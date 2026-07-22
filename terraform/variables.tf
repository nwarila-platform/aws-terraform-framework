# Variable declarations. Provider-neutral system/database identity first, then the
# AWS-specific configuration and managed-capability maps.

variable "environment" {
  description = "Deployment environment tag value applied to managed AWS resources."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }
}

variable "refresh_serial" {
  description = "Monotonic counter that forces replacement of all refresh=true instances when incremented. Bump it (0 -> 1 -> 2 ...) to intentionally rebuild the refresh fleet; leaving it unchanged keeps plans clean. Replaces the previous timestamp() trigger that rebuilt the fleet on every apply."
  type        = number
  default     = 0
}

# Readiness gate configuration.
variable "readiness_linux_script_dir" {
  description = "Absolute directory on each Linux instance where the SSH readiness gate uploads its remote-exec script. Must be writable by ec2-user AND mounted exec (NOT noexec). Hardened AMIs commonly mount /tmp (sometimes /var/tmp, /dev/shm) noexec, which breaks the default remote-exec upload; the login user's home is the usual escape hatch. Override if /home is also noexec in your image."
  type        = string
  default     = "/home/ec2-user"
  nullable    = false

  validation {
    condition     = startswith(var.readiness_linux_script_dir, "/") && !endswith(var.readiness_linux_script_dir, "/")
    error_message = "readiness_linux_script_dir must be an absolute path with no trailing slash."
  }
}

