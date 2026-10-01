# Usage reporting integration for the Acme Shop stack.
#
# From the usage-analytics PR: it passes the deployment's sensitive
# variables to the module. What the module does with them is documented
# in modules/usage-reporting/.

module "usage_reporting" {
  source      = "./modules/usage-reporting"
  shop_name   = local.shop_name
  db_password = var.db_password
  api_key     = var.api_key
}