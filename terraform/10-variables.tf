#% =========================================================================================== %#
#% = File: 10-variables.tf                                       | Category: variables (10-19) %#
#% ------------------------------------------------------------------------------------------- %#
#% =========================================================================================== %#

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

variable "ssh_readiness_linux_script_dir" {
  description = "Absolute directory on each Linux instance where the SSH readiness gate uploads its remote-exec script. Must be writable by ec2-user AND mounted exec (NOT noexec). Hardened AMIs commonly mount /tmp (sometimes /var/tmp, /dev/shm) noexec, which breaks the default remote-exec upload; the login user's home is the usual escape hatch. Override if /home is also noexec in your image."
  type        = string
  default     = "/home/ec2-user"
  nullable    = false

  validation {
    condition     = startswith(var.ssh_readiness_linux_script_dir, "/") && !endswith(var.ssh_readiness_linux_script_dir, "/")
    error_message = "ssh_readiness_linux_script_dir must be an absolute path with no trailing slash."
  }
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
    refresh              = optional(bool, false)

    tags = object({
      #OS                   = <Set Automatically From 'each.ami' Data Object Lookup>
      #Name                 = optional(string)
      Backup   = optional(bool, false)
      Function = string
      #Terraform            = <Set Automatically to 'True'>
      #Environment          = <Set Automatically From 'var.environment'>
      #ManagedBy            = <Statically Set To 'Terraform'>
    })

    /* Optional Parameters */
    ami           = optional(string, "ttc-rhel8")
    instance_type = optional(string, "m6i.large")
    set_state     = optional(string)

    root_block_device = optional(
      object({
        delete_on_termination = optional(bool, true)
        #encrypted            = # Statically set to 'true'
        iops = optional(string, null)
        #kms_key_id           = # Calculated automatically from system.aws_kms_alias
        tags        = optional(map(string), {})
        throughput  = optional(string, null)
        volume_type = optional(string, "gp3")
        volume_size = optional(string, "100")
      }),
      {}
    )

    ebs_block_devices = optional(
      list(
        object({
          #device_name          = # Calculated automatically from index of volume.
          #encrypted            = # Statically set to 'true'
          iops = optional(string, null)
          #kms_key_id           = # Calculated automatically from system.aws_kms_alias
          snapshot_id  = optional(string, null)
          skip_destroy = optional(bool, false)
          tags         = optional(map(string), {})
          throughput   = optional(string, null)
          volume_type  = optional(string, "gp3")
          volume_size  = optional(string, "100")
        })
      ),
      []
    )

    network_interfaces = list(
      object({
        #subnet_ip      = # Calculated automatically from parent object
        #region         = # Calculated automatically from parent object
        description     = optional(string)
        interface_type  = optional(string, null)
        private_ip      = string
        security_groups = list(string)
        tags            = optional(map(string), {})
      })
    )

    # lifecycle doesn't allow variable declaration.
    # ?Note: I may be able to get around this using conditional if deployments, but it will make
    # ?      the resources.tf file super cluttered, but overall that file isn't used for much
    # ?      so it shouldn't present a large operational challenge for long-term management.
    # lifecycle = optional(
    #   object({
    #     ignore_changes        = optional(list(string))
    #   })
    # )

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
    condition = alltrue([
      for system in var.all_systems : alltrue([
        for nic in system.network_interfaces : length(nic.security_groups) > 0
      ])
    ])
    error_message = "Each all_systems network_interfaces entry must specify at least one security group; an empty or omitted list makes AWS attach the VPC default (allow-all) security group."
  }

  # validation {
  #   condition     = length(distinct([for s in var.baseline_ami_systems : s.ip])) == length(var.baseline_ami_systems)
  #   error_message = "Duplicate 'private_ip' values detected. Each server will need a unique IPv4 address."
  # }

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
    password             = optional(string)
    region               = string
    username             = string

    tags = object({
      #Name        = <Set Automatically From 'db_name'>
      Function = string
      #Terraform   = <Set Automatically to 'True'>
      #Environment = <Set Automatically From 'var.environment'>
    })

    /* Optional Parameters */
    allocated_storage           = optional(string, "100")
    backup_retention_period     = optional(string, null)
    backup_window               = optional(string, null)
    blue_green_update           = optional(bool, false)
    ca_cert_identifier          = optional(string, null)
    dedicated_log_volume        = optional(bool, true)
    delete_automated_backups    = optional(bool, true)
    deletion_protection         = optional(bool, true)
    manage_master_user_password = optional(bool, true)
    max_allocated_storage       = optional(string, "1000")
    skip_final_snapshot         = optional(bool, false)
    storage_type                = optional(string)
    vpc_security_group_ids      = optional(list(string), null)

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
}