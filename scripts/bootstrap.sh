#!/bin/bash

set -e  # Exit on error

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# ----------------------------
# Upgrade all packages
# ----------------------------
echo 'Updating package lists...'
apt update

echo 'Upgrading all packages...'
apt full-upgrade -y

# ----------------------------
# Install core dependencies
# ----------------------------
echo 'Installing core packages...'
apt install -y --install-recommends curl cloud-init netplan.io systemd-resolved open-iscsi nfs-common

# ----------------------------
# Switch Network Stack
# ----------------------------
echo 'Migrating from ifupdown to Netplan...'

# Remove legacy networking so Cloud-Init defaults to Netplan
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

echo 'Cleaning up APT cache...'
apt autoclean

# ----------------------------
# Remove GRUB timeout
# ----------------------------
echo 'Removing GRUB timeout...'
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
if ! grep -q '^GRUB_TIMEOUT_STYLE=hidden' /etc/default/grub; then
  echo 'GRUB_TIMEOUT_STYLE=hidden' | tee -a /etc/default/grub
fi
update-grub

# ----------------------------
# Reset Machine ID
# ----------------------------
echo 'Resetting Machine ID...'
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# ----------------------------
# Reset cloud-init for templating
# ----------------------------
echo 'Resetting cloud-init state...'
cloud-init clean --logs

echo 'Bootstrap script completed successfully!'
