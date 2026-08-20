#!/bin/bash
# openvox-gui package %pre: ensure the service user exists before files
# (some with puppet ownership) are laid down. Group is created first and
# errors are NOT suppressed — on a host without a pre-existing puppet
# group a silent useradd failure would leave the unit dying with
# status=217/USER.
set -e

if ! getent group puppet >/dev/null; then
  groupadd --system puppet
fi
if ! getent passwd puppet >/dev/null; then
  useradd --system --gid puppet --shell /sbin/nologin \
    --home-dir /opt/openvox-gui --no-create-home puppet
fi
