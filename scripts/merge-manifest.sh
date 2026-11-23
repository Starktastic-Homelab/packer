#!/bin/bash
# Usage: merge-manifest.sh ROLE NEW CURRENT
# Prints CURRENT with its ROLE entries replaced by NEW's last ROLE build, by name; the other entries are kept.
# Fails, printing nothing, when NEW has no ROLE build.

set -euo pipefail

role=$1 new=$2 current=$3

entry=$(jq -ce --arg role "$role" '[.builds[] | select(.name == $role)] | last' "$new")
# k3s stays at builds[0] for terraform's readers until they select by name.
jq --argjson new "$entry" \
  '.builds = ([.builds[] | select(.name != $new.name)] + [$new] | sort_by(.name != "k3s"))
    | .last_run_uuid = $new.packer_run_uuid' \
  "$current"
