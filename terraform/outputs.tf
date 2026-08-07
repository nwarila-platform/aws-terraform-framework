# Output values: the non-secret inventory hand-off consumed by configuration-management
# pipelines. Deployment identity is not re-exported - it is written directly into every
# tag map, so the resource tags themselves are the record.


#region ------ [ Resource(s): aws_instance ] --------------------------------------------------- #

output "aws_instances" {
  description = "Stable non-secret EC2 inventory keyed by hostname for inventory hand-off and readiness gating."
  value = {
    for hostname, inst in local.all_ec2_instances : hostname => {
      hostname    = hostname
      instance_id = inst.id
      region      = local.systems_by_hostname[hostname].region
      private_ip  = aws_network_interface.us_east_1["${hostname}-eni-0"].private_ip
      private_dns = inst.private_dns
      function    = local.systems_by_hostname[hostname].tags["Function"]
      os_family   = local.systems_by_hostname[hostname].is_windows ? "windows" : "linux"
      environment = var.environment
    }
  }
}

#endregion --- [ Resource(s): aws_instance ] --------------------------------------------------- #


#region ------ [ Resource(s): aws_lb ] --------------------------------------------------------- #

output "aws_load_balancers" {
  description = "Stable Elastic Load Balancer attributes keyed by all_load_balancers resource_key."
  value = {
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
}

output "aws_load_balancer_arn_suffixes" {
  description = "Elastic Load Balancer ARN suffixes keyed by all_load_balancers resource_key."
  value       = { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.arn_suffix }
}

output "aws_load_balancer_arns" {
  description = "Elastic Load Balancer ARNs keyed by all_load_balancers resource_key."
  value       = { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.arn }
}

output "aws_load_balancer_dns_names" {
  description = "Elastic Load Balancer DNS names keyed by all_load_balancers resource_key."
  value       = { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.dns_name }
}

output "aws_load_balancer_zone_ids" {
  description = "Elastic Load Balancer Route 53 zone IDs keyed by all_load_balancers resource_key."
  value       = { for key, load_balancer in aws_lb.us_east_1 : key => load_balancer.zone_id }
}

#endregion --- [ Resource(s): aws_lb ] --------------------------------------------------------- #


#region ------ [ Resource(s): aws_lb_target_group ] -------------------------------------------- #

output "aws_target_groups" {
  description = "Stable Elastic Load Balancer Target Group attributes keyed by all_load_balancers and target_groups resource_key."
  value = {
    for key, target_group in aws_lb_target_group.us_east_1 : key => {
      arn        = target_group.arn
      arn_suffix = target_group.arn_suffix
      name       = target_group.name
    }
  }
}

output "aws_target_group_arns" {
  description = "Elastic Load Balancer Target Group ARNs keyed by all_load_balancers and target_groups resource_key."
  value       = { for key, target_group in aws_lb_target_group.us_east_1 : key => target_group.arn }
}

#endregion --- [ Resource(s): aws_lb_target_group ] -------------------------------------------- #


#region ------ [ Resource(s): aws_lb_listener ] ------------------------------------------------ #

output "aws_listeners" {
  description = "Stable Elastic Load Balancer Listener attributes keyed by all_load_balancers and listeners resource_key."
  value = {
    for key, listener in aws_lb_listener.us_east_1 : key => {
      arn = listener.arn
    }
  }
}

output "aws_listener_arns" {
  description = "Elastic Load Balancer Listener ARNs keyed by all_load_balancers and listeners resource_key."
  value       = { for key, listener in aws_lb_listener.us_east_1 : key => listener.arn }
}

#endregion --- [ Resource(s): aws_lb_listener ] ------------------------------------------------ #


#region ------ [ Resource(s): aws_ebs_volume ] ------------------------------------------------- #

output "ebs_volumes" {
  description = <<-EOT
    Data-volume identity map for consumer-side disk resolution, keyed like the aws_ebs_volume
    resources (<hostname>-ebs-<resource_key>). Exposes the real volume-id (on Nitro the NVMe
    serial equals the volume-id, so on-box tooling can match disks with zero AWS API calls)
    alongside the authored Function/DeviceName/Name tags. function is null for volumes that
    declare no Function tag.
  EOT
  value = {
    for key, volume in aws_ebs_volume.us_east_1 : key => {
      volume_id   = volume.id
      function    = try(volume.tags["Function"], null)
      device_name = try(volume.tags["DeviceName"], null)
      hostname    = try(volume.tags["Name"], null)
    }
  }
}

#endregion --- [ Resource(s): aws_ebs_volume ] ------------------------------------------------- #


#region ------ [ Resource(s): aws_db_instance ] ------------------------------------------------ #

output "aws_databases" {
  description = <<-EOT
    Non-secret RDS inventory keyed by db_name. master_user_secret_arn is a POINTER to the
    Secrets Manager secret AWS owns, never the password itself: the same posture as
    get_password_data = false on Windows instances, where the credential stays retrievable
    out-of-band instead of being copied into Terraform state. Read it with
    'aws secretsmanager get-secret-value --secret-id <arn>', which needs
    secretsmanager:GetSecretValue plus kms:Decrypt on the database's KMS key.
  EOT
  value = {
    for key, database in aws_db_instance.us_east_1 : key => {
      address                = database.address
      identifier             = database.identifier
      master_user_secret_arn = try(database.master_user_secret[0].secret_arn, null)
      port                   = database.port
    }
  }
}

#endregion --- [ Resource(s): aws_db_instance ] ------------------------------------------------ #
