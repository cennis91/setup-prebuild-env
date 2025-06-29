# Setup Dev Container Prebuild Environment

A composite action to prepare runners for [prebuilding](https://containers.dev/guide/prebuild) and publishing [Dev Container images](https://containers.dev/) via [devcontainers/ci](https://github.com/devcontainers/ci).

## Usage

### Quick start

The following is a simple, minimal workflow to quickly get started with this action. You may copy this directly into your workflow. When the job is triggered, the action will:

- Log in to the GitHub container registry.
- Prepare the tools needed to build and publish images.
- Build a single CPU architecture Dev Container image.
- Publish the image to the container registry.

```yaml
jobs:
  quick-start:
    name: Publish a Prebuilt Dev Container Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Prebuild Environment
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}
          registry: ${{ env.REGISTRY || 'ghcr.io' }}

      - name: Prebuild and Publish Image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ${{ env.REGISTRY || 'ghcr.io' }}/${{ github.repository }}/quick-start
          push: ${{ env.PUSH || 'always' }}
```

### Multi-platform images

The [devcontainers/ci](https://github.com/devcontainers/ci) action supports building multi-platform images, via emulation, which has [some caveats](https://github.com/devcontainers/ci/blob/main/docs/multi-platform-builds.md). This action can detect if multi-platform builds are needed using the `platforms` input.

```yaml
jobs:
  multi-platform:
    name: Publish a Prebuilt Multi-Platform Dev Container Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Prebuild Environment
        id: setup
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}
          platforms: linux/amd64,linux/arm64
          registry: ${{ env.REGISTRY || 'ghcr.io' }}

      - name: Prebuild and Publish Image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ${{ env.REGISTRY || 'ghcr.io' }}/${{ github.repository }}/multi-platform
          push: ${{ env.PUSH || 'always' }}
          platform: ${{ steps.setup.outputs.platforms }}
```

### Fine-tuned control

If more control is needed for one or more of the steps, the action supports disabling that step entirely by setting the corresponding `setup-*` input to `false`. If you do not need to customize a step, you should leave it enabled.

```yaml
jobs:
  custom-steps:
    name: Publish a Prebuilt Dev Container Image with Custom Steps
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Prebuild Environment
        id: setup
        uses: cennis91/setup-prebuild-env@v1
        with:
          password: ${{ secrets.GITHUB_TOKEN }}
          platforms: linux/amd64,linux/arm64
          registry: ${{ env.REGISTRY || 'ghcr.io' }}
          setup-buildx: false
          setup-qemu: false

      - name: Setup QEMU (Manually without cache)
        uses: docker/setup-qemu-action@v3
        with:
          cache-image: false
          platforms: ${{ steps.setup.outputs.platforms }}

      - name: Setup Buildx (Manually with debug)
        uses: docker/setup-buildx-action@v3
        with:
          buildkitd-flags: --debug
          platforms: ${{ steps.setup.outputs.platforms }}

      - name: Prebuild and Publish Image
        uses: devcontainers/ci@v0.3
        with:
          imageName: ${{ env.REGISTRY || 'ghcr.io' }}/${{ github.repository }}/custom-steps
          push: ${{ env.PUSH || 'always' }}
          platform: ${{ steps.setup.outputs.platforms }}
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
| `username` | string | Username for authenticating to the container registry | `github.actor` |
| | | |
| `setup-buildx` | bool | Setup Docker using [docker/setup-buildx-action](https://github.com/docker/setup-buildx-action) | `true` |
| `setup-login` | bool | Setup login to container registry using [docker/login-action](https://github.com/docker/login-action) | `true` |
| `setup-node` | bool | Setup Node.js via [actions/setup-node](https://github.com/actions/setup-node) | `true` |
| `setup-qemu` | bool | Setup QEMU via [docker/setup-qemu-action](https://github.com/docker/setup-qemu-action) for cross-platform builds | `true` |
| `setup-skopeo` | bool | Setup Skopeo by installing the Skopeo package | `true` |
| | | |
| `skopeo-minimum` | string | Minimum version of Skopeo needed | `1.9.0` |
| `skopeo-url` | string | Repository URL of the Skopeo package to install | [More info](https://github.com/devcontainers/ci/issues/191#issuecomment-1532014769) |
| `node-minimum` | string | Minimum version of Node.js needed to run devcontainer/cli | `18.0.0` |
| `node-version` | string | Version of Node.js to install via [actions/setup-node](https://github.com/actions/setup-node) | `lts` |
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
| `node-version` | string | Installed Node.js version |
| | | |
| `qemu-platforms` | string | QEMU available platforms (comma separated) |
| | | |
| `skopeo-cache-hit` | bool | Boolean value to indicate a cache was found for Skopeo packages |
| `skopeo-package-version` | string | The Skopeo package name and version that was installed |

## Compatibility

This action was written with the goal of being compatible with GitHub Actions and as many GitHub Actions compatible self-hosted runners out of the box as possible.

| Status | Runner |
|--------|--------|
|   ✅   | GitHub-hosted runners |
|   ✅   | Self-hosted GitHub runners |
|   ✅   | [Gitea act_runner](https://docs.gitea.com/usage/actions/act-runner) |
|   ✅   | [nektos/act](https://nektosact.com/) |
|   ✅   | [ChristopherHX/github-act-runner](https://github.com/ChristopherHX/github-act-runner) |

## Contributing

See the [Contribution guidelines](CONTRIBUTING.md) for more information.

## License

This action is licensed under the [Apache-2.0 license](LICENSE).
