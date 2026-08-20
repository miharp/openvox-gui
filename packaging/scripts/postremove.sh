#!/bin/bash
# openvox-gui package %postun: on full removal (not upgrade), delete the
# generated virtualenv and stamp. Site data (config/.env, data/, logs/)
# is left in place for the operator.
set -e

# rpm passes 0 on erase / >=1 on upgrade; dpkg passes "remove"/"purge".
case "${1:-}" in
  0|remove|purge)
    rm -rf /opt/openvox-gui/venv /opt/openvox-gui/.venv-requirements
    # Sweep runtime bytecode so package-owned directories can vanish.
    find /opt/openvox-gui -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
    find /opt/openvox-gui -type d -empty -delete 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    ;;
esac
