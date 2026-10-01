# LocalStack-only backend overrides, passed to `tofu init` by `make apply`
# as -backend-config. Without this flag file, the same backend.tf targets
# a real AWS account unchanged (see docs/aws-migration.md).
#
# With scenarios/*/localstack.tfvars and scripts/env/localstack.env, this
# is one of the only LocalStack-specific files in the repo;
# scripts/check/aws-portability.sh enforces that list.

endpoint                    = "http://localhost:4566"
dynamodb_endpoint           = "http://localhost:4566"
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_requesting_account_id  = true
use_path_style              = true