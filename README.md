<div align="center">

# asdf-helm-plugin [![Build](https://github.com/vitalis/asdf-helm-plugin/actions/workflows/build.yml/badge.svg)](https://github.com/vitalis/asdf-helm-plugin/actions/workflows/build.yml) [![Lint](https://github.com/vitalis/asdf-helm-plugin/actions/workflows/lint.yml/badge.svg)](https://github.com/vitalis/asdf-helm-plugin/actions/workflows/lint.yml)

[helm-plugin](https://github.com/vitalis/asdf-helm-plugin) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

**TODO: adapt this section**

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

Plugin:

```shell
asdf plugin add helm-plugin
# or
asdf plugin add helm-plugin https://github.com/vitalis/asdf-helm-plugin.git
```

helm-plugin:

```shell
# Show all installable versions
asdf list-all helm-plugin

# Install specific version
asdf install helm-plugin latest

# Set a version globally (on your ~/.tool-versions file)
asdf global helm-plugin latest

# Now helm-plugin commands are available
asdf-helm-plugin --help
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/vitalis/asdf-helm-plugin/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Vitaly Gorodetsky](https://github.com/vitalis/)