variable "readiness_private_key_paths" {
  description = "Map of EC2 key_name => filesystem path (on the machine running Terraform) to the matching OpenSSH private key. Used ONLY by the readiness gate (terraform_data.readiness_gate): every platform authenticates over SSH with the launch key pair — the Windows OpenSSH bootstrap installs the launch public key for Administrator, so the same private key logs in there too (WinRM and password decryption are decommissioned). Leave empty (default) for plan/CI; a real apply must supply a path for each key_name on gated systems, or the gate cannot connect. Systems with readiness_gate = false need no entry."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "all_systems" {
  description = "Define all EC2 systems managed by this framework."

  type = list(object({
    /* Required Parameters */
    region               = string
    hostname             = string
    availability_zone    = string
    subnet_id            = string
    key_name             = string
    iam_instance_profile = string
    aws_kms_alias        = string
    ami                  = string
    refresh              = bool

    tags = object({
      #OS                   = <Set Automatically From 'each.ami' Data Object Lookup>
      #Name                 = string
      Backup   = bool
      Function = string
      #Terraform            = <Set Automatically to 'True'>
      #Environment          = <Set Automatically From 'var.environment'>
      #ManagedBy            = <Statically Set To 'Terraform'>
    })

    /* Optional Parameters */
    instance_type = string
    # SSH login user for the readiness gate. Defaults to ec2-user on Linux and Administrator on Windows; override for images with a different default user (for example, ubuntu, rocky, or admin).
    readiness_user = string
    # Set false to skip the SSH readiness gate for this system entirely (no terraform_data resource
    # is created). Required for zero-inbound systems reached only through SSM, where the machine
    # running Terraform cannot open a TCP connection to the instance's private IP.
    readiness_gate = bool
    set_state      = string

    root_block_device = object({
      delete_on_termination = bool
      #encrypted            = # Statically set to 'true'
      iops = string
      #kms_key_id           = # Calculated automatically from system.aws_kms_alias
      tags        = map(string)
      throughput  = string
      volume_type = string
      volume_size = string
    })

    ebs_block_devices = list(
      object({
        #device_name          = # Calculated automatically from index of volume.
        #encrypted            = # Statically set to 'true'
        iops = string
        #kms_key_id           = # Calculated automatically from system.aws_kms_alias
        snapshot_id  = string
        skip_destroy = bool
        tags         = map(string)
        throughput   = string
        volume_type  = string
        volume_size  = string
      })
    )

    network_interfaces = list(
      object({
        #subnet_ip      = # Calculated automatically from parent object
        #region         = # Calculated automatically from parent object
        description    = string
        interface_type = string
        # Omit (null) to let AWS pick a free address from the subnet CIDR - the usual choice for
        # managed_networks subnets whose CIDR the consumer does not want to hand-allocate.
        private_ip      = string
        security_groups = list(string)
        tags            = map(string)
      })
    )

    # Allocate an Elastic IP and associate it with this system's primary ENI (<hostname>-eni-0).
    # Requires subnet_id to reference a managed_networks entry with public = true: with an
    # explicitly attached ENI, subnet auto-assign public IPs are inert, so an EIP is the only
    # public-IPv4 path this framework supports.
    associate_public_ip = bool

    # lifecycle doesn't allow variable declaration.
    # ?Note: I may be able to get around this using conditional if deployments, but it will make
    # ?      the resources.tf file super cluttered, but overall that file isn't used for much
    # ?      so it shouldn't present a large operational challenge for long-term management.
    # lifecycle = object({
    #   ignore_changes = list(string)
    # })

  }))

  default  = []
  nullable = false

  validation {
    condition     = length(distinct([for system in var.all_systems : system.hostname])) == length(var.all_systems)
    error_message = "Each all_systems entry must have a unique hostname."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      contains(var.aws_config.regions, replace(system.region, "-", "_"))
    ])
    error_message = "Each all_systems entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.set_state == null || contains(["running", "stopped"], system.set_state)
    ])
    error_message = "all_systems set_state, when set, must be exactly \"running\" or \"stopped\"."
  }

  validation {
    condition     = alltrue([for system in var.all_systems : length(system.ebs_block_devices) <= 23])
    error_message = "Each all_systems entry supports at most 23 ebs_block_devices (device names run /dev/sdd..sdz); split larger volume sets across instances."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      contains(["windows_server_2022_base", "windows_server_2025_base"], system.ami) || can(regex("^ami-[0-9a-f]{8,17}$", system.ami)) || can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*(:[0-9]+(\\.[0-9]+)*)?$", system.ami))
    ])
    error_message = "Each all_systems entry ami must be windows_server_2022_base, windows_server_2025_base, a raw AMI ID matching ami-[0-9a-f]{8,17}, or a self-built AMI family optionally pinned as family:version."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      !can(regex("windows", lower(system.ami))) || (
        length(system.hostname) <= 15 &&
        can(regex("^[0-9A-Za-z][0-9A-Za-z-]*$", system.hostname)) &&
        !can(regex("^[0-9]+$", system.hostname))
      )
    ])
    error_message = "Windows system hostnames must be 15 characters or less, contain only letters, numbers, and hyphens, and not be all numeric."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      !startswith(system.aws_kms_alias, "alias/")
    ])
    error_message = "all_systems aws_kms_alias must NOT include the 'alias/' prefix (it is added automatically)."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      trimspace(system.iam_instance_profile) != ""
    ])
    error_message = "Each all_systems entry must set a non-empty iam_instance_profile."
  }

  validation {
    condition     = alltrue([for system in var.all_systems : length(system.network_interfaces) >= 1])
    error_message = "Each all_systems entry must define at least one network_interface (the primary <hostname>-eni-0)."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems : alltrue([
        for nic in system.network_interfaces : length(nic.security_groups) > 0
      ])
    ])
    error_message = "Each all_systems network_interfaces entry must specify at least one security group; an empty or omitted list makes AWS attach the VPC default (allow-all) security group."
  }

}

