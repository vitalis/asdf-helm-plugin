#!/usr/bin/env bash

ASDF_HELM_PLUGIN_MY_NAME=asdf-helm-plugin

fail() {
	echo >&2 -e "${ASDF_HELM_PLUGIN_MY_NAME}: [ERROR] $*"
	exit 1
}

ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH=

if [[ ${ASDF_HELM_PLUGIN_DEBUG:-} -eq 1 ]]; then
	# In debug mode, dunp everything to a log file
	# got a little help from https://askubuntu.com/a/1345538/985855

	ASDF_HELM_PLUGIN_DEBUG_LOG_PATH="/tmp/${ASDF_HELM_PLUGIN_MY_NAME}-debug.log"
	mkdir -p "$(dirname "$ASDF_HELM_PLUGIN_DEBUG_LOG_PATH")"

	printf "\n\n-------- %s ----------\n\n" "$(date)" >>"$ASDF_HELM_PLUGIN_DEBUG_LOG_PATH"

	exec > >(tee -ia "$ASDF_HELM_PLUGIN_DEBUG_LOG_PATH")
	exec 2> >(tee -ia "$ASDF_HELM_PLUGIN_DEBUG_LOG_PATH" >&2)

	exec 19>>"$ASDF_HELM_PLUGIN_DEBUG_LOG_PATH"
	export BASH_XTRACEFD=19
	set -x
fi

log() {
	if [[ ${ASDF_HELM_PLUGIN_DEBUG:-} -eq 1 ]]; then
		echo >&2 -e "${ASDF_HELM_PLUGIN_MY_NAME}: $*"
	fi
}

get_helm_version() {
	local helm_path="$1"
	local regex='BuildInfo{Version:"v([0-9]+\.[0-9]+\.[0-9]+)'

	helm_version_raw=$("$helm_path" version)

	if [[ $helm_version_raw =~ $regex ]]; then
		echo -n "${BASH_REMATCH[1]}"
	else
		fail "Unable to determine helm version"
	fi
}

resolve_helm_path() {
	# if ASDF_HELM_PLUGIN_DEFAULT_HELM_PATH is set, use it, else:
	# 1. try $(asdf which helm)
	# 2. try $(which helm)

	if [ -n "${ASDF_HELM_PLUGIN_DEFAULT_HELM_PATH+x}" ]; then
		ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH="$ASDF_HELM_PLUGIN_DEFAULT_HELM_PATH"
		return
	fi

	# cd to $HOME to avoid picking up a local helm from .tool-versions
	pushd "$HOME" >/dev/null || fail "Failed to pushd \$HOME"

	# run direnv in $HOME to escape any direnv we might already be in
	if type -P direnv &>/dev/null; then
		eval "$(DIRENV_LOG_FORMAT=direnv export bash)"
	fi

	local asdf_helm
	if asdf_helm=$(asdf which helm 2>/dev/null); then
		ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH=("$asdf_helm")
	else
		local global_helm
		global_helm=$(which helm)
		ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH=("$global_helm")
	fi

	popd >/dev/null || fail "Failed to popd"

	if [ -z "$ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH" ]; then
		fail "Failed to find helm"
	else
		log "Using helm at '$ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH'"
	fi
}

if ! type "curl" >/dev/null 2>&1; then
	fail "curl is required"
fi

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

set_sanitized_name() {
	SANITIZED_NAME="${1//\-/_}"
}

set_gh_repo() {
	local gh_repo

	set_sanitized_name "$1"
	gh_repo="gh_repo_${SANITIZED_NAME}"

	if [ -z ${!gh_repo+x} ]; then
		fail "Helm plugin $1 not supported"
	else
		GH_REPO="${!gh_repo}"
	fi
}

set_archive_bin_path() {
	local archive_bin_path

	set_sanitized_name "$1"
	archive_bin_path="archive_bin_path_${SANITIZED_NAME}"

	if [ -z ${!archive_bin_path+x} ]; then
		fail "Helm plugin $1 not supported"
	else
		ARCHIVE_BIN_PATH="${!archive_bin_path}"
	fi
}

list_all_versions() {
	local releases_path

	set_gh_repo "$1"
	releases_path="https://api.github.com/repos/$GH_REPO/releases"

	curl "${curl_opts[@]}" "$releases_path" | grep -oE 'tag_name": ".{1,15}",' | sed 's/tag_name\": \"v//;s/\",//'
}

# set_arch discovers the architecture for this system.
set_arch() {
	ARCH=$(uname -m)
	case "$ARCH" in
	armv5*) ARCH="armv5" ;;
	armv6*) ARCH="armv6" ;;
	armv7*) ARCH="armv7" ;;
	aarch64) ARCH="arm64" ;;
	x86) ARCH="386" ;;
	x86_64) ARCH="amd64" ;;
	i686) ARCH="386" ;;
	i386) ARCH="386" ;;
	esac
}

