#% =========================================================================================== %#
#% Outputs: 62-outputs-aws.tf                                      | Category: Outputs (60-69) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% Output values make information about your infrastructure available on the command line, and %#
#%   can expose information for other Terraform configurations to use. Output values are       %#
#%   similar to return values in programming languages.                                        %#
#% =========================================================================================== %#


# #region ------ [ Local Variable(s) ] -------------------------------------------------------- #

# #region ------ [ Local Variable(s): elastic_compute_cloud ] ------------------------------- #

# ?region ------ [ Local Variable(s): elastic_compute_cloud: Sample ] --------------------- #
# elastic_compute_cloud = {
#   us_east_1 = {}
#   us_west_2 = {
#    FirstSystem = {
#      ami               = "ami-000a0a0000a00a000"
#      availability_zone = "us-west-2a"
#      hostname          = "FirstSystem"
#      instance_type     = "m6i.large"
#      key_name          = "my-key-pair"
#      root_block_device = {
#        delete_on_termination = true
#        encrypted             = true
#        kms_key_id            = "aws/ebs"
#        tags                  = {
#          Environment = "INT"
#          Name        = "FirstSystem"
#          index       = 0
#        }
#        volume_size           = "100"
#        volume_type           = "gp3"
#      }
#      tags              = {
#        Backup       = true
#        Environment  = "PROD"
#        Function     = "Test Build"
#        Name         = "FirstSystem"
#        OS           = "My Super Secure OS"
#        Terraform    = "True"
#      }
#    }
#    SecondSystem = {...
# ?endregion --- [ Local Variable(s): elastic_compute_cloud: Sample ] --------------------- #

# output "__LOCAL__elastic_compute_cloud" {
#   value = local.elastic_compute_cloud
# }

# #endregion --- [ Local Variable(s): elastic_compute_cloud ] ------------------------------- #

# #region ------ [ Local Variable(s): elastic_network_interfaces ] -------------------------- #

# ?region ------ [ Local Variable(s): elastic_network_interfaces: Sample ] ---------------- #
# elastic_network_interfaces = {
#   us_east_1 = {}
#   us_west_2 = {
#    FirstSystem-eni-0 = {
#      description     = "Primary Network Interface"
#      interface_type  = null
#      private_ips     = [
#        "127.0.0.1",
#      ]
#      security_groups = [
#        "sg-000a000aa000aaaaa",
#      ]
#      subnet_id       = "subnet-000a0000000000ccc"
#      tags                  = {
#        Environment = "INT"
#        Name        = "FirstSystem"
#        index       = 0
#      }
#    SecondSystem-eni-1 = {...
# ?endregion --- [ Local Variable(s): elastic_network_interfaces: Sample ] ---------------- #

# output "__LOCAL__elastic_network_interfaces" {
#   value = local.elastic_network_interfaces
# }

# #endregion --- [ Local Variable(s): elastic_network_interfaces ] -------------------------- #

# #region ------ [ Local Variable(s): ebs_block_devices ] ----------------------------------- #

# ?region ------ [ Local Variable(s): ebs_block_devices: Sample ] ------------------------- #
# elastic_network_interfaces = {
#   us_east_1 = {}
#   us_west_2 = {
#    FirstSystem-ebs-0 = {
#      availability_zone     = "us-west-2a"
#      delete_on_termination = false
#      encrypted             = true
#      iops                  = null
#      kms_key_id            = "aws/ebs"
#      snapshot_id           = null
#      throughput            = null
#      volume_size           = "100"
#      volume_type           = "gp3"
#      tags                  = {
#        DeviceName  = "/dev/sdd"
#        Name        = "FirstSystem"
#        Environment = "PROD"
#        index       = 0
#      }
#    SecondSystem-ebs-1 = {...
# ?endregion --- [ Local Variable(s): ebs_block_devices: Sample ] ------------------------- #

# output "ebs_block_devices" {
#   value = local.ebs_block_devices
# }

# #endregion --- [ Local Variable(s): ebs_block_devices ] ----------------------------------- #

# #endregion --- [ Local Variable(s) ] -------------------------------------------------------- #


# #region ------ [ Resource(s) ] -------------------------------------------------------------- #

# #region ------ [ Resource(s): aws_network_interface ] ------------------------------------- #

