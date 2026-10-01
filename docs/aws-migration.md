# Migrating off LocalStack

Planned. The rule this repo enforces: Terraform code under `scenarios/`
targets real AWS with no changes, and only these files carry LocalStack
settings (checked by `scripts/check/aws-portability.sh`):

- `scenarios/*/localstack.tfvars`, plus `bootstrap/localstack.tfvars`
- `backend-config/localstack.hcl`
- `scripts/env/localstack.env`

To run against real AWS, skip the LocalStack var-file and backend config,
set real credentials in `scripts/env/`, and replace the placeholder AMI in
`scenarios/vulnerable/app.tf` with a real one for your region.