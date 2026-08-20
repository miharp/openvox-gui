#!/bin/bash
# Build openvox-gui packages inside a container (local equivalent of the
# CI build job). Run from the repo root on any docker host:
#   packaging/build-in-docker.sh [rpm|deb] [amd64|arm64]
# Output lands in build/out/.
set -euo pipefail

FORMAT="${1:-rpm}"
ARCH="${2:-$(docker version --format '{{.Server.Arch}}' 2>/dev/null || echo amd64)}"
IMAGE="almalinux:10"

docker run --rm -v "$PWD":/src -w /src "$IMAGE" bash -euo pipefail -c "
  dnf -y -q install python3 python3-pip nodejs npm git make tar >/dev/null
  # nfpm: pinned version (resolving 'latest' via the API is
  # anonymous-rate-limited and flaky)
  NFPM_ARCH=\$( [ \"\$(uname -m)\" = 'aarch64' ] && echo arm64 || echo x86_64 )
  NFPM_VER=v2.47.0
  curl -sfL \"https://github.com/goreleaser/nfpm/releases/download/\${NFPM_VER}/nfpm_\${NFPM_VER#v}_Linux_\${NFPM_ARCH}.tar.gz\" | tar -xz -C /usr/local/bin nfpm
  make -f packaging/Makefile package PKG_FORMAT=$FORMAT PKG_ARCH=$ARCH PYTHON=python3
"
