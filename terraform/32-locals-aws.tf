#% =========================================================================================== %#
#% = File: 32-locals-aws.tf                                         | Category: locals (30-39) %#
#% ------------------------------------------------------------------------------------------- %#
#% The locals files is where the real heavy lifting for building the working objects used by   %#
#%    resources blocks is done. within "locals", all objects defined elsewhere (i.e. data,     %#
#%    variable, etc.) processed here to prepare the object(s) for action. This file is         %#
#%    intentionally designed to be the "brain" of the plan.                                    %#
#% =========================================================================================== %#

# Statically Configured LOCALS
locals {
  amazon_machine_images = {
    "red_hat_enterprise_linux_8" = {
      us_west_2 = try(data.aws_ami.us_west_2_red_hat_enterprise_linux_8[0], null)
      us_east_1 = try(data.aws_ami.us_east_1_red_hat_enterprise_linux_8[0], null)
    }
    "windows_server_2022_base" = {
      us_west_2 = try(data.aws_ami.us_west_2_windows_server_2022_base[0], null)
      us_east_1 = try(data.aws_ami.us_east_1_windows_server_2022_base[0], null)
    }
    "windows_server_2025_base" = {
      us_west_2 = try(data.aws_ami.us_west_2_windows_server_2025_base[0], null)
      us_east_1 = try(data.aws_ami.us_east_1_windows_server_2025_base[0], null)
    }
  }
}


