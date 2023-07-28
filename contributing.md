# Contributing

Testing Locally:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

# TODO: adapt this
asdf plugin test helm-unittest https://github.com/vitalis/asdf-helm-plugin.git "helm unittest -h"
```

Tests are automatically run in GitHub Actions on push and PR.