# ?region ------ [ Resource(s): aws_network_interface: Sample ] --------------------------- #
# FirstSystem-eni-0 = {
#   arn = "arn:aws:ec2:us-west-2:000000000000:network-interface/eni-00000000"
#   attachment                = [
#       {
#           attachment_id = "eni-attach-00000aa0a00aa0a0a"
#           device_index  = 0
#           instance      = "i-0a0a00aa00aa00000"
#         },
#     ]
#   description               = "Primary Network Interface"
#   enable_primary_ipv6       = null
#   id                        = "eni-00000000"
#   interface_type            = "interface"
#   ipv4_prefix_count         = 0
#   ipv4_prefixes             = []
#   ipv6_address_count        = 0
#   ipv6_address_list         = []
#   ipv6_address_list_enabled = false
#   ipv6_addresses            = []
#   ipv6_prefix_count         = 0
#   ipv6_prefixes             = []
#   mac_address               = "0a:0a:0a:0a:aa:a0"
#   outpost_arn               = ""
#   owner_id                  = "000000000000"
#   private_dns_name          = ""
#   private_ip                = "127.0.0.1"
#   private_ip_list           = [
#       "127.0.0.1",
#     ]
#   private_ip_list_enabled   = false
#   private_ips               = [
#       "127.0.0.1",
#     ]
#   private_ips_count         = 0
#   security_groups           = [
#       "sg-000a000aa000aaaaa",
#     ]
#   source_dest_check         = true
#   subnet_id                 = "subnet-000a0000000000aaa"
#   tags                      = {
#       Environment = "PROD"
#       Index       = "0"
#       Name        = "FirstSystem"
#     }
#   tags_all                  = {
#       Environment = "PROD"
#       Index       = "0"
#       Name        = "FirstSystem"
#     }
# }
# ?endregion --- [ Resource(s): aws_network_interface: Sample ] --------------------------- #

# output "__RESOURCE__aws_network_interface" {
#   value = merge(aws_network_interface.us_west_2, aws_network_interface.us_east_1)
# }

# #endregion --- [ Resource(s): aws_network_interface ] ------------------------------------- #

# #region ------ [ Resource(s): aws_ebs_volume ] -------------------------------------------- #

# ?region ------ [ Resource(s): aws_ebs_volume: Sample ] ---------------------------------- #
# aws_ebs_volume = {
#   FirstSystem-ebs-0 = {
#     arn                  = "arn:aws:ec2:us-west-2:000000000000:volume/vol-00a00a00a0a0a00aa"
#     availability_zone    = "us-west-2a"
#     create_time          = "2025-07-15T11:32:23Z"
#     encrypted            = true
#     final_snapshot       = false
#     id                   = "vol-00a00a00a0a0a00aa"
#     iops                 = 3000
#     kms_key_id           = "arn:aws:kms:us-west-2:000000000000:key/0a0000a0-aa00-0000-0aaa-000aa0000a00"
#     multi_attach_enabled = false
#     outpost_arn          = ""
#     size                 = 100
#     snapshot_id          = ""
#     tags                 = {
#         DeviceName  = "/dev/sdd"
#         Environment = "PROD"
#         Index       = "0"
#         Name        = "FirstSystem"
#       }
#     tags_all             = {
#         DeviceName  = "/dev/sdd"
#         Environment = "PROD"
#         Index       = "0"
#         Name        = "FirstSystem"
#       }
#     throughput           = 125
#     timeouts             = null
#     type                 = "gp3"
#   }
# rhel8-ami-builder-01-ebs-1 = {...
# ?endregion --- [ Resource(s): aws_ebs_volume: Sample ] ---------------------------------- #

# output "__RESOURCE__aws_ebs_volume" {
#   value = merge(aws_ebs_volume.us_west_2, aws_ebs_volume.us_east_1)
# }

# #endregion --- [ Resource(s): aws_ebs_volume ] -------------------------------------------- #

# #region ------ [ Resource(s): aws_instance ] ---------------------------------------------- #

