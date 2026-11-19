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

# Only the storage role may activate retained and regen (ADR 0017 F24). event_activation = 0 makes the udev pvscan
# return before reading a disk, in the initramfs and the main system; explicit vgchange is unaffected.
sed -i '0,/^global {/s//global {\n\tevent_activation = 0/' /etc/lvm/lvm.conf
[ "$(lvmconfig global/event_activation)" = event_activation=0 ] || {
  echo 'ERROR: global/event_activation is not 0 in /etc/lvm/lvm.conf.' >&2
  exit 1
}
# Every LV is linear (nothing to monitor); blk-availability's stop is an unscoped blkdeactivate.
systemctl mask lvm2-monitor.service blk-availability.service
# An lvm2 upgrade runs an unscoped vgcfgbackup and may replace lvm.conf, so it is a deliberate, drained operation.
apt-mark hold lvm2
# The lvm2 hook copies /etc/lvm into the initramfs; base.sh built it before lvm2, and -u alone rebuilds one kernel.
update-initramfs -u -k all
for initrd in /boot/initrd.img-*; do
  d=$(mktemp -d)
  unmkinitramfs "$initrd" "$d"
  # Flat, or early/ + main/ when the initrd carries early microcode.
  conf=$(find "$d" -path '*/etc/lvm/lvm.conf' -type f)
  if [ "$(printf '%s\n' "$conf" | grep -c .)" -ne 1 ] || ! cmp -s "$conf" /etc/lvm/lvm.conf; then
    echo "ERROR: $initrd does not carry /etc/lvm/lvm.conf." >&2
    rm -rf "$d"
    exit 1
  fi
  rm -rf "$d"
done

# Orders targetctl after the network (the portal binds to it); it activates nothing (ADR 0017 F24).
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
