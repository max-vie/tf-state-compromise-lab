#!/usr/bin/env bash
# Publish gates (run by `make verify` and by CI before anything ships):
#   1. The exfiltration endpoint is localhost only. No script or config in
#      attack/ may point anywhere else.
#   2. No real-looking credentials anywhere: gitleaks must find nothing, and
#      the demo's fake tokens must carry the demo-only: marker so they can
#      never be confused with live ones.
set -uo pipefail
fail=0

# 1. local-only exfil
if grep -rInE 'https?://' attack/ \
     | grep -vE 'localhost|127\.0\.0\.1|EXAMPLE\.COM' >/dev/null; then
  echo "FAIL non-localhost exfil endpoint found in attack/"
  grep -rInE 'https?://' attack/ | grep -vE 'localhost|127\.0\.0\.1'
  fail=1
else
  echo "OK  all exfil endpoints are localhost"
fi

# 2. gitleaks
if gitleaks detect --no-git --config .gitleaks.toml --redact >/tmp/gitleaks.out 2>&1; then
  echo "OK  gitleaks: no leaked-secrets findings"
else
  echo "FAIL gitleaks findings:"
  tail -20 /tmp/gitleaks.out
  fail=1
fi

# 3. demo secret values must be marked demo-only
if grep -rIn --include='*.tfvars' --include='*.env' 'db_password\|api_key' \
     scripts/env scenarios/*/localstack.tfvars \
     | grep -v 'demo-only:' >/dev/null; then
  echo "FAIL demo secret value missing the demo-only: marker"
  fail=1
else
  echo "OK  all demo secret values carry the demo-only: marker"
fi

exit $fail