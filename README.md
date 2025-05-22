# setup-prebuild-env

## Usage

```yaml
name: build
on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup prebuild environment
        id: setup
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Prebuild and publish image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          imageTag: latest
          configFile: .devcontainer/source/devcontainer.json
          refFilterForPush: |
            refs/heads/main
          eventFilterForPush: |
            push
          platform: ${{ steps.setup.outputs.platforms }}
```

## Customizing

See [action.yml](action.yml) for more details.

### Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `cache` | bool | Cache downloaded dependencies to cache backend | `true` |
| `password` | string | Password or token for authenticating to the container registry | |
| `platforms` | string | Comma-separated list of platforms to build for | |
| `registry` | string | Server address of the container registry | `ghcr.io` |
| `username` | string | Username for authenticating to the container registry | |
| | | |
| `setup-buildx` | bool | Setup Docker using [docker/setup-buildx-action](https://github.com/docker/setup-buildx-action) | `true` |
| `setup-login` | bool | Setup login to container registry using [docker/login-action](https://github.com/docker/login-action) | `true` |
| `setup-qemu` | bool | Setup QEMU via [docker/setup-qemu-action](https://github.com/docker/setup-qemu-action) for cross-platform builds | `true` |
| `setup-skopeo` | bool | Setup Skopeo by installing the Skopeo package | `true` |
| | | |
| `skopeo-url` | string | URL of the Skopeo package to install | [More info](https://github.com/devcontainers/ci/issues/191#issuecomment-1532014769) |
| `buildx-version` | string | Version of Buildx to install | |
| `qemu-image` | string | QEMU static binaries Docker image | |

### Outputs

| Name | Type | Description |
|------|------|-------------|
| `needs-cross` | bool | Boolean value to indicate cross-platform builds are needed |
| `platforms` | string | Comma-separated list of all OCI platform specifiers to build |
| `platforms-cross` | string | Comma-separated list of non-native OCI platform specifiers to build |
| `platforms-native` | string | Comma-separated list of native OCI platform specifiers to build |
| | | |
| `buildx-driver` | string | Docker Buildx builder driver |
| `buildx-name` | string | Docker Buildx builder name |
| `buildx-nodes` | string | Docker Buildx builder nodes metadata |
| `buildx-platforms` | string | Docker Buildx builder node platforms (preferred and/or available) |
| | | |
| `qemu-platforms` | string | QEMU available platforms (comma separated) |
| | | |
| `skopeo-cache-hit` | bool | Boolean value to indicate a cache was found for Skopeo packages |
| `skopeo-package-version` | string | The Skopeo package name and version that was installed |

## License

[Apache-2.0](LICENSE)
