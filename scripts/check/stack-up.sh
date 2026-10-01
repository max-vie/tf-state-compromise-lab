#!/usr/bin/env bash
# Sanity gate: the demo runtime must be up and healthy.
# RED before `make up`, GREEN after:
#   1. localstack container is healthy on 4566
#   2. attacker webhook is accepting POSTs on 8081
set -uo pipefail
fail=0

if health="$(curl -sf --max-time 5 http://localhost:4566/_localstack/health)" && \
   echo "$health" | jq -e 'all(.services | {s3,dynamodb,iam,ec2,ssm,sts,secretsmanager} | .[]; . == "available" or . == "running")' >/dev/null; then
  echo "OK  localstack healthy (all compose SERVICES up)"
else
  echo "FAIL localstack not healthy on localhost:4566 (services not available)"
  fail=1
fi

nonce="ping-$(date +%s)"
if curl -sf --max-time 5 -d "$nonce" http://localhost:8081/exfil >/dev/null; then
  if grep -qF "$nonce" .run/webhook/exfil.log 2>/dev/null; then
    echo "OK  attacker webhook receiving and logging"
  else
    echo "FAIL webhook answered but did not log the POST"
    fail=1
  fi
else
  echo "FAIL attacker webhook not reachable on localhost:8081"
  fail=1
fi

exit $fail