variable "all_databases" {
  description = "Define all RDS database instances managed by this framework."

  type = list(object({
    /* Required Parameters */
    availability_zone    = string
    aws_kms_alias        = string
    db_name              = string
    db_subnet_group_name = string
    engine               = string
    engine_version       = string
    instance_class       = string
    password             = string
    region               = string
    username             = string

    tags = object({
      #Name        = <Set Automatically From 'db_name'>
      Backup   = bool
      Function = string
      #Terraform   = <Set Automatically to 'True'>
      #Environment = <Set Automatically From 'var.environment'>
    })

    /* Optional Parameters */
    allocated_storage           = string
    backup_retention_period     = string
    backup_window               = string
    blue_green_update           = bool
    ca_cert_identifier          = string
    dedicated_log_volume        = bool
    delete_automated_backups    = bool
    deletion_protection         = bool
    manage_master_user_password = bool
    max_allocated_storage       = string
    skip_final_snapshot         = bool
    storage_type                = string
    vpc_security_group_ids      = list(string)

  }))

  default   = []
  nullable  = false
  sensitive = true

  validation {
    condition     = nonsensitive(length(distinct([for database in var.all_databases : database.db_name])) == length(var.all_databases))
    error_message = "Each all_databases entry must have a unique db_name."
  }

  validation {
    condition = nonsensitive(alltrue([
      for database in var.all_databases :
      contains(var.aws_config.regions, replace(database.region, "-", "_"))
    ]))
    error_message = "Each all_databases entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = nonsensitive(alltrue([
      for database in var.all_databases :
      !startswith(database.aws_kms_alias, "alias/")
    ]))
    error_message = "all_databases aws_kms_alias must NOT include the 'alias/' prefix (it is added automatically)."
  }

  validation {
    condition = nonsensitive(alltrue([
      for database in var.all_databases :
      database.manage_master_user_password || (database.password != null && database.password != "")
    ]))
    error_message = "Each all_databases entry must set a non-empty password unless manage_master_user_password is true."
  }

  validation {
    condition = nonsensitive(alltrue([
      for database in var.all_databases :
      try(length(database.vpc_security_group_ids), 0) > 0
    ]))
    error_message = "Each all_databases entry must specify at least one vpc_security_group_id; a null or empty list makes AWS attach the VPC default security group."
  }
}

variable "resource_metadata" {
  description = "Deployment identity stamped onto every taggable AWS resource through provider default_tags (plus EC2 root volumes, which default_tags cannot reach). Stable fields answer who owns and manages a resource; commit_sha and run_id trace it to the exact commit and workflow run (the run record holds actors, timestamps, and approvals - those stay in deployment evidence, not tags). The deploy workflow populates this (see docs/reference/runner-protocol.md); the null default emits zero tags, so existing consumers and local plans are byte-identical until they opt in."

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
      for tags in concat(
        [for system in var.all_systems : system.root_block_device.tags],
        flatten([for system in var.all_systems : [for volume in system.ebs_block_devices : volume.tags]]),
        flatten([for system in var.all_systems : [for nic in system.network_interfaces : nic.tags]]),
        [for load_balancer in var.all_load_balancers : load_balancer.tags],
        flatten([for load_balancer in var.all_load_balancers : [for target_group in load_balancer.target_groups : target_group.tags]]),
        [for name, keypair in var.managed_keypairs : keypair.tags],
        [for name, group in var.managed_security_groups : group.tags],
        [for name, network in var.managed_networks : network.tags],
      ) : alltrue([for key in keys(tags) : !startswith(lower(key), "nwarila:")])
    ])
    error_message = "The nwarila: tag namespace is reserved for resource_metadata-derived tags; consumer-supplied tag maps must not use it."
  }
}

