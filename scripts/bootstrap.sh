#!/bin/bash

set -e # Exit on error

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# ----------------------------
# Upgrade all packages
# ----------------------------
echo 'Updating package lists...'
apt update

echo 'Upgrading all packages...'
apt full-upgrade -y

# ----------------------------
# Install build dependencies
# ----------------------------
echo 'Installing build dependencies...'
apt install -y --install-recommends \
  curl \
  build-essential \
  dkms \
  linux-headers-amd64 \
  cloud-init \
  nfs-common \
  intel-media-va-driver-non-free \
  vainfo

# ----------------------------
# Install Intel SR-IOV driver
# ----------------------------
echo 'Installing Intel SR-IOV DKMS Driver...'
curl -L -s -S -o i915.deb "https://github.com/strongtz/i915-sriov-dkms/releases/download/2025.12.10/i915-sriov-dkms_2025.12.10_amd64.deb"
dpkg -i i915.deb && rm i915.deb

# ----------------------------
# Switch network stack
# ----------------------------
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
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_guc=3 module_blacklist=xe /' /etc/default/grub

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
if ! grep -q '^GRUB_TIMEOUT_STYLE=hidden' /etc/default/grub; then
  echo 'GRUB_TIMEOUT_STYLE=hidden' | tee -a /etc/default/grub
fi

update-grub
update-initramfs -u

# ----------------------------
# Reset machine ID
# ----------------------------
echo 'Resetting machine ID...'
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

# ----------------------------
# Reset cloud-init for templating
# ----------------------------
echo 'Resetting cloud-init state...'
cloud-init clean --logs

echo 'Bootstrap script completed successfully!'
