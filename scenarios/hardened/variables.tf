variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Database master password (sensitive: plan-hidden, state-visible)"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "Payment provider API key (sensitive: plan-hidden, state-visible)"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "App server instance type"
  type        = string
  default     = "t3.micro"
}
