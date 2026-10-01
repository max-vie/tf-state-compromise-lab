# Backend bootstrap for the vulnerable scenario.
#
# Creates the S3 state bucket and DynamoDB lock table that backend.tf
# points at. Deliberately NOT hardened: no versioning, no default
# encryption, no public-access block. This mirrors how most real backends
# looked before the whole "state hygiene" conversation, and it is what the
# hardened bootstrap/ contrasts against.
#
# Applied with `make bootstrap` (never by the main config: tofu cannot
# provision the backend it stores its state in).

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "registry.opentofu.org/hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

variable "aws_endpoints" {
  type    = map(string)
  default = {}
}

variable "skip_aws_validation" {
  type    = bool
  default = false
}

provider "aws" {
  region = "us-east-1"
  endpoints {
    s3       = try(var.aws_endpoints["s3"], null)
    dynamodb = try(var.aws_endpoints["dynamodb"], null)
  }
  skip_credentials_validation = var.skip_aws_validation
  skip_metadata_api_check     = var.skip_aws_validation
  skip_region_validation      = var.skip_aws_validation
  skip_requesting_account_id  = var.skip_aws_validation
  s3_use_path_style           = length(var.aws_endpoints) > 0
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "acme-shop-tfstate"
}

resource "aws_dynamodb_table" "tfstate_locks" {
  name         = "acme-shop-tfstate-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
