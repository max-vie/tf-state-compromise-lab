#!/usr/bin/env bash
# `make defend`: re-run each act of the attack chain against the hardened
# scenario and watch it stop. Expects the hardened scenario already
# bootstrap-applied and EXFIL_LINES set to the webhook log line count
# taken before that apply (both supplied by the Makefile).
#
# The vulnerable attack scripts stay untouched; this script re-uses their
# proof patterns inverted. Exit 0 only if every defense holds.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
ENDPOINT=http://localhost:4566
BUCKET=acme-shop-tfstate-hardened
KEY=hardened/acme-shop.tfstate
LOG="$repo/.run/webhook/exfil.log"

skip() { echo "STOPPED  $*"; }
fail_defense() { echo "FAIL  defense broken: $*"; exit 1; }

dbval=$(grep '^db_password' "$repo/scenarios/hardened/localstack.tfvars" | cut -d'"' -f2)
apikey=$(grep '^api_key' "$repo/scenarios/hardened/localstack.tfvars" | cut -d'"' -f2)

# The attacker re-uses the leaked keys from act 1; if act 1 has not run in
# this session, re-extract them from the same history artifact.
if test -s "$repo/attack/act1/.stolen-creds.env"; then
  CREDENV="$repo/attack/act1/.stolen-creds.env"
else
  CREDENV="$(mktemp)"
  trap 'rm -f "$tmpstate" "$CREDENV"' EXIT
  grep -E '^export AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY)=' \
    "$repo/attack/act1/history-leak/bash-history" \
    | sed 's/^export //' > "$CREDENV"
fi
set -a
# shellcheck source=/dev/null
source "$CREDENV"
set +a
export AWS_REGION=us-east-1

echo "defend: the attack chain against the hardened scenario"
echo

echo "act 1: state leak"
tmpstate="$(mktemp)"
trap 'rm -f "$tmpstate" "$CREDENV"' EXIT
aws --endpoint-url "$ENDPOINT" s3api get-object \
  --bucket "$BUCKET" --key "$KEY" "$tmpstate" >/dev/null \
  || fail_defense "state object unreadable"
if grep -qF -e "$dbval" -e "$apikey" "$tmpstate"; then
  fail_defense "act 1: secret values found in hardened state"
fi
skip "act 1: secrets are write-only (value_wo); the state file carries none"
echo

echo "act 2: rogue module exfil"
now=$(test -f "$LOG" && wc -l < "$LOG" || echo 0)
if test "$now" -ne "${EXFIL_LINES:-$now}"; then
  fail_defense "act 2: the hardened apply added webhook entries"
fi
if grep -qF 'acme-shop-hardened' "$LOG" 2>/dev/null; then
  fail_defense "act 2: the hardened stack phoned home"
fi
skip "act 2: the rogue PR never merged here; the beacon does not exist"
echo

echo "act 3: lateral movement"
hardstate=$(tofu -chdir="$repo/scenarios/hardened" state pull 2>/dev/null)
echo "    the deployed deploy-role policy (contrast: vulnerable's Action = \"*\"):"
echo "$hardstate" | jq -r '
  .resources[] | select(.type == "aws_iam_role_policy")
  | select(.name == "deploy_scoped") | .instances[0].attributes.policy
  | fromjson | .Statement[].Action | "    actions: \(.)"' 2>/dev/null
echo "$hardstate" | jq -e '
  [.resources[] | select(.type == "aws_iam_role_policy") | .instances[0].attributes.policy
  | fromjson | .Statement[] | .Action]
  | flatten | all(. != "*")' >/dev/null 2>&1 \
  || fail_defense "act 3: a wildcard action persists in a hardened policy"
echo "    (the emulator does not enforce IAM; on real AWS this scoped policy"
echo "     denies every call the vulnerable catch-all would have allowed)"
skip "act 3: no catch-all policy left to pivot with"
echo

echo "act 4: state sabotage"
# Pre-delete pull for the byte comparison in step 4.
prestate="$(mktemp)"
trap 'rm -f "$tmpstate" "$CREDENV" "$prestate"' EXIT
tofu -chdir="$repo/scenarios/hardened" state pull > "$prestate" 2>/dev/null \
  || fail_defense "act 4: could not pull hardened state before the probe"

echo "1. the attacker deletes the hardened state object"
aws --endpoint-url "$ENDPOINT" s3api delete-object \
  --bucket "$BUCKET" --key "$KEY" >/dev/null
echo "    OK object deleted ($BUCKET/$KEY)"

echo "2. but the bucket is versioned (the hardened bootstrap's act)"
versions=$(aws --endpoint-url "$ENDPOINT" s3api list-object-versions \
  --bucket "$BUCKET" --prefix "$KEY" --output json 2>/dev/null)
nv=$(echo "$versions" | jq '[.Versions[]?] | length')
nm=$(echo "$versions" | jq '[.DeleteMarkers[]?] | length')
if test "$nv" -lt 1 || test "$nm" -lt 1; then
  fail_defense "act 4: expected surviving versions and a delete marker, got $nv/$nm"
fi
echo "    versions kept: $nv, delete marker: $nm"

echo "3. restore: remove the delete marker"
marker=$(echo "$versions" | jq -r '.DeleteMarkers[] | select(.IsLatest==true) | .VersionId' | head -n1)
test -n "$marker" || fail_defense "act 4: no latest delete marker found"
aws --endpoint-url "$ENDPOINT" s3api delete-object \
  --bucket "$BUCKET" --key "$KEY" --version-id "$marker" >/dev/null
echo "    OK delete marker removed; the state object is back"

echo "4. verify: the restored state matches the pre-delete state"
poststate="$(mktemp)"
if ! tofu -chdir="$repo/scenarios/hardened" state pull > "$poststate" 2>/dev/null; then
  fail_defense "act 4: state pull failed after the restore"
fi
if ! cmp -s "$prestate" "$poststate"; then
  fail_defense "act 4: state did not come back intact"
fi
rm -f "$poststate"
echo "    OK state pull is byte-identical to the pre-delete pull"
echo "    (unlike act 3, this defense is one the emulator actually enforces:"
echo "     versioning is storage behavior, so the contrast is real)"
skip "act 4: deletion only made a marker; the state came back from a version"
exit 0