# ?region ------ [ Resource(s): aws_instance: Sample ] ------------------------------------ #
# aws_instance = {
#   rhel8-ami-builder-01 = {
#     ami                                  = "ami-000a0a0000a00a000"
#     arn                                  = "arn:aws:ec2:us-west-2:000000000000:instance/i-0a0a00aa00aa00000"
#     associate_public_ip_address          = false
#     availability_zone                    = "us-west-2a"
#     capacity_reservation_specification   = [
#       {
#         capacity_reservation_preference = "open"
#         capacity_reservation_target     = []
#       },
#     ]
#     cpu_core_count                       = 1
#     cpu_options                          = [
#       {
#         amd_sev_snp      = ""
#         core_count       = 1
#         threads_per_core = 2
#       },
#     ]
#     cpu_threads_per_core                 = 2
#     credit_specification                 = []
#     disable_api_stop                     = false
#     disable_api_termination              = false
#     ebs_block_device                     = [
#       {
#         delete_on_termination = false
#         device_name           = "/dev/sdd"
#         encrypted             = true
#         iops                  = 3000
#         kms_key_id            = "arn:aws:kms:us-west-2:000000000000:key/0a0000a0-aa00-0000-0aaa-000aa0000a00"
#         snapshot_id           = ""
#         tags                  = {
#           DeviceName  = "/dev/sdd"
#           Environment = "PROD"
#           Index       = "0"
#           Name        = "FirstSystem"
#         }
#         tags_all              = {
#           DeviceName  = "/dev/sdd"
#           Environment = "PROD"
#           Index       = "0"
#           Name        = "FirstSystem"
#         }
#         throughput            = 125
#         volume_id             = "vol-00a00a00a0a0a00aa"
#         volume_size           = 100
#         volume_type           = "gp3"
#       },
#       {
#         delete_on_termination = false
#         device_name           = "/dev/sde"
#         encrypted             = true
#         iops                  = 3000
#         kms_key_id            = "arn:aws:kms:us-west-2:000000000000:key/0a0000a0-aa00-0000-0aaa-000aa0000a00"
#         snapshot_id           = ""
#         tags                  = {
#           DeviceName  = "/dev/sde"
#           Environment = "PROD"
#           Index       = "1"
#           Name        = "FirstSystem"
#         }
#         tags_all              = {
#           DeviceName  = "/dev/sde"
#           Environment = "PROD"
#           Index       = "1"
#           Name        = "FirstSystem"
#         }
#         throughput            = 125
#         volume_id             = "vol-0a0a00a0000aa0aa0"
#         volume_size           = 100
#         volume_type           = "gp3"
#       },
#     ]
#     ebs_optimized                        = false
#     enable_primary_ipv6                  = null
#     enclave_options                      = [
#       {
#         enabled = false
#       },
#     ]
#     ephemeral_block_device               = []
#     get_password_data                    = false
#     hibernation                          = false
#     host_id                              = ""
#     host_resource_group_arn              = null
#     iam_instance_profile                 = ""
#     id                                   = "i-0a0a00aa00aa00000"
#     instance_initiated_shutdown_behavior = "stop"
#     instance_lifecycle                   = ""
#     instance_market_options              = []
#     instance_state                       = "running"
#     instance_type                        = "m6i.large"
#     ipv6_address_count                   = 0
#     ipv6_addresses                       = []
#     key_name                             = "my_key_pair"
#     launch_template                      = []
#     maintenance_options                  = [
#       {
#         auto_recovery = "default"
#       },
#     ]
#     metadata_options                     = [
#       {
#         http_endpoint               = "enabled"
#         http_protocol_ipv6          = ""
#         http_put_response_hop_limit = 1
#         http_tokens                 = "optional"
#         instance_metadata_tags      = "disabled"
#       },
#     ]
#     monitoring                           = false
#     network_interface                    = [
#       {
#         delete_on_termination = false
#         device_index          = 0
#         network_card_index    = 0
#         network_interface_id  = "eni-00000000"
#       },
#     ]
#     outpost_arn                          = ""
#     password_data                        = ""
#     placement_group                      = ""
#     placement_partition_number           = 0
#     primary_network_interface_id         = "eni-00000000"
#     private_dns                          = "ip-127-0-0-1.example.com"
#     private_dns_name_options             = [
#       {
#         enable_resource_name_dns_a_record    = false
#         enable_resource_name_dns_aaaa_record = false
#         hostname_type                        = "ip-name"
#       },
#     ]
#     private_ip                           = "127.0.0.1"
#     public_dns                           = ""
#     public_ip                            = ""
#     root_block_device                    = [
#       {
#         delete_on_termination = true
#         device_name           = "/dev/sda1"
#         encrypted             = true
#         iops                  = 3000
#         kms_key_id            = "arn:aws:kms:us-west-2:000000000000:key/0a0000a0-aa00-0000-0aaa-000aa0000a00"
#         tags                  = {
#           Environment = "PROD"
#           Name        = "FirstSystem"
#           index       = "0"
#         }
#         tags_all              = {
#           Environment = "PROD"
#           Name        = "FirstSystem"
#           index       = "0"
#         }
#         throughput            = 125
#         volume_id             = "vol-0a0aaa0a0a0a00a00"
#         volume_size           = 100
#         volume_type           = "gp3"
#       },
#     ]
#     secondary_private_ips                = []
#     security_groups                      = []
#     source_dest_check                    = true
#     spot_instance_request_id             = ""
#     subnet_id                            = "subnet-000a0000000000aaa"
#     tags                                 = {
#       Backup       = "true"
#       Environment  = "PROD"
#       Function     = "AMI Test Build"
#       Name         = "FirstSystem"
#       OS           = "My Secure OS"
#       Terraform    = "True"
#     }
#     tags_all                             = {
#       Backup       = "true"
#       Environment  = "PROD"
#       Function     = "AMI Test Build"
#       Name         = "FirstSystem"
#       OS           = "My Secure OS"
#       Terraform    = "True"
#     }
#     tenancy                              = "default"
#     timeouts                             = null
#     user_data                            = null
#     user_data_base64                     = null
#     user_data_replace_on_change          = false
#     volume_tags                          = null
#     vpc_security_group_ids               = [
#       "sg-000a000aa000aaaaa",
#     ]
#   }
# }
# ?endregion --- [ Resource(s): aws_instance: Sample ] ------------------------------------ #

