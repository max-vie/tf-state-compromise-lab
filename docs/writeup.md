# Writeup: the Terraform state and CI/CD pipeline compromise lab

## What this lab shows

This lab runs the "Terraform State & CI/CD Pipeline Compromise" threat end to end, then stops the same chain with defenses. A small e-commerce stack (the "Acme Shop") is deployed by a compromised pipeline, and the chain ends with the attacker erasing the shop's state. Every credential in the repo is fake and generated per run, and the attacker's collection endpoint is `http://localhost:8081` inside Docker; nothing here targets a real account.

## Setup

```sh
make up        # LocalStack + fake attacker webhook
make bootstrap # state bucket + lock table
make apply     # the compromised pipeline run
```

`make apply` deploys `scenarios/vulnerable/`: an asset bucket, one app server, an unhardened state backend (`scenarios/vulnerable/bootstrap/main.tf`), roles defined in `scenarios/vulnerable/iam.tf`, and runtime secrets in SSM (`scenarios/vulnerable/secrets.tf`).

## Act 1: state leak

The story starts with a leaked developer laptop: `attack/act1/history-leak/bash-history` is a shell history file holding long-lived AWS keys typed after `export`. `make attack` extracts them into `attack/act1/.stolen-creds.env`, and uses them to read the state object straight out of the S3 backend bucket. `terraform.tfstate` stores runtime secret values in plaintext, so the extraction step prints the database password and API key on camera.

**Defense.** The hardened deployment (`scenarios/hardened/secrets.tf`) passes secrets as write-only arguments: `value_wo` with `value_wo_version` (OpenTofu 1.11 or later). The provider sends the value to SSM on apply but never stores it in the state file, so a stolen state carries no secrets. `make defend` act 1 verifies this by searching the hardened state for both values and finding nothing.

## Act 2: rogue module

A pull request added a "usage reporting" module (`scenarios/vulnerable/telemetry.tf`, `scenarios/vulnerable/modules/usage-reporting/`) and the config passes `db_password` and `api_key` straight into it. The module's `terraform_data` beacon carries `triggers_replace = [timestamp()]`, so it re-creates and re-sends its payload on every apply; `|| true` keeps it from breaking the pipeline if the collector is down. The payload, with both secrets, lands in `.run/webhook/exfil.log`.

**Defense.** The hardened tree has no `telemetry.tf` and no module: the defense is at the merge gate, not in code. `make defend` act 2 checks that the hardened apply added nothing to the exfil log.

## Act 3: lateral movement

The deploy role in `scenarios/vulnerable/iam.tf` carries a policy with `Action = "*"` on `Resource = "*"` and is trusted by the static CI identity. The attacker assumes the role (`sts assume-role`) with the leaked keys and reads the production parameters `/prod/acme-shop/db_password` and `/prod/acme-shop/api_key` under it.

**Defense.** The hardened deploy role (`scenarios/hardened/iam.tf`) gets only what a deployment needs: read this stack's SSM parameters, fetch this stack's assets. No wildcard statement remains, so there is no catch-all to pivot with.

## Act 4: state sabotage

With everything useful already taken, the attacker goes after the backend: `scenarios/vulnerable/bootstrap/main.tf` created the state bucket without versioning, so a single `s3api delete-object` on the state object erases the shop's map (the same move removes the state digest tofu keeps in the lock table). The stack keeps running, but `tofu state pull` fails, no plan can be built, and there is no record of what was applied. The recovery check (`list-object-versions`) finds nothing: with versioning off, the delete was final. A plain re-apply only collides with the orphans it no longer knows about, which is why the demo rebuilds its environment fresh after the act; real incident response would import the orphans by hand.

**Defense.** The hardened bootstrap (`scenarios/hardened/bootstrap/main.tf`) enables S3 versioning, so the same delete only lays down a delete marker over the surviving version. `make defend` act 4 performs the full restore on camera: delete, show the marker and the surviving versions, remove the marker, pull the state again, and compare it byte for byte with the pre-delete pull. This is the one defense in the lab the emulator fully honors, since versioning is plain storage behavior rather than IAM enforcement.

## Honest limits

Community LocalStack enforces neither IAM policies nor S3 encryption semantics: it accepts the hardened settings and still lets any identity call any API. So `attack/defend/run.sh` proves the defenses by content, not by API denial: secrets absent from the state file, the exfil log unchanged by the hardened apply, and policy documents with no `*` in them. On real AWS, the scoped policy would be what actually denies the attacker, and the emulated reads would fail. The assume-role check in `scripts/check/stack-applied.sh` has the same ceiling and says so in a comment.

## Run it

```sh
make attack # the full chain against the vulnerable scenario
make defend # the same chain against the hardened scenario
make reset  # wipe everything (containers, volumes, logs) for a clean slate
```

## Beyond this lab

The real-world fixes this demo only points at: short-lived CI credentials through an OIDC provider instead of static keys, remote-state hygiene beyond what a demo can show (versioning and encryption plus a restrictive bucket policy on the state bucket), and injecting production secrets outside Terraform entirely.