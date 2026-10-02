# State backend for the hardened scenario.
#
# Real-AWS shape, like the vulnerable scenario's backend.tf; emulator-only
# settings come from backend-config/localstack.hcl via `make apply`.
#
# Pointed at its own bucket so both scenarios can be applied side by side
# in the single demo account:
#   bucket acme-shop-tfstate-hardened, key hardened/acme-shop.tfstate
# The bucket itself is provisioned by ../bootstrap, which IS hardened:
# versioning on, default encryption on, public access blocked. Contrast
# with ../../vulnerable/bootstrap/main.tf.

terraform {
  backend "s3" {
    bucket         = "acme-shop-tfstate-hardened"
    key            = "hardened/acme-shop.tfstate"
    region         = "us-east-1"
    dynamodb_table = "acme-shop-tfstate-hardened-locks"
  }
}