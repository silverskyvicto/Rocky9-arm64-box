#!/usr/bin/env bash
set -euxo pipefail

sudo dnf clean all

sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
sudo rm -f /etc/ssh/ssh_host_*

sudo truncate -s 0 /etc/machine-id || true
sudo rm -f /var/lib/dbus/machine-id || true
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id

sudo cloud-init clean --logs || true

history -c || true
