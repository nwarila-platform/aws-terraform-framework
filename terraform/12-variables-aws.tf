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

  validation {
    condition     = length(var.aws_config.regions) == 2 && toset(var.aws_config.regions) == toset(["us_east_1", "us_west_2"])
    error_message = "aws_config.regions must be exactly [\"us_east_1\", \"us_west_2\"]. Supporting other/additional regions requires new provider aliases and per-region resource blocks (a code change), not just a variable edit."
  }
}

variable "windows_ami_owners" {
  description = "AWS account IDs or owner aliases that own the public AWS Windows Server Base AMI. Defaults to Amazon's public AMIs; override only when mirroring those images into another account."
  type        = list(string)
  default     = ["amazon"]
  nullable    = false
}

variable "windows_openssh_source" {
  description = "Optional local Feature-on-Demand source path for installing the OpenSSH.Server capability on Windows Server 2019/2022 in air-gapped / no-egress environments (passed to 'Add-WindowsCapability -Source <path> -LimitAccess'). Leave empty (default) to install from Windows Update, which requires outbound egress. Ignored on Windows Server 2025 (OpenSSH ships preinstalled) and on any instance where OpenSSH is already Present."
  type        = string
  default     = ""
  nullable    = false
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
    target_groups = optional(list(object({
      resource_key                      = string
      function                          = string
      vpc_id                            = string
      port                              = number
      protocol                          = string
      protocol_version                  = optional(string)
      target_type                       = optional(string, "instance")
      deregistration_delay              = optional(number)
      slow_start                        = optional(number)
      load_balancing_algorithm_type     = optional(string)
      load_balancing_anomaly_mitigation = optional(string)
      load_balancing_cross_zone_enabled = optional(string)
      preserve_client_ip                = optional(string)
      proxy_protocol_v2                 = optional(bool)
      connection_termination            = optional(bool)
      ip_address_type                   = optional(string)
      health_check = optional(object({
        enabled             = optional(bool)
        healthy_threshold   = optional(number)
        interval            = optional(number)
        matcher             = optional(string)
        path                = optional(string)
        port                = optional(string)
        protocol            = optional(string)
        timeout             = optional(number)
        unhealthy_threshold = optional(number)
      }))
      stickiness = optional(object({
        type            = string
        cookie_duration = optional(number)
        cookie_name     = optional(string)
        enabled         = optional(bool, true)
      }))
      tags = optional(map(string), {})
    })), [])
    listeners = optional(list(object({
      resource_key                = string
      port                        = number
      protocol                    = optional(string)
      ssl_policy                  = optional(string)
      alpn_policy                 = optional(string)
      certificate_arn             = optional(string)
      additional_certificate_arns = optional(list(string), [])
      default_action = object({
        type             = optional(string, "forward")
        target_group_key = optional(string)
        redirect = optional(object({
          status_code = string
          host        = optional(string)
          path        = optional(string)
          port        = optional(string)
          protocol    = optional(string)
          query       = optional(string)
        }))
        fixed_response = optional(object({
          content_type = string
          message_body = optional(string)
          status_code  = optional(string)
        }))
      })
      rules = optional(list(object({
        resource_key = string
        priority     = number
        action = object({
          type             = optional(string, "forward")
          target_group_key = optional(string)
          redirect = optional(object({
            status_code = string
            host        = optional(string)
            path        = optional(string)
            port        = optional(string)
            protocol    = optional(string)
            query       = optional(string)
          }))
          fixed_response = optional(object({
            content_type = string
            message_body = optional(string)
            status_code  = optional(string)
          }))
        })
        conditions = list(object({
          host_header         = optional(list(string))
          path_pattern        = optional(list(string))
          http_request_method = optional(list(string))
          source_ip           = optional(list(string))
          http_header = optional(object({
            http_header_name = string
            values           = list(string)
          }))
          query_string = optional(list(object({
            key   = optional(string)
            value = string
          })))
        }))
      })), [])
    })), [])
    tags = optional(map(string), {})
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
      load_balancer.internal == true
    ])
    error_message = "Each all_load_balancers entry must be internal; public load balancers are not allowed."
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
      !contains(["application", "network"], load_balancer.load_balancer_type) ||
      (load_balancer.security_groups != null && length(load_balancer.security_groups) > 0)
    ])
    error_message = "Application and network load balancers must specify at least one security group; omitting it attaches the VPC default (allow-all) security group."
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

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      length(distinct([
        for target_group in load_balancer.target_groups : target_group.resource_key
      ])) == length(load_balancer.target_groups)
    ])
    error_message = "Each all_load_balancers target_groups entry must have a unique resource_key within its load balancer."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for target_group in load_balancer.target_groups :
        can(regex("^[0-9A-Za-z][0-9A-Za-z_-]*$", target_group.resource_key))
      ]
    ]))
    error_message = "Each all_load_balancers target_groups resource_key must start with a letter or number and contain only letters, numbers, underscores, or hyphens."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      length(distinct([
        for listener in load_balancer.listeners : listener.resource_key
      ])) == length(load_balancer.listeners)
    ])
    error_message = "Each all_load_balancers listeners entry must have a unique resource_key within its load balancer."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners :
        length(distinct([
          for rule in listener.rules : rule.resource_key
        ])) == length(listener.rules)
      ]
    ]))
    error_message = "Each all_load_balancers listener rule must have a unique resource_key within its listener."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners :
        length(distinct([
          for rule in listener.rules : rule.priority
        ])) == length(listener.rules)
      ]
    ]))
    error_message = "Each all_load_balancers listener rule must have a unique priority within its listener."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules :
          rule.priority >= 1 && rule.priority <= 50000
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule priority must be between 1 and 50000."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners :
        listener.default_action.target_group_key == null ? true : contains([
          for target_group in load_balancer.target_groups : target_group.resource_key
        ], listener.default_action.target_group_key)
      ]
    ]))
    error_message = "Each all_load_balancers listener default_action target_group_key must reference a target_groups resource_key on the same load balancer."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules :
          rule.action.target_group_key == null ? true : contains([
            for target_group in load_balancer.target_groups : target_group.resource_key
          ], rule.action.target_group_key)
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule action target_group_key must reference a target_groups resource_key on the same load balancer."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners :
        listener.default_action.type == "forward" ? (
          listener.default_action.target_group_key != null &&
          listener.default_action.redirect == null &&
          listener.default_action.fixed_response == null
          ) : listener.default_action.type == "redirect" ? (
          listener.default_action.target_group_key == null &&
          listener.default_action.redirect != null &&
          listener.default_action.fixed_response == null
          ) : listener.default_action.type == "fixed-response" ? (
          listener.default_action.target_group_key == null &&
          listener.default_action.redirect == null &&
          listener.default_action.fixed_response != null
        ) : false
      ]
    ]))
    error_message = "Each all_load_balancers listener default_action must set exactly one payload matching type: forward requires target_group_key only, redirect requires redirect only, and fixed-response requires fixed_response only."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules :
          rule.action.type == "forward" ? (
            rule.action.target_group_key != null &&
            rule.action.redirect == null &&
            rule.action.fixed_response == null
            ) : rule.action.type == "redirect" ? (
            rule.action.target_group_key == null &&
            rule.action.redirect != null &&
            rule.action.fixed_response == null
            ) : rule.action.type == "fixed-response" ? (
            rule.action.target_group_key == null &&
            rule.action.redirect == null &&
            rule.action.fixed_response != null
          ) : false
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule action must set exactly one payload matching type: forward requires target_group_key only, redirect requires redirect only, and fixed-response requires fixed_response only."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for target_group in load_balancer.target_groups :
        trimspace(target_group.function) != ""
      ]
    ]))
    error_message = "Each all_load_balancers target_groups entry must set a non-empty function."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for target_group in load_balancer.target_groups :
        trimspace(target_group.vpc_id) != ""
      ]
    ]))
    error_message = "Each all_load_balancers target_groups entry must set a non-empty vpc_id."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for target_group in load_balancer.target_groups :
        target_group.target_type == "instance"
      ]
    ]))
    error_message = "Each all_load_balancers target_groups target_type must be instance."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules :
          length(rule.conditions) >= 1
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule must set at least one condition."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules : [
            for condition in rule.conditions :
            length(compact([
              condition.host_header == null ? "" : "host_header",
              condition.http_header == null ? "" : "http_header",
              condition.http_request_method == null ? "" : "http_request_method",
              condition.path_pattern == null ? "" : "path_pattern",
              condition.query_string == null ? "" : "query_string",
              condition.source_ip == null ? "" : "source_ip",
            ])) == 1
          ]
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule condition must set exactly one of host_header, http_header, http_request_method, path_pattern, query_string, or source_ip."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules : [
            for condition in rule.conditions :
            (condition.host_header == null ? true : length(condition.host_header) > 0) &&
            (condition.path_pattern == null ? true : length(condition.path_pattern) > 0) &&
            (condition.http_request_method == null ? true : length(condition.http_request_method) > 0) &&
            (condition.source_ip == null ? true : length(condition.source_ip) > 0) &&
            (condition.http_header == null ? true : length(condition.http_header.values) > 0) &&
            (condition.query_string == null ? true : length(condition.query_string) > 0)
          ]
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule condition value list must be non-empty when set."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners :
        length(distinct(listener.additional_certificate_arns)) == length(listener.additional_certificate_arns)
      ]
    ]))
    error_message = "Each all_load_balancers listener additional_certificate_arns list must not contain duplicates."
  }
}

variable "managed_keypairs" {
  description = "EC2 key pairs this framework creates instead of consuming pre-existing ones. Map key = the key-pair name that all_systems[*].key_name references; the value supplies the PUBLIC half only, so the private key stays wherever the deploy pipeline keeps its secrets and never enters Terraform state. Each managed key pair is created in both supported regions so any system may reference it. The empty default preserves the consume-pre-existing behavior exactly (zero plan change for existing consumers)."

  type = map(object({
    public_key = string
    tags       = optional(map(string), {})
  }))

  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name, keypair in var.managed_keypairs :
      can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521))\\s+\\S+", keypair.public_key))
    ])
    error_message = "managed_keypairs public_key values must be single-line OpenSSH public keys (ssh-ed25519, ssh-rsa, or ecdsa-sha2-nistp*)."
  }
}
