# Terraform state and CI/CD pipeline compromise lab

A scripted, reproducible demo of how a compromised Terraform setup breaks,
and of the defenses that stop each step:

1. State leak. Fake AWS keys leak, the state backend has no encryption, and
   the database password ends up readable straight out of `terraform.tfstate`.
2. Rogue module. An innocent-looking pull request adds a module that sends
   the deployed secrets to an attacker's server.
3. Lateral movement. The CI pipeline's over-broad IAM role is used to reach
   production data that a narrow runtime role owns.

The whole chain succeeds against the vulnerable scenario. Run it against the
hardened variant and it fails at every step.

The vulnerable scenario and its checks are in place. The attack scripts and
the hardened variant are not written yet.

## Safety

- Every credential in this repo is fake and generated per run. Nothing here
  targets a real AWS account.
- The exfiltration endpoint is `http://localhost:8081` inside Docker. It
  goes nowhere.
- Everything runs against LocalStack in Docker. The Terraform code applies
  unchanged to real AWS; see `docs/aws-migration.md`.

## Usage (once complete)

```sh
make up     # start LocalStack and the fake attacker webhook
make attack # run the attack chain against the vulnerable scenario
make defend # run it against the hardened scenario and watch it fail
```