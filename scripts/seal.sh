#!/bin/bash
# Runs last in every build: nothing from this build boot may reach the clones.

set -e # Exit on error

: "${BUILDER_USER:?must be set by the Packer shell provisioner}"

echo 'Resetting machine ID...'
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo 'Resetting cloud-init state...'
cloud-init clean --logs

echo "Removing builder user: $BUILDER_USER..."
/usr/sbin/userdel -r -f "$BUILDER_USER" || true
if getent passwd "$BUILDER_USER" >/dev/null; then
  echo "ERROR: builder user $BUILDER_USER still exists." >&2
  exit 1
fi
rm -f /etc/sudoers.d/"$BUILDER_USER"
# Clone builds log in as a cloud-init user, whose NOPASSWD sudo lives here.
if [ "${CLONE_BUILD:-0}" = 1 ]; then
  rm -f /etc/sudoers.d/90-cloud-init-users
fi

echo 'Image sealed successfully!'