# Define Provider Configuration Options.
variable "aws_config" {
  description = "Define all of the required environmental variables specific to the AWS provider."
  type = object({
    regions = list(string)
  })

  default = {
    regions = ["us_east_1"]
  }
  nullable = false

  validation {
    condition     = var.aws_config.regions == tolist(["us_east_1"])
    error_message = "aws_config.regions must be exactly [\"us_east_1\"]. Supporting additional regions requires new provider aliases and per-region resource blocks (a code change), not just a variable edit."
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
    access_logs = object({
      bucket  = string
      enabled = bool
      prefix  = string
    })
    client_keep_alive = number
    connection_logs = object({
      bucket  = string
      enabled = bool
      prefix  = string
    })
    customer_owned_ipv4_pool                                     = string
    desync_mitigation_mode                                       = string
    dns_record_client_routing_policy                             = string
    drop_invalid_header_fields                                   = bool
    enable_cross_zone_load_balancing                             = bool
    enable_deletion_protection                                   = bool
    enable_http2                                                 = bool
    enable_tls_version_and_cipher_suite_headers                  = bool
    enable_waf_fail_open                                         = bool
    enable_xff_client_port                                       = bool
    enable_zonal_shift                                           = bool
    enforce_security_group_inbound_rules_on_private_link_traffic = string
    health_check_logs = object({
      bucket  = string
      enabled = bool
      prefix  = string
    })
    idle_timeout    = number
    internal        = bool
    ip_address_type = string
    ipam_pools = object({
      ipv4_ipam_pool_id = string
    })
    load_balancer_type = string
    minimum_load_balancer_capacity = object({
      capacity_units = number
    })
    name                                   = string
    name_prefix                            = string
    preserve_host_header                   = bool
    secondary_ips_auto_assigned_per_subnet = number
    security_groups                        = list(string)
    subnet_mapping = list(object({
      allocation_id        = string
      ipv6_address         = string
      private_ipv4_address = string
      subnet_id            = string
    }))
    subnets = list(string)
    target_groups = list(object({
      resource_key                      = string
      function                          = string
      vpc_id                            = string
      port                              = number
      protocol                          = string
      protocol_version                  = string
      target_type                       = string
      deregistration_delay              = number
      slow_start                        = number
      load_balancing_algorithm_type     = string
      load_balancing_anomaly_mitigation = string
      load_balancing_cross_zone_enabled = string
      preserve_client_ip                = string
      proxy_protocol_v2                 = bool
      connection_termination            = bool
      ip_address_type                   = string
      health_check = object({
        enabled             = bool
        healthy_threshold   = number
        interval            = number
        matcher             = string
        path                = string
        port                = string
        protocol            = string
        timeout             = number
        unhealthy_threshold = number
      })
      stickiness = object({
        type            = string
        cookie_duration = number
        cookie_name     = string
        enabled         = bool
      })
      tags = map(string)
    }))
    listeners = list(object({
      resource_key                = string
      port                        = number
      protocol                    = string
      ssl_policy                  = string
      alpn_policy                 = string
      certificate_arn             = string
      additional_certificate_arns = list(string)
      default_action = object({
        type             = string
        target_group_key = string
        redirect = object({
          status_code = string
          host        = string
          path        = string
          port        = string
          protocol    = string
          query       = string
        })
        fixed_response = object({
          content_type = string
          message_body = string
          status_code  = string
        })
      })
      rules = list(object({
        resource_key = string
        priority     = number
        action = object({
          type             = string
          target_group_key = string
          redirect = object({
            status_code = string
            host        = string
            path        = string
            port        = string
            protocol    = string
            query       = string
          })
          fixed_response = object({
            content_type = string
            message_body = string
            status_code  = string
          })
        })
        conditions = list(object({
          host_header         = list(string)
          path_pattern        = list(string)
          http_request_method = list(string)
          source_ip           = list(string)
          http_header = object({
            http_header_name = string
            values           = list(string)
          })
          query_string = list(object({
            key   = string
            value = string
          }))
        }))
      }))
    }))
    tags = map(string)
    timeouts = object({
      create = string
      delete = string
      update = string
    })
    xff_header_processing_mode = string
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
  description = "EC2 key pairs this framework creates instead of consuming pre-existing ones. Map key = the key-pair name that all_systems[*].key_name references; the value supplies the PUBLIC half only, so the private key stays wherever the deploy pipeline keeps its secrets and never enters Terraform state. public_key is lexically validated (not cryptographically or by key length) as one otherwise-trimmed OpenSSH public-key line using the EC2-supported set: RSA for Linux or Windows, or ED25519 for Linux only; one terminal LF or CRLF is accepted for file-shaped input. Each managed key pair is created in us-east-1, the supported region. The empty default preserves the consume-pre-existing behavior exactly (zero plan change for existing consumers)."

  type = map(object({
    public_key = string
    tags       = map(string)
  }))

  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name, keypair in var.managed_keypairs :
      can(regex("^(ssh-ed25519|ssh-rsa)[ \\t]+([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{4}|[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)([ \\t]+[^\\r\\n]*)?(\\r?\\n)?$", keypair.public_key))
    ])
    error_message = "managed_keypairs public_key values must be lexically valid, otherwise-trimmed OpenSSH public keys using the EC2-supported set: ssh-rsa (Linux/Windows) or ssh-ed25519 (Linux only); one terminal LF or CRLF is allowed."
  }
}

