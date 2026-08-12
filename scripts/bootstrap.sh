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
  firmware-misc-nonfree \
  intel-media-va-driver-non-free \
  vainfo

# ----------------------------
# Install Intel SR-IOV driver
# ----------------------------
# Version and kernel series come from debian.auto.pkrvars.hcl. The pair is
# validated against upstream release metadata in CI (i915-compat workflow);
# here we only confirm the image really is on the kernel series that was
# validated, so a Debian kernel bump fails the build instead of silently
# installing a DKMS release that cannot support it.
: "${I915_SRIOV_VERSION:?must be set by the Packer shell provisioner}"
: "${I915_SRIOV_KERNEL_SERIES:?must be set by the Packer shell provisioner}"

echo "Verifying guest kernels are on series ${I915_SRIOV_KERNEL_SERIES}..."
for kernel in "$(uname -r)" /lib/modules/*; do
  kernel="${kernel#/lib/modules/}"
  series="$(echo "$kernel" | cut -d. -f1,2)"
  if [ "$series" != "$I915_SRIOV_KERNEL_SERIES" ]; then
    echo "ERROR: kernel ${kernel} is series ${series}, but i915-sriov-dkms ${I915_SRIOV_VERSION}" >&2
    echo "       was validated for series ${I915_SRIOV_KERNEL_SERIES}." >&2
    echo "       Update i915_sriov_version/i915_sriov_kernel_series in debian.auto.pkrvars.hcl." >&2
    exit 1
  fi
done

echo "Installing Intel SR-IOV DKMS Driver ${I915_SRIOV_VERSION}..."
curl -L -s -S -o i915.deb "https://github.com/strongtz/i915-sriov-dkms/releases/download/${I915_SRIOV_VERSION}/i915-sriov-dkms_${I915_SRIOV_VERSION}_amd64.deb"
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
# Remove ModemManager (interferes with Zigbee USB serial adapters)
# ----------------------------
echo 'Removing ModemManager...'
apt purge -y modemmanager || true

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
