# setup-prebuild-env

A composite action to prepare a runner for [prebuilding](https://containers.dev/guide/prebuild) and publishing [Dev Container images](https://containers.dev/) via [devcontainers/ci](https://github.com/devcontainers/ci).

## Usage

### Simple prebuild

The following workflow is the simplest example for using this action. Using the action's default settings, any time a commit is pushed to the `main` branch, the action will:
- Log in to the GitHub container registry.
- Prepare the necessary tools to build a Dev Container image.
- Build a single CPU architecture Dev Container image.
- Publish the image to the GitHub container registry.

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
      - name: checkout
        uses: actions/checkout@v4

      - name: setup prebuild environment
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: prebuild and publish image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          configFile: .devcontainer/source/devcontainer.json
          push: always
```

### Multi-platform images

The [devcontainers/ci](https://github.com/devcontainers/ci) action supports building multi-platform images, via emulation, which has [some caveats](https://github.com/devcontainers/ci/blob/main/docs/multi-platform-builds.md). This action can detect if multi-platform builds are needed using the `platforms` input.

```yaml
name: build multi-platform
on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: checkout
        uses: actions/checkout@v4

      - name: setup prebuild environment
        id: setup
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}
          platforms: linux/amd64,linux/arm64

      - name: prebuild and publish image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          configFile: .devcontainer/source/devcontainer.json
          push: always
          platforms: ${{ steps.setup.outputs.platforms }}
```

### Advanced configuration

If more control is needed for one or more of the steps, the action supports disabling that step entirely by setting the `setup-*` inputs to `false`.

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
      - name: checkout
        uses: actions/checkout@v4

      - name: setup prebuild environment
        id: setup
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}
          platforms: linux/amd64,linux/arm64
          setup-buildx: false

      - name: setup buildx
        uses: docker/setup-buildx-action@v3
        with:
          buildkitd-flags: --debug
          driver-opts: image=moby/buildkit:v0.11.0
          platforms: ${{ steps.setup.outputs.platforms }}

      - name: prebuild and publish image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          configFile: .devcontainer/source/devcontainer.json
          push: always
          platforms: ${{ steps.setup.outputs.platforms }}
```

## Customizing

See [action.yml](action.yml) for more information.

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
