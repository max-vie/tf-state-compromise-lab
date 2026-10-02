# Runtime secrets stored in SSM Parameter Store, hardened.
#
# Act 1's defense: the values are write-only arguments (value_wo, tofu
# >= 1.11). The provider sends them to SSM on apply but never stores them
# in terraform.tfstate, so a leaked state file carries no secrets. Rotate
# by bumping value_wo_version (tofu re-sends the value, nothing in state).

resource "aws_ssm_parameter" "db_password" {
  name             = "/prod/${local.shop_name}/db_password"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = 1
}

resource "aws_ssm_parameter" "api_key" {
  name             = "/prod/${local.shop_name}/api_key"
  type             = "SecureString"
  value_wo         = var.api_key
  value_wo_version = 1
}