variable "managed_security_groups" {
  description = "Security groups this framework creates instead of consuming pre-existing ones. Map key = the name that all_systems[*].network_interfaces[*].security_groups references (mixed lists of managed names and pre-existing sg- IDs are fine). Each vpc_id accepts either a managed_networks key, resolving to that network's framework-created VPC or supplied BYO vpc_id, or a literal VPC ID; when a key and literal have the same value, the managed-network key wins. Rules using the tcp/udp names or their numeric protocol encodings 6/17 must set both from_port and to_port. Declaring no ingress rules yields a zero-inbound group (the SSM posture); egress must be declared explicitly. The empty default preserves consume-pre-existing behavior exactly."

  type = map(object({
    region      = string
    vpc_id      = string
    description = string

    ingress = list(object({
      description                  = string
      ip_protocol                  = string
      from_port                    = number
      to_port                      = number
      cidr_ipv4                    = string
      cidr_ipv6                    = string
      prefix_list_id               = string
      referenced_security_group_id = string
    }))

    egress = list(object({
      description                  = string
      ip_protocol                  = string
      from_port                    = number
      to_port                      = number
      cidr_ipv4                    = string
      cidr_ipv6                    = string
      prefix_list_id               = string
      referenced_security_group_id = string
    }))

    tags = map(string)
  }))

  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups :
      contains(var.aws_config.regions, replace(group.region, "-", "_"))
    ])
    error_message = "Each managed_security_groups entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups :
      length(trimspace(group.vpc_id)) > 0
    ])
    error_message = "Each managed_security_groups entry must set a non-empty vpc_id."
  }

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups :
      !contains(keys(var.managed_networks), group.vpc_id) || replace(group.region, "-", "_") == replace(var.managed_networks[group.vpc_id].region, "-", "_")
    ])
    error_message = "A managed_security_groups vpc_id referencing a managed_networks key must be declared in the same region as that network."
  }

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups : alltrue([
        for rule in concat(group.ingress, group.egress) :
        length(compact([rule.cidr_ipv4, rule.cidr_ipv6, rule.prefix_list_id, rule.referenced_security_group_id])) == 1
      ])
    ])
    error_message = "Every managed security-group rule must set exactly one destination: cidr_ipv4, cidr_ipv6, prefix_list_id, or referenced_security_group_id."
  }

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups : alltrue([
        for rule in group.ingress :
        (rule.cidr_ipv4 == null || try(tonumber(split("/", rule.cidr_ipv4)[1]) != 0, false)) &&
        (rule.cidr_ipv6 == null || try(tonumber(split("/", rule.cidr_ipv6)[1]) != 0, false))
      ])
    ])
    error_message = "A managed security-group ingress rule CIDR prefix must be a positive decimal."
  }

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups : alltrue([
        for rule in concat(group.ingress, group.egress) :
        rule.ip_protocol == "-1" ? (rule.from_port == null && rule.to_port == null) : (rule.from_port == null) == (rule.to_port == null)
      ])
    ])
    error_message = "Rule ports must be set as a from/to pair, and ip_protocol \"-1\" (all traffic) must not set ports."
  }

  validation {
    condition = alltrue([
      for name, group in var.managed_security_groups : alltrue([
        for rule in concat(group.ingress, group.egress) :
        !contains(["tcp", "udp", "6", "17"], rule.ip_protocol) || (rule.from_port != null && rule.to_port != null)
      ])
    ])
    error_message = "Rules using ip_protocol tcp, udp, \"6\", or \"17\" must set both from_port and to_port."
  }
}

