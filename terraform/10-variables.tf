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
    region            = string
    hostname          = string
    availability_zone = string
    subnet_id         = string
    key_name          = string
    aws_kms_alias     = string
    refresh           = optional(bool, false)

    tags = object({
      #OS                   = <Set Automatically From 'each.ami' Data Object Lookup>
      #Name                 = optional(string)
      Backup   = optional(bool, false)
      Function = string
      #Terraform            = <Set Automatically to 'True'>
      #Environment          = <Set Automatically From 'var.environment'>
    })

    /* Optional Parameters */
    ami               = optional(string, "red_hat_enterprise_linux_8")
    instance_type     = optional(string, "m6i.large")
    get_password_data = optional(bool, false)
    set_state         = optional(string)

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
        #subnet_ip            = # Calculated automatically from parent object
        #region               = # Calculated automatically from parent object
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
    password = string

    aws_kms_alias = string

    tags = object({
      #Name                 = <Set Automatically From 'db_name'>
      Function = string
      #Terraform            = <Set Automatically to 'True'>
      #Environment          = <Set Automatically From 'var.environment'>
    })

    /* Optional Parameters */
    allocated_storage        = optional(string, "100")
    backup_retention_period  = optional(string, null)
    backup_window            = optional(string, null)
    blue_green_update        = optional(bool, false)
    ca_cert_identifier       = optional(string, null)
    dedicated_log_volume     = optional(bool, true)
    delete_automated_backups = optional(bool, true)
    deletion_protection      = optional(bool, true)
    max_allocated_storage    = optional(string, "1000")
    skip_final_snapshot      = optional(bool, false)
    storage_type             = optional(string)
    vpc_security_group_ids   = optional(list(string), null)

  }))

  default  = []
  nullable = false
}