# set_os discovers the operating system for this system.
set_os() {
	OS=$(uname | tr '[:upper:]' '[:lower:]')

	case "$OS" in
	# Msys support
	msys*) OS='windows' ;;
	# Minimalist GNU for Windows
	mingw*) OS='windows' ;;
	darwin) OS='macos' ;;
	esac
}

# verify_supported checks that the os/arch combination is supported for
# binary builds.
verify_supported() {
	local supported="linux-arm64\nlinux-amd64\nmacos-amd64\nwindows-amd64\nmacos-arm64"

	if ! echo "$supported" | grep -q "$OS-$ARCH"; then
		fail "No prebuild binary for $OS-$ARCH."
	fi

	log "Support $OS-$ARCH"
}

default_download_url() {
	local plugin_name=$1
	local version=$2
	local scheme

	scheme="release_url_scheme_$SANITIZED_NAME"
	eval "echo ${!scheme}" | xargs echo
}

get_download_url() {
	default_download_url "$@"
}

set_helm_plugin_name() {
	local plugin_name=$1

	HELM_PLUGIN_NAME="$(echo "$plugin_name" | sed -n 's/.*\-\(?:.\)*/\1/p')"
}

generate_plugin_yaml() {
	local plugin_name=$1
	local version=$2
	local install_path=$3

	cat >"${install_path}/plugin.yaml" <<END
name: "${HELM_PLUGIN_NAME}"
version: "${version}"
ignoreFlags: false
useTunnel: true
command: "\$HELM_PLUGIN_DIR/bin/${HELM_PLUGIN_NAME}"
END
}

plugin_version_is_installed() {
	local version=$1
	eval "${ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH} plugin list" | sed 1d | grep -qs "${HELM_PLUGIN_NAME}" | grep -sq "${version}"
}

plugin_is_installed() {
	eval "${ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH} plugin list" | sed 1d | grep -qs "${HELM_PLUGIN_NAME}"
}

install_plugin_version() {
	local plugin_name=$1
	local version=$2
	local install_path=$3

	local bin_install_path="${install_path}/bin"
	local download_url release_path

	download_url=$(get_download_url "$@")
	release_path="${install_path}/${plugin_name}"

	mkdir -p "${bin_install_path}"
	pushd "${bin_install_path}" >/dev/null || fail "Failed to pushd ${bin_install_path}"
	log "Downloading ${plugin_name} from ${download_url}"
	curl "${curl_opts[@]}" -C - "${download_url}" | tar zx -O "${ARCHIVE_BIN_PATH}" >"${bin_install_path}/${HELM_PLUGIN_NAME}"
	chmod +x "${bin_install_path}/${HELM_PLUGIN_NAME}"
	generate_plugin_yaml "$@"
	ln -s "${install_path}" "${release_path}"
	popd >/dev/null || fail "Failed to popd"
	eval "${ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH} plugin install ${release_path}" || fail "Failed installing ${plugin_name}@${version}, rerun with ASDF_HELM_PLUGIN_DEBUG=1 for details"
}

update_plugin_version() {
	local plugin_name=$1
	local version=$2
	local install_path=$3

	uninstall_version "$plugin_name" "$install_path"
	install_plugin_version "$plugin_name" "$version" "$install_path"
}

install_version() {
	local plugin_name=$1
	local install_type=$2
	local version=$3
	local install_path=$4
	if [ "$install_type" != "version" ]; then
		fail "$plugin_name supports release installs only"
	fi

	set_gh_repo "$plugin_name"
	set_archive_bin_path "$plugin_name"
	set_helm_plugin_name "$plugin_name"
	resolve_helm_path
	set_arch
	set_os
	verify_supported

	if plugin_version_is_installed "$version"; then
		fail "$plugin_name $version is already installed"
	elif plugin_is_installed; then
		update_plugin_version "$plugin_name" "$version" "$install_path"
	else
		install_plugin_version "$plugin_name" "$version" "$install_path"
	fi
}

uninstall_version() {
	local plugin_name=$1
	local install_path=$2

	resolve_helm_path
	set_helm_plugin_name "$plugin_name"

	if plugin_is_installed; then
	  eval "${ASDF_HELM_PLUGIN_RESOLVED_HELM_PATH} plugin uninstall ${HELM_PLUGIN_NAME}" || fail "Failed uninstalling ${HELM_PLUGIN_NAME}, rerun with ASDF_HELM_PLUGIN_DEBUG=1 for details"
	fi
	rm -rf "$install_path"
}
