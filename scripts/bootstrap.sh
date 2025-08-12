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
apt install -y --install-recommends curl cloud-init resolvconf

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

echo 'Bootstrap script completed successfully!'
