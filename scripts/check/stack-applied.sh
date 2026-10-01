#!/usr/bin/env bash
# Gate: the vulnerable scenario is fully applied and its state is reachable.
# RED before `make bootstrap apply`, GREEN after:
#   1. backend state object exists in the LocalStack S3 backend
#   2. terraform.tfstate contains the sensitive parameter values (Act 1 target)
#   3. the deploy role is assumable via STS with the leaked-credentials shape
#   4. the /prod/* SSM parameters exist
set -uo pipefail
fail=0
source scripts/env/localstack.env

if aws --endpoint-url http://localhost:4566 s3 ls s3://acme-shop-tfstate/vulnerable/ 2>/dev/null | grep -q tfstate; then
  echo "OK  state object present in backend bucket"
else
  echo "FAIL no state object in s3://acme-shop-tfstate/vulnerable/"
  fail=1
fi

state=$(tofu -chdir=scenarios/vulnerable state pull 2>/dev/null)
dbval=$(grep '^db_password' scenarios/vulnerable/localstack.tfvars | cut -d'"' -f2)
if echo "$state" | jq -e --arg db "$dbval" \
     '[.resources[] | select(.type=="aws_ssm_parameter" and .name=="db_password") | .instances[0].attributes.value] | index($db) != null' >/dev/null 2>&1; then
  echo "OK  db_password present in plaintext in state (Act 1 target confirmed)"
else
  echo "FAIL db_password not found in state as expected"
  fail=1
fi

if AWS_ACCESS_KEY_ID=leaked-key AWS_SECRET_ACCESS_KEY=leaked-secret \
   aws --endpoint-url http://localhost:4566 sts assume-role \
     --role-arn "arn:aws:iam::000000000000:role/acme-shop-deploy" \
     --role-session-name demo-probe 2>/dev/null | jq -e '.Credentials.AccessKeyId' >/dev/null 2>&1; then
  echo "OK  deploy role assumable via STS (pivot path exists)"
  # ponytail: community LocalStack does not enforce IAM trust policies, so
  # this check cannot go RED on the hardened variant by itself; compare the
  # role's policy in state when the defend act needs a real fail signal.
else
  echo "FAIL could not assume acme-shop-deploy via STS"
  fail=1
fi

for p in db_password api_key; do
  if aws --endpoint-url http://localhost:4566 ssm get-parameter \
       --name "/prod/acme-shop/$p" --with-decryption --query 'Parameter.Value' \
       --output text 2>/dev/null | grep -q .; then
    echo "OK  ssm:/prod/acme-shop/$p exists"
  else
    echo "FAIL ssm:/prod/acme-shop/$p missing"
    fail=1
  fi
done

exit $fail