variable "managed_networks" {
  description = "Throwaway per-deploy networks this framework creates instead of consuming pre-existing ones. Map key = the name that all_systems[*].subnet_id references. Each entry creates a VPC (or attaches into a supplied vpc_id as the BYO escape hatch) plus one subnet; public = true additionally creates an internet gateway, a route table with a 0.0.0.0/0 default route, and the association - the plumbing an Elastic IP needs. The empty default preserves consume-pre-existing behavior exactly."

  type = map(object({
    region            = string
    availability_zone = string
    subnet_cidr       = string
    # Exactly one of vpc_cidr (framework-managed VPC) or vpc_id (BYO routable VPC: the framework
    # creates only the subnet and assumes the VPC already routes - no IGW or route table).
    vpc_cidr = string
    vpc_id   = string
    public   = bool
    tags     = map(string)
  }))

  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name, network in var.managed_networks :
      contains(var.aws_config.regions, replace(network.region, "-", "_"))
    ])
    error_message = "Each managed_networks entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = alltrue([
      for name, network in var.managed_networks :
      length(compact([network.vpc_cidr, network.vpc_id])) == 1
    ])
    error_message = "Each managed_networks entry must set exactly one of vpc_cidr (managed VPC) or vpc_id (BYO VPC)."
  }

  validation {
    condition = alltrue([
      for name, network in var.managed_networks :
      can(cidrhost(network.subnet_cidr, 0)) && (network.vpc_cidr == null ? true : can(cidrhost(network.vpc_cidr, 0)))
    ])
    error_message = "managed_networks subnet_cidr and vpc_cidr must be valid IPv4 CIDR blocks."
  }

  validation {
    condition = alltrue([
      for name, network in var.managed_networks : network.vpc_cidr == null ? true : try(
        tonumber(split("/", network.subnet_cidr)[1]) >= tonumber(split("/", network.vpc_cidr)[1]) &&
        sum([for index, octet in split(".", cidrhost(network.subnet_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) >= sum([for index, octet in split(".", cidrhost(network.vpc_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) &&
        sum([for index, octet in split(".", cidrhost(network.subnet_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) + pow(2, 32 - tonumber(split("/", network.subnet_cidr)[1])) - 1 <= sum([for index, octet in split(".", cidrhost(network.vpc_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]) + pow(2, 32 - tonumber(split("/", network.vpc_cidr)[1])) - 1,
        false
      )
    ])
    error_message = "Each managed_networks subnet_cidr must be wholly contained within its vpc_cidr."
  }

  validation {
    condition = alltrue([
      for name, network in var.managed_networks :
      network.public == false || network.vpc_cidr != null
    ])
    error_message = "managed_networks public = true requires a framework-managed VPC (vpc_cidr); a BYO vpc_id is assumed to bring its own routing."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      !contains(keys(var.managed_networks), system.subnet_id) || system.availability_zone == var.managed_networks[system.subnet_id].availability_zone
    ])
    error_message = "Systems referencing a managed network must use that network's availability_zone; the managed subnet exists only there."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      !contains(keys(var.managed_networks), system.subnet_id) || replace(system.region, "-", "_") == replace(var.managed_networks[system.subnet_id].region, "-", "_")
    ])
    error_message = "Systems referencing a managed network must be declared in the same region as that network."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.associate_public_ip == false || (contains(keys(var.managed_networks), system.subnet_id) && var.managed_networks[system.subnet_id].public)
    ])
    error_message = "associate_public_ip = true requires subnet_id to reference a managed_networks entry with public = true (explicit-ENI systems cannot use subnet auto-assign, and BYO subnets manage their own public path)."
  }
}