# Dynamically Configured LOCALS
locals {

  elastic_compute_cloud = {
    for region in var.aws_config.regions : region => {
      for system in var.all_systems : system.hostname => {

        #region           = < This is set statically >
        ami                  = system.ami
        availability_zone    = system.availability_zone
        get_password_data    = system.get_password_data
        key_name             = system.key_name
        iam_instance_profile = system.iam_instance_profile
        ansible_group        = system.ansible_group
        user_data = trimspace(can(regex("windows", lower(system.ami))) ? <<-WINDOWS_USER_DATA
          <powershell>
          Set-Service -Name sshd -StartupType Automatic
          Start-Service -Name sshd
          </powershell>
        WINDOWS_USER_DATA
          : <<-LINUX_USER_DATA
          #cloud-config
          runcmd:
            - systemctl enable --now sshd
        LINUX_USER_DATA
        )
        hostname      = system.hostname
        instance_type = system.instance_type
        refresh       = system.refresh
        set_state     = system.set_state

        root_block_device = {
          volume_size           = system.root_block_device.volume_size
          volume_type           = system.root_block_device.volume_type
          encrypted             = true
          iops                  = system.root_block_device.iops
          kms_key_id            = system.aws_kms_alias
          delete_on_termination = system.root_block_device.delete_on_termination
          throughput            = system.root_block_device.throughput

          tags = merge(
            system.root_block_device.tags,
            {
              index       = 0
              Name        = system.hostname
              Environment = var.environment
            }
          )
        }

        tags = merge(
          # Overwriteable Default Tags
          {
            Backup = try(system.tags["Backup"], "True")
          },
          system.tags,
          # Non-Overwritable Default Tags
          {
            Name             = system.hostname
            Environment      = var.environment
            Terraform        = "True"
            ManagedBy        = "Terraform"
            AnsibleTransport = "ssh"
            AnsibleGroup     = system.ansible_group
            OS               = local.amazon_machine_images[system.ami][region].platform_details
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region
    }
  }

  elastic_network_interfaces = {
    for region in var.aws_config.regions : region => merge([
      for system in var.all_systems : {
        for index in range(length(system.network_interfaces)) :
        "${system.hostname}-eni-${index}" => {

          # AWS Network Interface Properties
          description     = system.network_interfaces[index].description
          hostname        = system.hostname
          index           = index
          interface_type  = system.network_interfaces[index].interface_type
          private_ips     = [system.network_interfaces[index].private_ip]
          security_groups = system.network_interfaces[index].security_groups
          subnet_id       = system.subnet_id

          # ?Note: Merges all of the defined user tags (if any) with the 'default' automatically
          # ?      calculated tags. The default tags cannot be overwritten, if the user provides
          # ?      tags with the same name, the default tags will take precedence.
          tags = merge(
            system.network_interfaces[index].tags,
            {
              Index       = index
              Name        = system.hostname
              Environment = var.environment
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region
    ]...)
  }

  ebs_block_devices = {
    for region in var.aws_config.regions : region => merge([
      for system in var.all_systems : {
        for index in range(length(system.ebs_block_devices)) :
        "${system.hostname}-ebs-${index}" => {

          # AWS Network Interface Properties
          availability_zone     = system.availability_zone
          delete_on_termination = system.ebs_block_devices[index].delete_on_termination
          device_name = can(regex(
            "[Ww]indows",
            local.amazon_machine_images[system.ami][region].platform
            )) ? "xvd${jsondecode(format("\"\\u%04x\"", 100 + index))}" : (
            "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + index))}"
          )
          encrypted   = true
          hostname    = system.hostname
          index       = index
          iops        = system.ebs_block_devices[index].iops
          refresh     = system.refresh
          snapshot_id = system.ebs_block_devices[index].snapshot_id
          throughput  = system.ebs_block_devices[index].throughput
          volume_size = system.ebs_block_devices[index].volume_size
          volume_type = system.ebs_block_devices[index].volume_type

          # ?Note: This is property relies on a data lookup, which is region specific, so its
          # ?  final value is actually calculated in the 'aws_ebs_volume' resource.
          kms_key_id = system.aws_kms_alias

          # ?Note: Merges all of the defined user tags (if any) with the 'default' automatically
          # ?      calculated tags. The default tags cannot be overwritten, if the user provides
          # ?      tags with the same name, the default tags will take precedence.
          tags = merge(
            try(system.ebs_block_devices[index].tags, {}),
            {
              Name        = system.hostname
              Index       = index
              Environment = var.environment
              # ?Note: Dynamically assign a predictable device name by using the index to increment
              # ?      a [char] lookup. Unicode character set is used in the conversation, so
              # ?      [INT]100 converted to Unicode [CHAR] is'd', then each index increment after
              # ?      that will itterate through next characters (I.E. e, f, g, h, etc.)
              DeviceName = can(regex(
                "[Ww]indows",
                local.amazon_machine_images[system.ami][region].platform
                )) ? "xvd${jsondecode(format("\"\\u%04x\"", 100 + index))}" : (
                "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + index))}"
              )
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region && system.ebs_block_devices != null
    ]...)
  }

  elastic_load_balancers = {
    for region in var.aws_config.regions : region => {
      for load_balancer in var.all_load_balancers : load_balancer.resource_key => {

        access_logs                                                  = load_balancer.access_logs
        client_keep_alive                                            = load_balancer.client_keep_alive
        connection_logs                                              = load_balancer.connection_logs
        customer_owned_ipv4_pool                                     = load_balancer.customer_owned_ipv4_pool
        desync_mitigation_mode                                       = load_balancer.desync_mitigation_mode
        dns_record_client_routing_policy                             = load_balancer.dns_record_client_routing_policy
        drop_invalid_header_fields                                   = load_balancer.drop_invalid_header_fields
        enable_cross_zone_load_balancing                             = load_balancer.enable_cross_zone_load_balancing
        enable_deletion_protection                                   = load_balancer.enable_deletion_protection
        enable_http2                                                 = load_balancer.enable_http2
        enable_tls_version_and_cipher_suite_headers                  = load_balancer.enable_tls_version_and_cipher_suite_headers
        enable_waf_fail_open                                         = load_balancer.enable_waf_fail_open
        enable_xff_client_port                                       = load_balancer.enable_xff_client_port
        enable_zonal_shift                                           = load_balancer.enable_zonal_shift
        enforce_security_group_inbound_rules_on_private_link_traffic = load_balancer.enforce_security_group_inbound_rules_on_private_link_traffic
        health_check_logs                                            = load_balancer.health_check_logs
        idle_timeout                                                 = load_balancer.idle_timeout
        internal                                                     = load_balancer.internal
        ip_address_type                                              = load_balancer.ip_address_type
        ipam_pools                                                   = load_balancer.ipam_pools
        load_balancer_type                                           = load_balancer.load_balancer_type
        minimum_load_balancer_capacity                               = load_balancer.minimum_load_balancer_capacity
        name                                                         = load_balancer.name
        name_prefix                                                  = load_balancer.name_prefix
        preserve_host_header                                         = load_balancer.preserve_host_header
        secondary_ips_auto_assigned_per_subnet                       = load_balancer.secondary_ips_auto_assigned_per_subnet
        security_groups                                              = load_balancer.security_groups
        subnet_mapping                                               = load_balancer.subnet_mapping
        subnets                                                      = length(load_balancer.subnets) > 0 ? load_balancer.subnets : null
        timeouts                                                     = load_balancer.timeouts
        xff_header_processing_mode                                   = load_balancer.xff_header_processing_mode

        tags = merge(
          load_balancer.tags,
          {
            Name        = coalesce(load_balancer.name, load_balancer.name_prefix, load_balancer.resource_key)
            Environment = var.environment
            Terraform   = "True"
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    }
  }

  lb_target_groups = {
    for region in var.aws_config.regions : region => merge([
      for load_balancer in var.all_load_balancers : {
        for target_group in load_balancer.target_groups :
        "${load_balancer.resource_key}/${target_group.resource_key}" => {

          lb_key                            = load_balancer.resource_key
          tg_key                            = target_group.resource_key
          function                          = target_group.function
          vpc_id                            = target_group.vpc_id
          port                              = target_group.port
          protocol                          = target_group.protocol
          protocol_version                  = target_group.protocol_version
          target_type                       = target_group.target_type
          deregistration_delay              = target_group.deregistration_delay
          slow_start                        = target_group.slow_start
          load_balancing_algorithm_type     = target_group.load_balancing_algorithm_type
          load_balancing_anomaly_mitigation = target_group.load_balancing_anomaly_mitigation
          load_balancing_cross_zone_enabled = target_group.load_balancing_cross_zone_enabled
          preserve_client_ip                = target_group.preserve_client_ip
          proxy_protocol_v2                 = target_group.proxy_protocol_v2
          connection_termination            = target_group.connection_termination
          ip_address_type                   = target_group.ip_address_type
          health_check                      = target_group.health_check
          stickiness                        = target_group.stickiness

          tags = merge(
            target_group.tags,
            {
              Name        = "${load_balancer.resource_key}/${target_group.resource_key}"
              Environment = var.environment
              Terraform   = "True"
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ]...)
  }

  lb_target_group_attachments = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in var.all_load_balancers : [
        for target_group in load_balancer.target_groups : {
          for system in var.all_systems :
          "${load_balancer.resource_key}/${target_group.resource_key}/${system.hostname}" => {
            tg_key   = "${load_balancer.resource_key}/${target_group.resource_key}"
            hostname = system.hostname
            port     = target_group.port
          }
          if replace(system.region, "-", "_") == region && system.tags.Function == target_group.function
        }
      ]
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ])...)
  }

  lb_listeners = {
    for region in var.aws_config.regions : region => merge([
      for load_balancer in var.all_load_balancers : {
        for listener in load_balancer.listeners :
        "${load_balancer.resource_key}/${listener.resource_key}" => {

          lb_key          = load_balancer.resource_key
          listener_key    = listener.resource_key
          port            = listener.port
          protocol        = listener.protocol
          ssl_policy      = listener.ssl_policy
          alpn_policy     = listener.alpn_policy
          certificate_arn = listener.certificate_arn

          default_action = {
            type             = listener.default_action.type
            target_group_key = listener.default_action.target_group_key == null ? null : "${load_balancer.resource_key}/${listener.default_action.target_group_key}"
            redirect         = listener.default_action.redirect
            fixed_response   = listener.default_action.fixed_response
          }
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ]...)
  }

  lb_listener_rules = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : {
          for rule in listener.rules :
          "${load_balancer.resource_key}/${listener.resource_key}/${rule.resource_key}" => {

            listener_key = "${load_balancer.resource_key}/${listener.resource_key}"
            priority     = rule.priority

            action = {
              type             = rule.action.type
              target_group_key = rule.action.target_group_key == null ? null : "${load_balancer.resource_key}/${rule.action.target_group_key}"
              redirect         = rule.action.redirect
              fixed_response   = rule.action.fixed_response
            }

            conditions = rule.conditions
          }
        }
      ]
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ])...)
  }

  lb_listener_certificates = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : {
          for certificate_arn in listener.additional_certificate_arns :
          "${load_balancer.resource_key}/${listener.resource_key}/${certificate_arn}" => {

            listener_key    = "${load_balancer.resource_key}/${listener.resource_key}"
            certificate_arn = certificate_arn
          }
        }
      ]
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ])...)
  }


  relational_database_service = {
    for region in var.aws_config.regions : region => nonsensitive({
      for database in var.all_databases : nonsensitive(database.db_name) => {

        allocated_storage           = nonsensitive(database.allocated_storage)
        availability_zone           = nonsensitive(database.availability_zone)
        backup_retention_period     = nonsensitive(database.backup_retention_period)
        backup_window               = nonsensitive(database.backup_window)
        blue_green_update           = nonsensitive(database.blue_green_update)
        ca_cert_identifier          = nonsensitive(database.ca_cert_identifier)
        db_name                     = nonsensitive(database.db_name)
        db_subnet_group_name        = nonsensitive(database.db_subnet_group_name)
        dedicated_log_volume        = nonsensitive(database.dedicated_log_volume)
        delete_automated_backups    = nonsensitive(database.delete_automated_backups)
        deletion_protection         = nonsensitive(database.deletion_protection)
        engine                      = nonsensitive(database.engine)
        engine_version              = nonsensitive(database.engine_version)
        final_snapshot_identifier   = "${nonsensitive(database.db_name)}-FINAL"
        identifier                  = lower(nonsensitive(database.db_name))
        instance_class              = nonsensitive(database.instance_class)
        kms_key_id                  = nonsensitive(database.aws_kms_alias)
        manage_master_user_password = nonsensitive(database.manage_master_user_password)
        max_allocated_storage       = nonsensitive(database.max_allocated_storage)
        #region                     = < This is set statically >
        skip_final_snapshot    = nonsensitive(database.skip_final_snapshot)
        storage_encrypted      = true
        storage_type           = nonsensitive(try(database.storage_type, "gp3"))
        vpc_security_group_ids = nonsensitive(database.vpc_security_group_ids)

        tags = merge(
          # Overwriteable Default Tags
          {
            Backup = try(nonsensitive(database.tags["Backup"]), "True")
          },
          nonsensitive(database.tags),
          # Non-Overwritable Default Tags
          {
            Name        = nonsensitive(database.db_name)
            Environment = var.environment
            Terraform   = "True"
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(nonsensitive(database.region), "-", "_") == region
    })
  }

  relational_database_service_credentials = {
    for region in var.aws_config.regions : region => {
      for database in var.all_databases : nonsensitive(database.db_name) => {
        password = database.password == null ? null : sensitive(database.password)
        username = sensitive(database.username)
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(nonsensitive(database.region), "-", "_") == region
    }
  }

}
