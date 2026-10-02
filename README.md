# Terraform state and CI/CD pipeline compromise lab

A scripted, reproducible demo of how a compromised Terraform setup breaks,
and of the defenses that stop each step:

1. State leak. Fake AWS keys leak, the state backend has no encryption, and
   the database password ends up readable straight out of `terraform.tfstate`.
2. Rogue module. An innocent-looking pull request adds a module that sends
   the deployed secrets to an attacker's server on every pipeline run.
3. Lateral movement. The CI pipeline's over-broad IAM role is used to reach
   production data that a narrow runtime role owns.
4. State sabotage. The attacker deletes the state object; with no versioning
   on the backend bucket, that delete is final, and the shop cannot be
   rebuilt on its orphaned remains.

The whole chain succeeds against the vulnerable scenario. Run it against the
hardened variant and it fails at every step.

More background in `docs/`: a walkthrough of the whole attack chain and its
defenses (`docs/writeup.md`), and how to point the same Terraform at real AWS
(`docs/aws-migration.md`).

## Safety

- Every credential in this repo is fake and generated per run. Nothing here
  targets a real AWS account.
- The exfiltration endpoint is `http://localhost:8081` inside Docker. It
  goes nowhere.
- Everything runs against LocalStack in Docker. The Terraform code applies
  unchanged to real AWS; see `docs/aws-migration.md`.

## Usage

```sh
make up     # start LocalStack and the fake attacker webhook
make attack # run the kill chain: state leak, rogue module, lateral movement, state sabotage
make defend # apply the hardened scenario and watch the same chain stop
```

Both scenarios are complete and the gates in `scripts/check/` keep them honest.