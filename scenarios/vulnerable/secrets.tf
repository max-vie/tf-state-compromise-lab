# Runtime secrets stored in SSM Parameter Store.
#
# This is the Act 1 extraction target: after `apply`, the *values* (not
# references!) of these parameters are sitting in terraform.tfstate, so
# anyone who can read the state can read the database password. The
# hardened variant fixes this pattern; see docs/writeup.md.

resource "aws_ssm_parameter" "db_password" {
  name  = "/prod/${local.shop_name}/db_password"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ssm_parameter" "api_key" {
  name  = "/prod/${local.shop_name}/api_key"
  type  = "SecureString"
  value = var.api_key
}