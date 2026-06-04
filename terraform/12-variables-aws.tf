#% =========================================================================================== %#
#% = File: 12-variables-aws.tf                                   | Category: variables (10-19) %#
#% ------------------------------------------------------------------------------------------- %#
#% =========================================================================================== %#

# Define Provider Configuration Options.
variable "aws_config" {
  description = "Define all of the required environmental variables specific to the AWS provider."
  type = object({
    regions = list(string)
  })

  default = {
    regions = ["us_east_1", "us_west_2"]
  }
  nullable = false
}

variable "all_load_balancers" {
  description = "Define all Elastic Load Balancers managed by this framework."

  type = list(object({
    /* Required Parameters */
    region       = string
    resource_key = string

    /* Optional Parameters */
    access_logs = optional(object({
      bucket  = string
      enabled = optional(bool)
      prefix  = optional(string)
    }))
    client_keep_alive = optional(number)
    connection_logs = optional(object({
      bucket  = string
      enabled = optional(bool)
      prefix  = optional(string)
    }))
    customer_owned_ipv4_pool                                     = optional(string)
    desync_mitigation_mode                                       = optional(string)
    dns_record_client_routing_policy                             = optional(string)
    drop_invalid_header_fields                                   = optional(bool)
    enable_cross_zone_load_balancing                             = optional(bool)
    enable_deletion_protection                                   = optional(bool, true)
    enable_http2                                                 = optional(bool)
    enable_tls_version_and_cipher_suite_headers                  = optional(bool)
    enable_waf_fail_open                                         = optional(bool)
    enable_xff_client_port                                       = optional(bool)
    enable_zonal_shift                                           = optional(bool)
    enforce_security_group_inbound_rules_on_private_link_traffic = optional(string)
    health_check_logs = optional(object({
      bucket  = string
      enabled = optional(bool)
      prefix  = optional(string)
    }))
    idle_timeout    = optional(number)
    internal        = optional(bool, true)
    ip_address_type = optional(string, "ipv4")
    ipam_pools = optional(object({
      ipv4_ipam_pool_id = string
    }))
    load_balancer_type = optional(string, "application")
    minimum_load_balancer_capacity = optional(object({
      capacity_units = number
    }))
    name                                   = optional(string)
    name_prefix                            = optional(string)
    preserve_host_header                   = optional(bool)
    secondary_ips_auto_assigned_per_subnet = optional(number)
    security_groups                        = optional(list(string))
    subnet_mapping = optional(list(object({
      allocation_id        = optional(string)
      ipv6_address         = optional(string)
      private_ipv4_address = optional(string)
      subnet_id            = string
    })), [])
    subnets = optional(list(string), [])
    tags    = optional(map(string), {})
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
      update = optional(string)
    }))
    xff_header_processing_mode = optional(string)
  }))

  default  = []
  nullable = false

  validation {
    condition = length(distinct([
      for load_balancer in var.all_load_balancers : load_balancer.resource_key
    ])) == length(var.all_load_balancers)
    error_message = "Each all_load_balancers entry must have a unique resource_key."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      can(regex("^[0-9A-Za-z][0-9A-Za-z_-]*$", load_balancer.resource_key))
    ])
    error_message = "Each all_load_balancers resource_key must start with a letter or number and contain only letters, numbers, underscores, or hyphens."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.name == null || can(regex("^[0-9A-Za-z]([0-9A-Za-z-]{0,30}[0-9A-Za-z])?$", load_balancer.name))
    ])
    error_message = "Each load balancer name must be 1-32 characters, contain only letters, numbers, and hyphens, and not begin or end with a hyphen."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.name == null || load_balancer.name_prefix == null
    ])
    error_message = "Each all_load_balancers entry must set at most one of name or name_prefix."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      (length(load_balancer.subnets) > 0 ? 1 : 0) + (length(load_balancer.subnet_mapping) > 0 ? 1 : 0) == 1
    ])
    error_message = "Each all_load_balancers entry must set exactly one of subnets or subnet_mapping."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      contains(var.aws_config.regions, replace(load_balancer.region, "-", "_"))
    ])
    error_message = "Each all_load_balancers entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      contains(["application", "gateway", "network"], load_balancer.load_balancer_type)
    ])
    error_message = "load_balancer_type must be application, gateway, or network."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      contains(["dualstack", "dualstack-without-public-ipv4", "ipv4"], load_balancer.ip_address_type)
    ])
    error_message = "ip_address_type must be dualstack, dualstack-without-public-ipv4, or ipv4."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.ip_address_type != "dualstack-without-public-ipv4" || load_balancer.load_balancer_type == "application"
    ])
    error_message = "ip_address_type dualstack-without-public-ipv4 is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      !load_balancer.internal || load_balancer.ip_address_type == "ipv4"
    ])
    error_message = "Internal load balancers must use ip_address_type ipv4."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.client_keep_alive == null || (load_balancer.client_keep_alive >= 60 && load_balancer.client_keep_alive <= 604800)
    ])
    error_message = "client_keep_alive must be between 60 and 604800 seconds."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.desync_mitigation_mode == null || contains(["defensive", "monitor", "strictest"], load_balancer.desync_mitigation_mode)
    ])
    error_message = "desync_mitigation_mode must be defensive, monitor, or strictest."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.dns_record_client_routing_policy == null || contains(["any_availability_zone", "availability_zone_affinity", "partial_availability_zone_affinity"], load_balancer.dns_record_client_routing_policy)
    ])
    error_message = "dns_record_client_routing_policy must be any_availability_zone, availability_zone_affinity, or partial_availability_zone_affinity."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.dns_record_client_routing_policy == null || load_balancer.load_balancer_type == "network"
    ])
    error_message = "dns_record_client_routing_policy is only valid for network load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.drop_invalid_header_fields == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "drop_invalid_header_fields is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.enable_http2 == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "enable_http2 is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.enable_tls_version_and_cipher_suite_headers == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "enable_tls_version_and_cipher_suite_headers is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.enable_xff_client_port == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "enable_xff_client_port is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.enforce_security_group_inbound_rules_on_private_link_traffic == null || contains(["off", "on"], load_balancer.enforce_security_group_inbound_rules_on_private_link_traffic)
    ])
    error_message = "enforce_security_group_inbound_rules_on_private_link_traffic must be off or on."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.enforce_security_group_inbound_rules_on_private_link_traffic == null || load_balancer.load_balancer_type == "network"
    ])
    error_message = "enforce_security_group_inbound_rules_on_private_link_traffic is only valid for network load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.idle_timeout == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "idle_timeout is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.ipam_pools == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "ipam_pools is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.minimum_load_balancer_capacity == null || contains(["application", "network"], load_balancer.load_balancer_type)
    ])
    error_message = "minimum_load_balancer_capacity is only valid for application or network load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.preserve_host_header == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "preserve_host_header is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.secondary_ips_auto_assigned_per_subnet == null || (load_balancer.secondary_ips_auto_assigned_per_subnet >= 0 && load_balancer.secondary_ips_auto_assigned_per_subnet <= 7)
    ])
    error_message = "secondary_ips_auto_assigned_per_subnet must be between 0 and 7."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.secondary_ips_auto_assigned_per_subnet == null || load_balancer.load_balancer_type == "network"
    ])
    error_message = "secondary_ips_auto_assigned_per_subnet is only valid for network load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.security_groups == null || load_balancer.load_balancer_type != "gateway"
    ])
    error_message = "security_groups is only valid for application or network load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.connection_logs == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "connection_logs is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.health_check_logs == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "health_check_logs is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.xff_header_processing_mode == null || load_balancer.load_balancer_type == "application"
    ])
    error_message = "xff_header_processing_mode is only valid for application load balancers."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.xff_header_processing_mode == null || contains(["append", "preserve", "remove"], load_balancer.xff_header_processing_mode)
    ])
    error_message = "xff_header_processing_mode must be append, preserve, or remove."
  }
}
