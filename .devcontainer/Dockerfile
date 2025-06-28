ARG VARIANT="bookworm"
FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

ARG REPO_HOST="https://github.com"
ARG REPO_OWNER="cennis91"
ARG REPO_NAME="setup-prebuild-env"
ARG REPO_URL="${REPO_HOST}/${REPO_OWNER}/${REPO_NAME}"
ARG VARIANT

# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.base.name="mcr.microsoft.com/devcontainers/base:${VARIANT}" \
      org.opencontainers.image.description="A devcontainer image for ${REPO_NAME} action development" \
      org.opencontainers.image.documentation="${REPO_URL}/tree/main/README.md" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.title="${REPO_NAME}" \
      org.opencontainers.image.url="${REPO_URL}/pkgs/container/${REPO_NAME}%2fdevcontainer" \
      org.opencontainers.image.vendor="${REPO_OWNER}"
