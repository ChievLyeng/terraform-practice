#!/usr/bin/env bash
# Terraform's "external" data source protocol: read a JSON object with
# string values from stdin, print a JSON object with string values to
# stdout. This is the escape hatch for "there's no provider for this,
# but I need to pull a value into Terraform" that isn't a full resource
# lifecycle (that's what null_resource + local-exec is for instead).
set -euo pipefail

eval "$(jq -r '@sh "NAME=\(.name)"')"

IP=""
for i in $(seq 1 30); do
  IP=$(lxc list "$NAME" -c 4 --format csv | cut -d' ' -f1 | head -n1 || true)
  if [ -n "$IP" ]; then
    break
  fi
  sleep 1
done

if [ -z "$IP" ]; then
  echo "Timed out waiting for $NAME to get an IP address" >&2
  exit 1
fi

jq -n --arg ip "$IP" '{"ip": $ip}'
