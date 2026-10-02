# Migrating off LocalStack

Everything under `scenarios/` targets real AWS unchanged. The portability contract: LocalStack-specific config lives only in three files, enforced by `scripts/check/aws-portability.sh`:

- `scenarios/*/localstack.tfvars`, plus each `bootstrap/localstack.tfvars`
- `backend-config/localstack.hcl`
- `scripts/env/localstack.env`

## Steps

1. Tear the demo down first: `make destroy SCENARIO=vulnerable` (repeat for the hardened scenario if applied), then `make down`. The attack scripts read stolen keys from files; a demo script must never run with a real account in its environment.
2. Put real credentials in `scripts/env/localstack.env`. It is the only file you swap; `make apply` and `make destroy` source it. Its current header says never to commit real credentials there, and that still holds: prefer a profile or SSO and export the keys into it at runtime.
3. Bootstrap the backend without the LocalStack var-file:

   ```sh
   tofu -chdir=scenarios/vulnerable/bootstrap init
   tofu -chdir=scenarios/vulnerable/bootstrap apply
   ```

   S3 bucket names are globally unique, so pick your own bucket names; here that means editing the names in `bootstrap/main.tf` and its `backend.tf`.
4. Apply without the emulator wiring:

   ```sh
   tofu -chdir=scenarios/vulnerable init
   tofu -chdir=scenarios/vulnerable apply
   ```

   Omit the `localstack.tfvars` var-file and everything the Makefile passes for LocalStack (`-backend-config` and the env file). The variables `aws_endpoints` and `skip_aws_validation` default so that their absence means plain AWS.
5. Replace the placeholder AMI in `scenarios/vulnerable/app.tf` (and the hardened copy) with a real AMI id for your region.

## What changes on real AWS

Two behaviors are real-AWS facts that the emulator only mimes. SSM `SecureString` values still land in `terraform.tfstate` in plaintext unless the write-only pattern from `scenarios/hardened/secrets.tf` is used, so use that pattern. IAM is actually enforced: the wide `Action = "*"` policy in `scenarios/vulnerable/iam.tf` would be a genuine pivot path, and state locking through the DynamoDB table becomes a behavior you will notice, not a detail.

The attack scripts and the webhook container are demo props. Leave them off; nothing in the real-AWS flow calls them.