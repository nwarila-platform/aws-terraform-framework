variable "region" {
  description = "AWS region for the disposable e2e harness. Underscore and hyphen spellings are accepted."
  type        = string
  default     = "us-east-1"
  nullable    = false

  validation {
    condition     = contains(["us-east-1", "us_east_1"], var.region)
    error_message = "region must be us-east-1/us_east_1 for the reusable e2e harness."
  }
}

variable "name_prefix" {
  description = "Short suffix for the e2e Project tag; resources are tagged Project=e2e-NAME_PREFIX."
  type        = string
  default     = "e2e"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,24}$", var.name_prefix))
    error_message = "name_prefix must start with a lowercase letter or number and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "operator_cidr" {
  description = "REQUIRED CIDR allowed to SSH to the public runner."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost(var.operator_cidr, 0))
    error_message = "operator_cidr must be a valid IPv4 or IPv6 CIDR block."
  }
}

variable "use_runner" {
  description = "When true, create the public runner EC2 and run the framework from inside the VPC."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_rds" {
  description = "Render and verify the RDS scenario in the generated framework tfvars."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_lb" {
  description = "Render and verify the internal ALB scenario in the generated framework tfvars."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_nlb" {
  description = "Reserved toggle for a future internal NLB variant; default e2e coverage keeps this off."
  type        = bool
  default     = false
  nullable    = false
}
