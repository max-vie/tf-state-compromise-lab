# Backend bootstrap for the hardened scenario.
#
# The hardened contrast to ../../vulnerable/bootstrap/main.tf:
#   - S3 versioning enabled (state versions survive deletion)
#   - default server-side encryption (AES256)
#   - public access blocked (all four settings)
# Applied with `make bootstrap SCENARIO=hardened`.

terraform {
  required_version = ">= 1.11"
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
  bucket = "acme-shop-tfstate-hardened"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_locks" {
  name         = "acme-shop-tfstate-hardened-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}