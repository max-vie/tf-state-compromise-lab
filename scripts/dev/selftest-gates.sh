#!/usr/bin/env bash
# Proves the gate scripts have teeth: plants a violation for each gate,
# expects the gate to FAIL, removes the violation, expects the gate to PASS.
# Run any time the gates are edited. Exit 0 only if every gate both
# detected its violation and passed on a clean tree.
set -uo pipefail
fail=0
repo="$(git rev-parse --show-toplevel)"
cd "$repo"

expect_fail() { # label gate...
  local label="$1" gate="$2" rc
  shift 2
  "$@" >/dev/null 2>&1 && rc=0 || rc=$?
  if test "$rc" -ne 0; then
    echo "OK  planted violation detected: $label"
  else
    echo "FAIL gate '$gate' passed despite planted violation"
    fail=1
  fi
}

# 1. portability gate: localstack reference in infrastructure code
echo '  # planted localstack reference for selftest' >> scenarios/vulnerable/providers.tf
expect_fail "portability" aws-portability ./scripts/check/aws-portability.sh
sed -i '/planted localstack reference for selftest/d' scenarios/vulnerable/providers.tf

# 2. exfil endpoint gate: non-localhost URL under attack/
echo 'exfil to https://evil-collector.example.invalid/grab' > attack/webhook/selftest-probe
expect_fail "exfil" ports-and-secrets ./scripts/check/ports-and-secrets.sh
rm attack/webhook/selftest-probe

# 3. gitleaks: seeded stripe-shaped fake token outside the allowlist.
#    Constructed at runtime so this source file never contains a full
#    secret-shaped string (which would trip our own gitleaks gate).
tmpdir=$(mktemp -d)
printf 'token %s\n' "sk_live_51FakeKey$(head -c 24 /dev/zero | tr '\0' '0')" > "$tmpdir/probe.txt"
if gitleaks detect --no-git --source "$tmpdir" --config .gitleaks.toml >/dev/null 2>&1; then
  echo "FAIL gitleaks did not detect the seeded token"
  fail=1
else
  echo "OK  gitleaks detects the seeded token"
fi
rm -rf "$tmpdir"

# clean passes
./scripts/check/aws-portability.sh >/dev/null 2>&1 && \
  ./scripts/check/ports-and-secrets.sh >/dev/null 2>&1 || fail=1
test "$fail" -eq 0 && echo "CLEAN  all gates pass on a clean tree"

exit $fail