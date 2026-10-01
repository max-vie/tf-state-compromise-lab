#!/usr/bin/env bash
# Act 2 of the attack: rogue module exfil.
#
# Story: the usage-analytics PR merged without anyone reading the module.
# The next pipeline run applied it, and its provisioner posted the
# deployment's sensitive variables to the attacker's collector.
# `make attack` runs the pipeline apply before this script.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
LOG="$repo/.run/webhook/exfil.log"
CALLSITE="$repo/scenarios/vulnerable/telemetry.tf"
dbval=$(grep '^db_password' "$repo/scenarios/vulnerable/localstack.tfvars" | cut -d'"' -f2)
apikey=$(grep '^api_key' "$repo/scenarios/vulnerable/localstack.tfvars" | cut -d'"' -f2)

fail() { echo "FAIL $*"; exit 1; }

echo "1. the merged PR: a \"usage reporting\" module receiving the secrets"
grep -A5 'module "usage_reporting"' "$CALLSITE" | sed 's/^/    /'

echo
echo "2. what the module sends per pipeline run"
test -s "$LOG" || fail "no exfil log at .run/webhook/exfil.log"
last=$(tail -n 1 "$LOG")
echo "    received at $(echo "$last" | jq -r .time):"
echo "$last" | jq -r '.body | fromjson' 2>/dev/null | sed 's/^/    /' \
  || echo "    $last"

echo
echo "3. confirm the exfiltrated values are the live deployment secrets"
echo "$last" | jq -e --arg db "$dbval" --arg key "$apikey" \
  '.body | fromjson? | .db_password == $db and .api_key == $key' >/dev/null \
  || fail "webhook payload does not contain the current deployment secrets"
echo "OK  db_password and api_key delivered to the attacker's collector"
exit 0