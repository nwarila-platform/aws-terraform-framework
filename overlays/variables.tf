variable "environment" {
  description = <<-EOT
    Deployment environment tag value applied to managed AWS resources.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.environment)) > 0 && length(var.environment) <= 256
    error_message = "environment must not be empty and must be at most 256 characters so its framework-generated tag values fit the EC2 tag-value limit."
  }
}

variable "resource_metadata" {
  description = <<-EOT
    Deployment identity stamped onto every taggable AWS resource through provider default_tags.
    Stable fields answer who owns and manages a resource; commit_sha and run_id trace it to the
    exact commit and workflow run. The deploy workflow populates this through
    TF_VAR_resource_metadata; the null default emits zero identity tags.
  EOT

  type = object({
    repository    = string
    repository_id = string
    stack         = string
    owner         = string
    commit_sha    = string
    run_id        = string
  })

  default  = null
  nullable = true

  validation {
    condition     = var.resource_metadata == null ? true : can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.resource_metadata.repository))
    error_message = "resource_metadata.repository must be an owner/name slug (e.g. nwarila-platform/aws-terraform-framework)."
  }

  validation {
    condition     = var.resource_metadata == null ? true : can(regex("^[0-9]+$", var.resource_metadata.repository_id))
    error_message = "resource_metadata.repository_id must be the numeric, rename-stable GitHub repository id."
  }

  validation {
    condition     = var.resource_metadata == null ? true : (length(trimspace(var.resource_metadata.stack)) > 0 && length(trimspace(var.resource_metadata.owner)) > 0)
    error_message = "resource_metadata.stack and owner must be non-empty (owner is a team, not a person)."
  }

  validation {
    condition     = var.resource_metadata == null ? true : (var.resource_metadata.commit_sha == null ? true : can(regex("^[0-9a-f]{40}$", var.resource_metadata.commit_sha)))
    error_message = "resource_metadata.commit_sha must be the lowercase 40-character checked-out commit SHA (git rev-parse HEAD after checkout, not github.sha)."
  }

  validation {
    condition     = var.resource_metadata == null ? true : (var.resource_metadata.run_id == null ? true : can(regex("^[0-9]+$", var.resource_metadata.run_id)))
    error_message = "resource_metadata.run_id must be the numeric GitHub Actions run id."
  }

  validation {
    condition = var.resource_metadata == null ? true : alltrue([
      length(var.resource_metadata.repository) <= 256,
      length(var.resource_metadata.repository_id) <= 256,
      length(var.resource_metadata.stack) <= 256,
      length(var.resource_metadata.owner) <= 256,
      var.resource_metadata.commit_sha == null ? true : length(var.resource_metadata.commit_sha) <= 256,
      var.resource_metadata.run_id == null ? true : length(var.resource_metadata.run_id) <= 256,
    ])
    error_message = "Each resource_metadata value must be at most 256 characters so its provider-default tag value fits the EC2 tag-value limit."
  }

  validation {
    # The tautological first term binds this cross-variable invariant to its declared variable;
    # the tag namespace remains reserved whether metadata is null or populated.
    condition = (var.resource_metadata == null || var.resource_metadata != null) && alltrue([
      for tags in [for name, network in var.networks : network.tags == null ? {} : network.tags] :
      alltrue([for key in keys(tags) : !startswith(lower(key), "nwarila:")])
    ])
    error_message = "The nwarila: tag namespace is reserved for resource_metadata-derived tags; consumer-supplied tag maps must not use it."
  }
}

variable "networks" {
  description = <<-EOT
    Throwaway per-deployment networks. Each entry creates one VPC, public subnet, internet gateway,
    route table, default route, and route-table association. The map key becomes the symbolic alias
    emitted to the framework; the empty default creates no resources.
  EOT

  type = map(object({
    availability_zone = string
    vpc_cidr          = string
    subnet_cidr       = string
    tags              = map(string)
  }))

  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name, network in var.networks :
      !can(regex("^subnet-", name))
    ])
    error_message = "A networks key is a symbolic network name and must not begin with 'subnet-'; this mirrors framework network_aliases rule V1b so the output cannot be mistaken for a literal subnet reference."
  }

  validation {
    condition = alltrue([
      for name, network in var.networks :
      network.availability_zone != null &&
      network.vpc_cidr != null &&
      network.subnet_cidr != null &&
      network.tags != null
    ])
    error_message = "Each networks entry must set availability_zone, vpc_cidr, subnet_cidr, and tags explicitly; use tags = {} when no consumer tags are needed."
  }

  validation {
    condition = alltrue([
      for name, network in var.networks :
      can(regex("^us-east-1[a-f]$", network.availability_zone))
    ])
    error_message = "Each networks availability_zone must be one of us-east-1a through us-east-1f; the shared ephemeral-poc.tfvars profile pins us-east-1a."
  }

  validation {
    condition = alltrue(flatten([
      for name, network in var.networks : [
        for cidr in [network.vpc_cidr, network.subnet_cidr] :
        can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$", cidr)) &&
        can(cidrhost(cidr, 0))
      ]
    ]))
    error_message = "Each networks vpc_cidr and subnet_cidr must be a valid IPv4 CIDR block; IPv6 and malformed octets are unsupported."
  }

  validation {
    condition = alltrue([
      for name, network in var.networks : try(
        tonumber(split("/", network.subnet_cidr)[1]) >= tonumber(split("/", network.vpc_cidr)[1]) &&
        sum([for index, octet in split(".", cidrhost(network.subnet_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) >= sum([for index, octet in split(".", cidrhost(network.vpc_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) &&
        sum([for index, octet in split(".", cidrhost(network.subnet_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) + pow(2, 32 - tonumber(split("/", network.subnet_cidr)[1])) - 1 <= sum([for index, octet in split(".", cidrhost(network.vpc_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) + pow(2, 32 - tonumber(split("/", network.vpc_cidr)[1])) - 1,
        false
      )
    ])
    error_message = "Each networks subnet_cidr must be wholly contained within its vpc_cidr."
  }

  validation {
    condition = alltrue([
      for name, network in var.networks : try(
        tonumber(split("/", network.vpc_cidr)[1]) >= 16 &&
        tonumber(split("/", network.vpc_cidr)[1]) <= 28 &&
        tonumber(split("/", network.subnet_cidr)[1]) >= 16 &&
        tonumber(split("/", network.subnet_cidr)[1]) <= 28,
        false
      )
    ])
    error_message = "Each networks VPC and subnet prefix length must be between /16 and /28 inclusive, matching AWS VPC and subnet limits."
  }
}
