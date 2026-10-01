# State backend.
#
# The values in the block are the real-AWS shape. Emulator-only backend
# settings (endpoint, validation skips) are NOT allowed here; they come
# from backend-config/localstack.hcl (designated file), passed by
# `make apply` as -backend-config. Without that flag, `tofu init` targets a real AWS
# account unchanged. That is the portability contract for this backend.
#
# The bucket and lock table themselves are created by ../bootstrap, which
# for this (vulnerable) scenario deliberately does NOT enable versioning,
# encryption or public-access blocking.

terraform {
  backend "s3" {
    bucket         = "acme-shop-tfstate"
    key            = "vulnerable/acme-shop.tfstate"
    region         = "us-east-1"
    dynamodb_table = "acme-shop-tfstate-locks"
  }
}
