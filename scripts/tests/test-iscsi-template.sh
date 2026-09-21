#!/bin/bash
# Run only in a disposable Debian container, never on a workstation or VM.
set -euo pipefail
if [ ! -e /.dockerenv ]; then
  echo 'This check requires a disposable Docker container.' >&2
  exit 1
fi
apt-get update -qq
apt-get install -y -qq open-iscsi e2fsprogs kmod systemd >/dev/null
mkdir -p /test-bin /lib/modules/test-kernel-a /lib/modules/test-kernel-b
cat >/test-bin/modinfo <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>/tmp/module-checks
[ "$1" = -k ] && [ "$3" = iscsi_tcp ] && [ "${MISSING_MODULE:-}" != "$2" ]
SH
cat >/test-bin/iscsiadm <<'SH'
#!/bin/sh
exit "${SESSION_STATUS:-21}"
SH
cat >/test-bin/systemctl <<'SH'
#!/bin/bash
# This container has no systemd PID 1. Exercise real offline enable/disable;
# runtime stop and real kernel loading remain image/VM qualification gates.
printf '%s\n' "$*" >>/tmp/service-checks
args=()
for arg in "$@"; do [ "$arg" = --now ] || args+=("$arg"); done
exec /usr/bin/systemctl "${args[@]}"
SH
cat >/test-bin/update-initramfs <<'SH'
#!/bin/sh
test ! -e /etc/iscsi/initiatorname.iscsi
printf '%s\n' "$*" >/tmp/initramfs-check
SH
chmod +x /test-bin/*
export PATH="/test-bin:$PATH"
script=/workspace/scripts/prepare-iscsi-template.sh

# A missing module, active session, or failed session query must preserve identity.
for scenario in module active unknown; do
  printf 'InitiatorName=iqn.test:build\n' >/etc/iscsi/initiatorname.iscsi
  case "$scenario" in
    module) export MISSING_MODULE=test-kernel-b SESSION_STATUS=21 ;;
    active) export MISSING_MODULE='' SESSION_STATUS=0 ;;
    unknown) export MISSING_MODULE='' SESSION_STATUS=1 ;;
  esac
  if bash "$script" >/tmp/check-output 2>&1; then
    echo "Unexpected acceptance: $scenario" >&2; exit 1
  fi
  test -s /etc/iscsi/initiatorname.iscsi
  grep -q 'ERROR:' /tmp/check-output
done
export MISSING_MODULE='' SESSION_STATUS=21
mkdir -p /var/lib/iscsi/nodes/unexpected-target
printf 'private fixture\n' >/var/lib/iscsi/nodes/unexpected-target/default
if bash "$script" >/tmp/check-output 2>&1; then
  echo 'Unexpected acceptance of stored target configuration' >&2; exit 1
fi
test -s /etc/iscsi/initiatorname.iscsi
rm -rf /var/lib/iscsi/nodes/unexpected-target

bash "$script"
test ! -e /etc/iscsi/initiatorname.iscsi
for unit in iscsid.service iscsid.socket open-iscsi.service; do
  state=$(/usr/bin/systemctl is-enabled "$unit" || true)
  test "$state" = disabled
done
grep -q -- '-k test-kernel-a iscsi_tcp' /tmp/module-checks
grep -q -- '-k test-kernel-b iscsi_tcp' /tmp/module-checks
grep -q -- 'disable --now' /tmp/service-checks
grep -qx -- '-u -k all' /tmp/initramfs-check
printf 'PASS: clone identity, inactive services, stored-target refusal, missing module, active/unknown sessions\n'
