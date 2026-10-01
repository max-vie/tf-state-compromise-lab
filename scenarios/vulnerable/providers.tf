# Provider configuration.
#
# Real-AWS shape: nothing here knows about the emulator. The only knobs are
# two variables that default to a plain AWS setup; the emulator fills them
# via ../localstack.tfvars, which is the single emulator-specific mechanism
# in this scenario (enforced by scripts/check/aws-portability.sh).

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
  description = "AWS service endpoints override. Empty = real AWS."
  type        = map(string)
  default     = {}
}

variable "skip_aws_validation" {
  description = "Skip provider-side validation against the AWS account (only needed for the emulator)."
  type        = bool
  default     = false
}

provider "aws" {
  region = var.region
  endpoints {
    s3             = try(var.aws_endpoints["s3"], null)
    dynamodb       = try(var.aws_endpoints["dynamodb"], null)
    ec2            = try(var.aws_endpoints["ec2"], null)
    iam            = try(var.aws_endpoints["iam"], null)
    ssm            = try(var.aws_endpoints["ssm"], null)
    sts            = try(var.aws_endpoints["sts"], null)
    secretsmanager = try(var.aws_endpoints["secretsmanager"], null)
  }
  skip_credentials_validation = var.skip_aws_validation
  skip_metadata_api_check     = var.skip_aws_validation
  skip_region_validation      = var.skip_aws_validation
  skip_requesting_account_id  = var.skip_aws_validation
  # Path-style addressing is required for the emulator's S3, harmless on real AWS.
  s3_use_path_style = length(var.aws_endpoints) > 0
}

locals {
  shop_name = "acme-shop"
}
