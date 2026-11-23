#!/bin/bash
# Usage: merge-manifest.sh NEEDS CURRENT
# NEEDS is push-manifest's toJSON(needs). For every job whose result is success, replaces CURRENT's entries
# of the job's name with the last build of that name in the job's manifest output; other entries are kept.
# Prints the merged manifest once at the end; fails, printing nothing, when no job succeeded or a successful
# job's manifest lacks its build.

set -euo pipefail

needs=$1
merged=$(cat "$2")

roles=$(jq -r 'to_entries[] | select(.value.result == "success") | .key' "$needs")
if [[ -z $roles ]]; then
  echo "merge-manifest: no build succeeded" >&2
  exit 1
fi

for role in $roles; do
  entry=$(jq -ce --arg role "$role" '.[$role].outputs.manifest | fromjson | [.builds[] | select(.name == $role)] | last' "$needs")
  # k3s stays at builds[0] for terraform's readers until they select by name.
  merged=$(jq --argjson new "$entry" \
    '.builds = ([.builds[] | select(.name != $new.name)] + [$new] | sort_by(.name != "k3s"))
      | .last_run_uuid = $new.packer_run_uuid' <<<"$merged")
done

printf '%s\n' "$merged"
