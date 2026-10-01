#!/usr/bin/env bash
# Portability gate: the AWS-recreatability requirement.
#
# Rule: all infrastructure code under scenarios/ plus the Makefile must
# contain zero references to LocalStack or the emulator endpoint. The ONLY
# files allowed to carry LocalStack configuration are, by name:
#   scenarios/*/localstack.tfvars (and bootstrap/localstack.tfvars)
#   backend-config/localstack.hcl
# Docs, README, compose file and check/attack scripts may *talk* about
# LocalStack; the requirement is that no infrastructure code depends on it.

set -uo pipefail
fail=0

checked=$(find scenarios -name '*.tf' -not -path '*/.terraform/*' | sort)

for f in $checked; do
  case "$f" in
    scenarios/*/localstack.tfvars|scenarios/*/bootstrap/localstack.tfvars)
      continue ;;
  esac
  hits=$(grep -nE 'localhost:4566|[Ll]ocalstack' "$f" \
    | grep -vE 'localstack\.(tfvars|hcl|env)') || hits=""
  if test -n "$hits"; then
    echo "FAIL localstack reference in infrastructure code: $f"
    echo "$hits" | sed 's/^/    /'
    fail=1
  fi
done

# The Makefile may reference the designated files by name only.
mkhits=$(grep -nE 'localhost:4566|[Ll]ocalstack' Makefile \
  | grep -vE 'localstack\.(tfvars|env|hcl)') || mkhits=""
if test -n "$mkhits"; then
  echo "FAIL localstack reference in Makefile:"
  echo "$mkhits" | sed 's/^/    /'
  fail=1
fi

if test "$fail" -eq 0; then
  echo "OK  infrastructure code (tofu + Makefile) is AWS-clean; LocalStack config lives only in designated files"
fi
exit $fail