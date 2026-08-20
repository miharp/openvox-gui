#!/bin/bash
# openvox-gui package %post: build the application virtualenv offline
# from the wheels shipped in /usr/share/openvox-gui/wheels, then reload
# systemd. Nothing is enabled or started — run `openvox-gui-setup` for
# the one-time site configuration.
set -e

INSTALL_DIR="/opt/openvox-gui"
WHEEL_DIR="/usr/share/openvox-gui/wheels"
REQ="${INSTALL_DIR}/backend/requirements.txt"
STAMP="${INSTALL_DIR}/.venv-requirements"

# Prefer a parallel-installed python3.12 (EL8/EL9); fall back to the
# system python3 (EL10, Ubuntu 24.04 — both 3.12).
if command -v python3.12 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3.12)"
else
  PYTHON_BIN="$(command -v python3)"
fi

if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
  echo "openvox-gui: no Python >= 3.10 found (looked for python3.12, python3)" >&2
  exit 1
fi

if [ ! -f "$STAMP" ] || ! cmp -s "$REQ" "$STAMP"; then
  rm -rf "${INSTALL_DIR}/venv"
  # --without-pip: distro venv modules do not reliably ship ensurepip
  # wheels; pip is bootstrapped from its own vendored wheel instead.
  "$PYTHON_BIN" -m venv --without-pip "${INSTALL_DIR}/venv"
  PIP_WHEEL=$(ls "${WHEEL_DIR}"/pip-*.whl | head -1)
  PYTHONPATH="$PIP_WHEEL" "${INSTALL_DIR}/venv/bin/python" -m pip install \
    --quiet --no-index --find-links "$WHEEL_DIR" pip setuptools wheel
  "${INSTALL_DIR}/venv/bin/pip" install --quiet --no-index \
    --find-links "$WHEEL_DIR" -r "$REQ"
  "${INSTALL_DIR}/venv/bin/pip" install --quiet --no-index \
    --find-links "$WHEEL_DIR" ovox
  cp "$REQ" "$STAMP"
fi

systemctl daemon-reload >/dev/null 2>&1 || true
