#!/bin/bash
# Base image: what every VM shares. No GPU stack and no compiler (ADR 0017).

set -e # Exit on error

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# ----------------------------
# Upgrade all packages
# ----------------------------
echo 'Updating package lists...'
apt update

echo 'Upgrading all packages...'
apt full-upgrade -y

echo 'Installing cloud-init...'
apt install -y --install-recommends cloud-init

# ----------------------------
# Switch network stack
# ----------------------------
# Last step that needs the network: purging ifupdown breaks downloads (f9f0b6d).
echo 'Migrating from ifupdown to Netplan...'

apt install -y netplan.io systemd-resolved
apt purge -y ifupdown

# Enable systemd networking services
systemctl enable systemd-networkd
systemctl enable systemd-resolved

# Link /etc/resolv.conf to systemd-resolved
# This ensures standard Linux tools use the DNS settings Cloud-Init provides
rm -f /etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# ----------------------------
# Clean and remove unnecessary packages
# ----------------------------
echo 'Removing unnecessary packages...'
apt autoremove -y
apt clean

# ----------------------------
# Configure GRUB
# ----------------------------
echo 'Configuring GRUB...'
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
if ! grep -q '^GRUB_TIMEOUT_STYLE=hidden' /etc/default/grub; then
  echo 'GRUB_TIMEOUT_STYLE=hidden' | tee -a /etc/default/grub
fi

update-grub
update-initramfs -u

echo 'Base script completed successfully!'
