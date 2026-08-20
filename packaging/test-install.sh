#!/bin/bash
# Install-test an openvox-gui package in a systemd container. Shared by
# local runs and CI:
#   packaging/test-install.sh almalinux:10 build/out/openvox-gui-*.rpm
#   packaging/test-install.sh almalinux:9  build/out/openvox-gui-*.rpm
#   packaging/test-install.sh ubuntu:24.04 build/out/openvox-gui_*.deb
# Asserts: package installs (deps resolve), venv built offline, setup
# succeeds, service active, /health ok, admin login 200, and that
# removal deletes the app+venv but preserves .env and site data.
set -euo pipefail

IMAGE="${1:?usage: test-install.sh <image> <package-file>}"
PKG="${2:?usage: test-install.sh <image> <package-file>}"
PKG_DIR=$(cd "$(dirname "$PKG")" && pwd)
PKG_FILE=$(basename "$PKG")
NAME="ovoxgui-test-$$"

case "$IMAGE" in
  ubuntu:*)
    # Stock ubuntu images ship no systemd; bake a minimal init layer.
    RUN_IMAGE="openvox-gui-test-noble-systemd"
    printf 'FROM %s\nENV DEBIAN_FRONTEND=noninteractive\nRUN apt-get update -qq && apt-get install -y -qq systemd systemd-sysv sudo curl >/dev/null && apt-get clean\nCMD ["/lib/systemd/systemd"]\n' "$IMAGE" \
      | docker build -q -t "$RUN_IMAGE" - >/dev/null
    INSTALL_CMD="export DEBIAN_FRONTEND=noninteractive; apt-get -qq update >/dev/null && apt-get -qq install -y /pkg/${PKG_FILE} >/dev/null"
    REMOVE_CMD="DEBIAN_FRONTEND=noninteractive apt-get -qq remove -y openvox-gui >/dev/null"
    ;;
  *)
    RUN_IMAGE="$IMAGE"
    INSTALL_CMD="dnf -y -q install sudo >/dev/null 2>&1; dnf -y -q install /pkg/${PKG_FILE}"
    REMOVE_CMD="dnf -y -q remove openvox-gui >/dev/null"
    ;;
esac

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --privileged --name "$NAME" -v "$PKG_DIR":/pkg:ro "$RUN_IMAGE" $( [ "${RUN_IMAGE#openvox-gui-test}" != "$RUN_IMAGE" ] || echo /sbin/init ) >/dev/null
sleep 5

docker exec "$NAME" bash -euo pipefail -c "
  $INSTALL_CMD
  test -x /opt/openvox-gui/venv/bin/uvicorn
  echo 'PASS: package installed, venv built offline'
  printf 'SSL_ENABLED=false\nADMIN_PASSWORD=test-install-secret\n' > /root/answers.conf
  openvox-gui-setup -c /root/answers.conf >/dev/null
  [ \"\$(systemctl is-active openvox-gui)\" = active ]
  curl -sf http://127.0.0.1:4567/health | grep -q '\"status\":\"ok\"'
  echo 'PASS: service active and healthy'
  CODE=\$(curl -s -X POST http://127.0.0.1:4567/api/auth/login \
    -H 'Content-Type: application/json' \
    -d '{\"username\":\"admin\",\"password\":\"test-install-secret\"}' \
    -o /dev/null -w '%{http_code}')
  [ \"\$CODE\" = 200 ]
  echo 'PASS: admin login'
  systemctl stop openvox-gui
  $REMOVE_CMD
  test ! -d /opt/openvox-gui/venv
  test ! -d /opt/openvox-gui/backend
  test -f /opt/openvox-gui/config/.env
  test -f /opt/openvox-gui/data/openvox_gui.db
  echo 'PASS: removal deletes app+venv, preserves .env and data'
"
echo "OK: ${PKG_FILE} on ${IMAGE}"
