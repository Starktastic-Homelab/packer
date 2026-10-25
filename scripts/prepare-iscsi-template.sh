#!/bin/bash
# Packer image preparation only. Worker identity/enrollment belongs to Ansible.
set -euo pipefail

apt-get install -y open-iscsi e2fsprogs kmod

for kernel in /lib/modules/*; do
  if [ ! -d "$kernel" ] || ! modinfo -k "${kernel##*/}" iscsi_tcp >/dev/null; then
    echo "ERROR: iSCSI TCP transport is missing from installed kernel ${kernel##*/}." >&2
    exit 1
  fi
done

# Never stop an initiator or erase its identity when ownership is uncertain.
if iscsiadm -m session >/dev/null 2>&1; then
  echo 'ERROR: active iSCSI sessions prevent sealing this template.' >&2
  exit 1
else
  status=$?
  if [ "$status" -ne 21 ]; then
    echo "ERROR: cannot establish an idle iSCSI initiator (status $status)." >&2
    exit 1
  fi
fi

# Debian Trixie stores node records in /var/lib/iscsi; also reject legacy state.
for root in /etc/iscsi /var/lib/iscsi; do
  for database in nodes send_targets isns static ifaces; do
    path="$root/$database"
    if [ -L "$path" ] || { [ -d "$path" ] && [ -n "$(find "$path" -mindepth 1 -print -quit)" ]; }; then
      echo "ERROR: stored iSCSI configuration at $path requires inspection." >&2
      exit 1
    fi
  done
done

# Disable, rather than mask, so Ansible can start the daemon after assigning IQNs.
systemctl disable --now open-iscsi.service iscsid.socket iscsid.service
rm -f /etc/iscsi/initiatorname.iscsi
# Ensure the package-generated identity cannot remain in a copied initramfs.
update-initramfs -u -k all