# output "__RESOURCE__aws_instance" {
#   value = merge(aws_instance.us_west_2, aws_instance.us_east_1)
# }

# #endregion --- [ Resource(s): aws_instance ] ---------------------------------------------- #

# #endregion --- [ Resource(s) ] -------------------------------------------------------------- #


#region ------ [ Resource(s): aws_instance ] -------------------------------------------------- #

output "aws_instances" {
  description = "Stable non-secret EC2 inventory keyed by hostname for the Ansible aws_ec2 SSH hand-off + readiness gate."
  value = merge(
    {
      for key, inst in aws_instance.us_west_2 : key => {
        hostname           = key
        instance_id        = inst.id
        region             = "us_west_2"
        private_ip         = aws_network_interface.us_west_2["${key}-eni-0"].private_ip
        private_dns        = inst.private_dns
        function           = local.elastic_compute_cloud.us_west_2[key].tags["Function"]
        ansible_group      = local.elastic_compute_cloud.us_west_2[key].ansible_group
        environment        = var.environment
        transport          = "ssh"
        os_family          = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[key].ami))) ? "windows" : "linux"
        ansible_host       = aws_network_interface.us_west_2["${key}-eni-0"].private_ip
        ansible_connection = "ssh"
        ansible_user       = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[key].ami))) ? null : "ec2-user"
        ansible_shell_type = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[key].ami))) ? "powershell" : null
      }
    },
    {
      for key, inst in aws_instance.us_west_2_refresh : key => {
        hostname           = key
        instance_id        = inst.id
        region             = "us_west_2"
        private_ip         = aws_network_interface.us_west_2["${key}-eni-0"].private_ip
        private_dns        = inst.private_dns
        function           = local.elastic_compute_cloud.us_west_2[key].tags["Function"]
        ansible_group      = local.elastic_compute_cloud.us_west_2[key].ansible_group
        environment        = var.environment
        transport          = "ssh"
        os_family          = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[key].ami))) ? "windows" : "linux"
        ansible_host       = aws_network_interface.us_west_2["${key}-eni-0"].private_ip
        ansible_connection = "ssh"
        ansible_user       = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[key].ami))) ? null : "ec2-user"
        ansible_shell_type = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[key].ami))) ? "powershell" : null
      }
    },
    {
      for key, inst in aws_instance.us_east_1 : key => {
        hostname           = key
        instance_id        = inst.id
        region             = "us_east_1"
        private_ip         = aws_network_interface.us_east_1["${key}-eni-0"].private_ip
        private_dns        = inst.private_dns
        function           = local.elastic_compute_cloud.us_east_1[key].tags["Function"]
        ansible_group      = local.elastic_compute_cloud.us_east_1[key].ansible_group
        environment        = var.environment
        transport          = "ssh"
        os_family          = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[key].ami))) ? "windows" : "linux"
        ansible_host       = aws_network_interface.us_east_1["${key}-eni-0"].private_ip
        ansible_connection = "ssh"
        ansible_user       = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[key].ami))) ? null : "ec2-user"
        ansible_shell_type = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[key].ami))) ? "powershell" : null
      }
    },
    {
      for key, inst in aws_instance.us_east_1_refresh : key => {
        hostname           = key
        instance_id        = inst.id
        region             = "us_east_1"
        private_ip         = aws_network_interface.us_east_1["${key}-eni-0"].private_ip
        private_dns        = inst.private_dns
        function           = local.elastic_compute_cloud.us_east_1[key].tags["Function"]
        ansible_group      = local.elastic_compute_cloud.us_east_1[key].ansible_group
        environment        = var.environment
        transport          = "ssh"
        os_family          = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[key].ami))) ? "windows" : "linux"
        ansible_host       = aws_network_interface.us_east_1["${key}-eni-0"].private_ip
        ansible_connection = "ssh"
        ansible_user       = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[key].ami))) ? null : "ec2-user"
        ansible_shell_type = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[key].ami))) ? "powershell" : null
      }
    }
  )
}

