#!/bin/bash

set -e  # Exit on error

echo "Removing builder user: $BUILDER_USER..."

/usr/sbin/userdel -r -f "$BUILDER_USER" || true
rm -f /etc/sudoers.d/$BUILDER_USER || true

echo 'Builder user removed successfully!'
