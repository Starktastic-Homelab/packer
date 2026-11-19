#!/bin/bash
# Storage image, cloned from the base: LIO target, LVM, firewall, metrics (ADR 0017).

set -e # Exit on error

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# The build boot runs cloud-init (and may run apt); wait for it. Exit 2 means
# done with recoverable errors.
echo 'Waiting for cloud-init...'
cloud-init status --wait >/dev/null || [ $? -eq 2 ]

echo 'Updating package lists...'
apt update

echo 'Installing storage packages...'
apt install -y targetcli-fb lvm2 nftables prometheus-node-exporter

# Debian ships nftables disabled; the storage role only ever reloads it.
systemctl enable nftables

# A restart of rtslib-fb-targetctl drops every session, so upgrades are deliberate.
apt-mark hold python3-rtslib-fb targetcli-fb

# Activate the VGs before targetctl restores the saved targets at boot.
install -D -m 0644 /tmp/rtslib-fb-targetctl.service.d/10-lvm.conf \
  /etc/systemd/system/rtslib-fb-targetctl.service.d/10-lvm.conf
rm -rf /tmp/rtslib-fb-targetctl.service.d

echo 'Removing unnecessary packages...'
apt autoremove -y
apt clean

# The storage VM carries no compiler.
for pkg in build-essential gcc; do
  if dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then
    echo "ERROR: $pkg is installed in the storage image." >&2
    exit 1
  fi
done

echo 'Storage script completed successfully!'