#endregion --- [ Resource(s): aws_instance ] -------------------------------------------------- #


#region ------ [ Resource(s): aws_lb ] -------------------------------------------------------- #

output "aws_load_balancers" {
  description = "Stable Elastic Load Balancer attributes keyed by all_load_balancers resource_key."
  value = merge(
    {
      for key, load_balancer in aws_lb.us_west_2 : key => {
        arn            = load_balancer.arn
        arn_suffix     = load_balancer.arn_suffix
        dns_name       = load_balancer.dns_name
        id             = load_balancer.id
        name           = load_balancer.name
        subnet_mapping = load_balancer.subnet_mapping
        tags_all       = load_balancer.tags_all
        zone_id        = load_balancer.zone_id
      }
    },
    {
      for key, load_balancer in aws_lb.us_east_1 : key => {
        arn            = load_balancer.arn
        arn_suffix     = load_balancer.arn_suffix
        dns_name       = load_balancer.dns_name
        id             = load_balancer.id
        name           = load_balancer.name
        subnet_mapping = load_balancer.subnet_mapping
        tags_all       = load_balancer.tags_all
        zone_id        = load_balancer.zone_id
      }
    }
  )
}

output "aws_load_balancer_arn_suffixes" {
  description = "Elastic Load Balancer ARN suffixes keyed by all_load_balancers resource_key."
  value = merge(
    { for key, load_balancer in aws_lb.us_west_2 : key => load_balancer.arn_suffix },
    { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.arn_suffix }
  )
}

output "aws_load_balancer_arns" {
  description = "Elastic Load Balancer ARNs keyed by all_load_balancers resource_key."
  value = merge(
    { for key, load_balancer in aws_lb.us_west_2 : key => load_balancer.arn },
    { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.arn }
  )
}

output "aws_load_balancer_dns_names" {
  description = "Elastic Load Balancer DNS names keyed by all_load_balancers resource_key."
  value = merge(
    { for key, load_balancer in aws_lb.us_west_2 : key => load_balancer.dns_name },
    { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.dns_name }
  )
}

output "aws_load_balancer_zone_ids" {
  description = "Elastic Load Balancer Route 53 zone IDs keyed by all_load_balancers resource_key."
  value = merge(
    { for key, load_balancer in aws_lb.us_west_2 : key => load_balancer.zone_id },
    { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.zone_id }
  )
}

#endregion --- [ Resource(s): aws_lb ] -------------------------------------------------------- #


#region ------ [ Resource(s): aws_lb_target_group ] ------------------------------------------ #

output "aws_target_groups" {
  description = "Stable Elastic Load Balancer Target Group attributes keyed by all_load_balancers and target_groups resource_key."
  value = merge(
    {
      for key, target_group in aws_lb_target_group.us_west_2 : key => {
        arn        = target_group.arn
        arn_suffix = target_group.arn_suffix
        name       = target_group.name
      }
    },
    {
      for key, target_group in aws_lb_target_group.us_east_1 : key => {
        arn        = target_group.arn
        arn_suffix = target_group.arn_suffix
        name       = target_group.name
      }
    }
  )
}

output "aws_target_group_arns" {
  description = "Elastic Load Balancer Target Group ARNs keyed by all_load_balancers and target_groups resource_key."
  value = merge(
    { for key, target_group in aws_lb_target_group.us_west_2 : key => target_group.arn },
    { for key, target_group in aws_lb_target_group.us_east_1 : key => target_group.arn }
  )
}

#endregion --- [ Resource(s): aws_lb_target_group ] ------------------------------------------ #


#region ------ [ Resource(s): aws_lb_listener ] ---------------------------------------------- #

output "aws_listeners" {
  description = "Stable Elastic Load Balancer Listener attributes keyed by all_load_balancers and listeners resource_key."
  value = merge(
    {
      for key, listener in aws_lb_listener.us_west_2 : key => {
        arn = listener.arn
      }
    },
    {
      for key, listener in aws_lb_listener.us_east_1 : key => {
        arn = listener.arn
      }
    }
  )
}

output "aws_listener_arns" {
  description = "Elastic Load Balancer Listener ARNs keyed by all_load_balancers and listeners resource_key."
  value = merge(
    { for key, listener in aws_lb_listener.us_west_2 : key => listener.arn },
    { for key, listener in aws_lb_listener.us_east_1 : key => listener.arn }
  )
}

#endregion --- [ Resource(s): aws_lb_listener ] ---------------------------------------------- #
