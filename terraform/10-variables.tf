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
    ami           = optional(string, "red_hat_enterprise_linux_8")
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
          delete_on_termination = optional(bool, true)
          #device_name          = # Calculated automatically from index of volume.
          #encrypted            = # Statically set to 'true'
          iops = optional(string, null)
          #kms_key_id           = # Calculated automatically from system.aws_kms_alias
          snapshot_id = optional(string, null)
          tags        = optional(map(string), {})
          throughput  = optional(string, null)
          volume_type = optional(string, "gp3")
          volume_size = optional(string, "100")
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
        security_groups = optional(list(string), null)
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
      contains(["red_hat_enterprise_linux_8", "windows_server_2022_base", "windows_server_2025_base"], system.ami)
    ])
    error_message = "Each all_systems entry ami must be red_hat_enterprise_linux_8, windows_server_2022_base, or windows_server_2025_base."
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

  # validation {
  #   condition     = length(distinct([for s in var.baseline_ami_systems : s.ip])) == length(var.baseline_ami_systems)
  #   error_message = "Duplicate 'private_ip' values detected. Each server will need a unique IPv4 address."
  # }

}


variable "all_databases" {
  description = "Define all RDS database instances managed by this framework."

  type = list(object({
    /* Required Parameters */
    region            = string
    availability_zone = string

    db_name              = string
    instance_class       = string
    db_subnet_group_name = string

    engine         = string
    engine_version = string

    username = string
    password = optional(string)

    aws_kms_alias = string

    tags = object({
      #Name                 = <Set Automatically From 'db_name'>
      Function = string
      #Terraform            = <Set Automatically to 'True'>
      #Environment          = <Set Automatically From 'var.environment'>
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
    manage_master_user_password = optional(bool, false)
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
