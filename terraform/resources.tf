# Managed resources. Consumes the shaped maps from locals.tf; the refresh trigger
# fleet-replaces refresh=true instances when var.refresh_serial increments.


#region ------ [ terraform_data.refresh ] ------------------------------------------------------ #

resource "terraform_data" "refresh" {

  # Define the Fleet Refresh Trigger Properties
  input = var.refresh_serial

}

#endregion --- [ terraform_data.refresh ] ------------------------------------------------------ #


#region ------ [ aws_security_group ] ---------------------------------------------------------- #

#region ------ [ aws_security_group - us-east-1 ] ---------------------------------------------- #

resource "aws_security_group" "us_east_1" {

  # Iterate through all Security Groups in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.network_interface_security_groups_by_region.us_east_1

  # Define the Security Group Properties
  description = each.value.description
  name        = each.key
  tags        = each.value.tags
  vpc_id      = each.value.vpc_id

  lifecycle {
    # Changing a security group's description forces replacement, which AWS refuses while the
    # group is attached to a live ENI, so the authored description is fixed at creation.
    ignore_changes = [description]
  }

}

#endregion --- [ aws_security_group - us-east-1 ] ---------------------------------------------- #

#endregion --- [ aws_security_group ] ---------------------------------------------------------- #


#region ------ [ aws_security_group.runner_ingress ] ------------------------------------------- #

#region ------ [ aws_security_group.runner_ingress - us-east-1 ] ------------------------------- #

resource "aws_security_group" "runner_ingress_us_east_1" {

  # Iterate through the Run-Scoped Runner Ingress Security Group in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.runner_ingress_security_groups.us_east_1

  # Define the Security Group Properties
  description = each.value.description
  name        = each.value.name
  tags        = each.value.tags
  vpc_id      = each.value.vpc_id

  lifecycle {
    # A security group lives in exactly one VPC, so one shared group cannot cover a fleet spread
    # across several. Fail here rather than attach to whichever VPC sorted first and leave the
    # rest silently unreachable.
    precondition {
      condition = length(local.runner_ingress_vpc_ids.us_east_1) == 1
      error_message = format(
        join(" ", [
          "runner_ip is set, but all_systems resolves to %d VPCs (%s). One security group cannot",
          "span VPCs. Deploy the systems sharing a VPC separately, or clear runner_ip.",
        ]),
        length(local.runner_ingress_vpc_ids.us_east_1),
        join(", ", local.runner_ingress_vpc_ids.us_east_1),
      )
    }

    # Changing a security group's description forces replacement, which AWS refuses while the
    # group is attached to a live ENI, so the authored description is fixed at creation.
    ignore_changes = [description]
  }

}

#endregion --- [ aws_security_group.runner_ingress - us-east-1 ] ------------------------------- #

#endregion --- [ aws_security_group.runner_ingress ] ------------------------------------------- #


#region ------ [ aws_vpc_security_group_ingress_rule ] ----------------------------------------- #

#region ------ [ aws_vpc_security_group_ingress_rule - us-east-1 ] ----------------------------- #

resource "aws_vpc_security_group_ingress_rule" "us_east_1" {

  # Iterate through all Security Group Ingress Rules in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.network_interface_security_group_ingress_rules.us_east_1

  # Define the Security Group Ingress Rule Properties
  cidr_ipv4                    = each.value.cidr_ipv4
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.us_east_1[each.value.sg_key].id
  tags                         = each.value.tags
  to_port                      = each.value.to_port

}

#endregion --- [ aws_vpc_security_group_ingress_rule - us-east-1 ] ----------------------------- #

#endregion --- [ aws_vpc_security_group_ingress_rule ] ----------------------------------------- #


#region ------ [ aws_vpc_security_group_ingress_rule.runner_ingress ] -------------------------- #

#region ------ [ aws_vpc_security_group_ingress_rule.runner_ingress - us-east-1 ] -------------- #

resource "aws_vpc_security_group_ingress_rule" "runner_ingress_us_east_1" {

  # Iterate through all Run-Scoped Runner Ingress Rules in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.runner_ingress_security_group_rules.us_east_1

  # Define the Security Group Ingress Rule Properties
  cidr_ipv4                    = each.value.cidr_ipv4
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.runner_ingress_us_east_1[each.value.sg_key].id
  tags                         = each.value.tags
  to_port                      = each.value.to_port

}

#endregion --- [ aws_vpc_security_group_ingress_rule.runner_ingress - us-east-1 ] -------------- #

#endregion --- [ aws_vpc_security_group_ingress_rule.runner_ingress ] -------------------------- #


#region ------ [ aws_vpc_security_group_egress_rule ] ------------------------------------------ #

#region ------ [ aws_vpc_security_group_egress_rule - us-east-1 ] ------------------------------ #

resource "aws_vpc_security_group_egress_rule" "us_east_1" {

  # Iterate through all Security Group Egress Rules in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.network_interface_security_group_egress_rules.us_east_1

  # Define the Security Group Egress Rule Properties
  cidr_ipv4                    = each.value.cidr_ipv4
  description                  = each.value.description
  from_port                    = each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = aws_security_group.us_east_1[each.value.sg_key].id
  tags                         = each.value.tags
  to_port                      = each.value.to_port

}

#endregion --- [ aws_vpc_security_group_egress_rule - us-east-1 ] ------------------------------ #

#endregion --- [ aws_vpc_security_group_egress_rule ] ------------------------------------------ #


#region ------ [ aws_eip ] --------------------------------------------------------------------- #

#region ------ [ aws_eip - us-east-1 ] --------------------------------------------------------- #

resource "aws_eip" "us_east_1" {

  # Iterate through all Elastic IPs in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.eip_systems.us_east_1

  # Define the Elastic IP Properties
  domain = "vpc"
  tags   = each.value.tags

}

#endregion --- [ aws_eip - us-east-1 ] --------------------------------------------------------- #

#endregion --- [ aws_eip ] --------------------------------------------------------------------- #


#region ------ [ aws_eip_association ] --------------------------------------------------------- #

#region ------ [ aws_eip_association - us-east-1 ] --------------------------------------------- #

resource "aws_eip_association" "us_east_1" {

  # Iterate through all EIP Associations in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.eip_systems.us_east_1

  # Define the EIP Association Properties
  allocation_id        = aws_eip.us_east_1[each.key].id
  network_interface_id = aws_network_interface.us_east_1["${each.key}-eni-0"].id

  # Associating by interface rather than by instance is deliberate: the interface outlives an
  # OS swap, so the replacement instance inherits the address with no association churn and no
  # window without a public IP. The cost is that this resource's only real dependencies are the
  # address and the interface, both of which exist before the instance does - so nothing stops
  # AssociateAddress being called while the instance is still pending-instance-creation, which
  # AWS rejects with IncorrectInstanceState and the provider does not retry.
  #
  # The edge is therefore stated rather than derived. It is coarse - every association waits for
  # every instance rather than its own, because depends_on cannot be computed per key - and that
  # is acceptable: association is fast, and the alternative is an apply that fails roughly one
  # run in ten with most of the stack already created.
  #
  # Enforced by `make eip-order-check`, because a plan cannot see a race and the tests cannot
  # see the graph.
  depends_on = [
    aws_instance.us_east_1,
    aws_instance.us_east_1_refresh,
  ]

}

#endregion --- [ aws_eip_association - us-east-1 ] --------------------------------------------- #

#endregion --- [ aws_eip_association ] --------------------------------------------------------- #


#region ------ [ aws_network_interface ] ------------------------------------------------------- #

#region ------ [ aws_network_interface - us-east-1 ] ------------------------------------------- #

resource "aws_network_interface" "us_east_1" {

  # Iterate through all Elastic Network Interfaces in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.elastic_network_interfaces.us_east_1

  # Define the Elastic Network Interface Properties
  description     = each.value.description
  interface_type  = each.value.interface_type
  private_ips     = each.value.private_ips
  security_groups = each.value.security_groups
  subnet_id       = each.value.subnet_id
  tags            = each.value.tags

  # These two checks used to be variable validations fed by caller-declared subnet metadata. The
  # subnet is now read directly, so they compare against the real thing instead - which means they
  # must be preconditions: a variable validation runs before any data source is read.
  lifecycle {
    precondition {
      condition = (
        each.value.availability_zone ==
        data.aws_subnet.us_east_1[each.value.subnet_id].availability_zone
      )
      error_message = format(
        "System %s declares availability_zone %s, but subnet %s is in %s. An interface is created in its subnet's zone, so the instance and its volumes must name that same zone.",
        each.value.hostname,
        each.value.availability_zone,
        each.value.subnet_id,
        data.aws_subnet.us_east_1[each.value.subnet_id].availability_zone,
      )
    }

    # AWS reserves five addresses in every subnet: the first four and the last.
    precondition {
      condition = each.value.private_ip == null || (
        cidrhost(
          "${each.value.private_ip}/${split("/", data.aws_subnet.us_east_1[each.value.subnet_id].cidr_block)[1]}",
          0
        ) == cidrhost(data.aws_subnet.us_east_1[each.value.subnet_id].cidr_block, 0) &&
        !contains(
          [
            for reserved in [0, 1, 2, 3, -1] :
            cidrhost(data.aws_subnet.us_east_1[each.value.subnet_id].cidr_block, reserved)
          ],
          each.value.private_ip,
        )
      )
      error_message = format(
        "Pinned private_ip %s on %s falls outside subnet %s (%s) or lands on one of the five addresses AWS reserves in it. Leave private_ip null to let AWS pick.",
        coalesce(each.value.private_ip, "null"),
        each.value.hostname,
        each.value.subnet_id,
        data.aws_subnet.us_east_1[each.value.subnet_id].cidr_block,
      )
    }
  }

}

#endregion --- [ aws_network_interface - us-east-1 ] ------------------------------------------- #

#endregion --- [ aws_network_interface ] ------------------------------------------------------- #


#region ------ [ aws_lb ] ---------------------------------------------------------------------- #

#region ------ [ aws_lb - us-east-1 ] ---------------------------------------------------------- #

resource "aws_lb" "us_east_1" {

  # Iterate through all Elastic Load Balancers in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.elastic_load_balancers.us_east_1

  # Define the Elastic Load Balancer Properties
  client_keep_alive                                            = each.value.client_keep_alive
  customer_owned_ipv4_pool                                     = each.value.customer_owned_ipv4_pool
  desync_mitigation_mode                                       = each.value.desync_mitigation_mode
  dns_record_client_routing_policy                             = each.value.dns_record_client_routing_policy
  drop_invalid_header_fields                                   = each.value.drop_invalid_header_fields
  enable_cross_zone_load_balancing                             = each.value.enable_cross_zone_load_balancing
  enable_deletion_protection                                   = each.value.enable_deletion_protection
  enable_http2                                                 = each.value.enable_http2
  enable_tls_version_and_cipher_suite_headers                  = each.value.enable_tls_version_and_cipher_suite_headers
  enable_waf_fail_open                                         = each.value.enable_waf_fail_open
  enable_xff_client_port                                       = each.value.enable_xff_client_port
  enable_zonal_shift                                           = each.value.enable_zonal_shift
  enforce_security_group_inbound_rules_on_private_link_traffic = each.value.load_balancer_type == "network" ? "on" : null
  idle_timeout                                                 = each.value.idle_timeout
  internal                                                     = each.value.internal
  ip_address_type                                              = each.value.ip_address_type
  load_balancer_type                                           = each.value.load_balancer_type
  name                                                         = each.value.name
  name_prefix                                                  = each.value.name_prefix
  preserve_host_header                                         = each.value.preserve_host_header
  secondary_ips_auto_assigned_per_subnet                       = each.value.secondary_ips_auto_assigned_per_subnet
  security_groups                                              = each.value.security_groups
  subnets                                                      = each.value.subnets
  tags                                                         = each.value.tags
  xff_header_processing_mode                                   = each.value.xff_header_processing_mode

  dynamic "access_logs" {
    for_each = each.value.access_logs == null ? [] : [each.value.access_logs]

    content {
      bucket  = access_logs.value.bucket
      enabled = access_logs.value.enabled
      prefix  = access_logs.value.prefix
    }
  }

  dynamic "connection_logs" {
    for_each = each.value.connection_logs == null ? [] : [each.value.connection_logs]

    content {
      bucket  = connection_logs.value.bucket
      enabled = connection_logs.value.enabled
      prefix  = connection_logs.value.prefix
    }
  }

  dynamic "health_check_logs" {
    for_each = each.value.health_check_logs == null ? [] : [each.value.health_check_logs]

    content {
      bucket  = health_check_logs.value.bucket
      enabled = health_check_logs.value.enabled
      prefix  = health_check_logs.value.prefix
    }
  }

  dynamic "ipam_pools" {
    for_each = each.value.ipam_pools == null ? [] : [each.value.ipam_pools]

    content {
      ipv4_ipam_pool_id = ipam_pools.value.ipv4_ipam_pool_id
    }
  }

  dynamic "minimum_load_balancer_capacity" {
    for_each = each.value.minimum_load_balancer_capacity == null ? [] : [each.value.minimum_load_balancer_capacity]

    content {
      capacity_units = minimum_load_balancer_capacity.value.capacity_units
    }
  }

  dynamic "subnet_mapping" {
    for_each = each.value.subnet_mapping == null ? [] : each.value.subnet_mapping

    content {
      allocation_id        = subnet_mapping.value.allocation_id
      ipv6_address         = subnet_mapping.value.ipv6_address
      private_ipv4_address = subnet_mapping.value.private_ipv4_address
      subnet_id            = subnet_mapping.value.subnet_id
    }
  }

  dynamic "timeouts" {
    for_each = each.value.timeouts == null ? [] : [each.value.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      update = timeouts.value.update
    }
  }

}

#endregion --- [ aws_lb - us-east-1 ] ---------------------------------------------------------- #

#endregion --- [ aws_lb ] ---------------------------------------------------------------------- #


#region ------ [ aws_lb_target_group ] --------------------------------------------------------- #

#region ------ [ aws_lb_target_group - us-east-1 ] --------------------------------------------- #

resource "aws_lb_target_group" "us_east_1" {

  # Iterate through all Elastic Load Balancer Target Groups in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.lb_target_groups.us_east_1

  # Define the Elastic Load Balancer Target Group Properties
  connection_termination            = each.value.connection_termination
  deregistration_delay              = each.value.deregistration_delay
  ip_address_type                   = each.value.ip_address_type
  load_balancing_algorithm_type     = each.value.load_balancing_algorithm_type
  load_balancing_anomaly_mitigation = each.value.load_balancing_anomaly_mitigation
  load_balancing_cross_zone_enabled = each.value.load_balancing_cross_zone_enabled
  port                              = each.value.port
  preserve_client_ip                = each.value.preserve_client_ip
  protocol                          = each.value.protocol
  protocol_version                  = each.value.protocol_version
  proxy_protocol_v2                 = each.value.proxy_protocol_v2
  slow_start                        = each.value.slow_start
  tags                              = each.value.tags
  target_type                       = each.value.target_type
  vpc_id                            = each.value.vpc_id

  dynamic "health_check" {
    for_each = each.value.health_check == null ? [] : [each.value.health_check]

    content {
      enabled             = health_check.value.enabled
      healthy_threshold   = health_check.value.healthy_threshold
      interval            = health_check.value.interval
      matcher             = health_check.value.matcher
      path                = health_check.value.path
      port                = health_check.value.port
      protocol            = health_check.value.protocol
      timeout             = health_check.value.timeout
      unhealthy_threshold = health_check.value.unhealthy_threshold
    }
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness == null ? [] : [each.value.stickiness]

    content {
      cookie_duration = stickiness.value.cookie_duration
      cookie_name     = stickiness.value.cookie_name
      enabled         = stickiness.value.enabled
      type            = stickiness.value.type
    }
  }

}

#endregion --- [ aws_lb_target_group - us-east-1 ] --------------------------------------------- #

#endregion --- [ aws_lb_target_group ] --------------------------------------------------------- #


#region ------ [ aws_lb_target_group_attachment ] ---------------------------------------------- #

#region ------ [ aws_lb_target_group_attachment - us-east-1 ] ---------------------------------- #

resource "aws_lb_target_group_attachment" "us_east_1" {

  # Iterate through all Elastic Load Balancer Target Group Attachments in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.lb_target_group_attachments.us_east_1

  # Define the Elastic Load Balancer Target Group Attachment Properties
  port             = each.value.port
  target_group_arn = aws_lb_target_group.us_east_1[each.value.tg_key].arn
  target_id        = local.all_ec2_instances[each.value.hostname].id

}

#endregion --- [ aws_lb_target_group_attachment - us-east-1 ] ---------------------------------- #

#endregion --- [ aws_lb_target_group_attachment ] ---------------------------------------------- #


#region ------ [ aws_lb_listener ] ------------------------------------------------------------- #

#region ------ [ aws_lb_listener - us-east-1 ] ------------------------------------------------- #

resource "aws_lb_listener" "us_east_1" {

  # Iterate through all Elastic Load Balancer Listeners in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.lb_listeners.us_east_1

  # Define the Elastic Load Balancer Listener Properties
  alpn_policy       = each.value.alpn_policy
  certificate_arn   = each.value.certificate_arn
  load_balancer_arn = aws_lb.us_east_1[each.value.lb_key].arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.ssl_policy

  default_action {
    target_group_arn = each.value.default_action.type == "forward" ? aws_lb_target_group.us_east_1[each.value.default_action.target_group_key].arn : null
    type             = each.value.default_action.type

    dynamic "fixed_response" {
      for_each = each.value.default_action.fixed_response == null ? [] : [each.value.default_action.fixed_response]

      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }

    dynamic "redirect" {
      for_each = each.value.default_action.redirect == null ? [] : [each.value.default_action.redirect]

      content {
        host        = redirect.value.host
        path        = redirect.value.path
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        query       = redirect.value.query
        status_code = redirect.value.status_code
      }
    }
  }

}

#endregion --- [ aws_lb_listener - us-east-1 ] ------------------------------------------------- #

#endregion --- [ aws_lb_listener ] ------------------------------------------------------------- #


#region ------ [ aws_lb_listener_rule ] -------------------------------------------------------- #

#region ------ [ aws_lb_listener_rule - us-east-1 ] -------------------------------------------- #

resource "aws_lb_listener_rule" "us_east_1" {

  # Iterate through all Elastic Load Balancer Listener Rules in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.lb_listener_rules.us_east_1

  # Define the Elastic Load Balancer Listener Rule Properties
  listener_arn = aws_lb_listener.us_east_1[each.value.listener_key].arn
  priority     = each.value.priority

  action {
    target_group_arn = each.value.action.type == "forward" ? aws_lb_target_group.us_east_1[each.value.action.target_group_key].arn : null
    type             = each.value.action.type

    dynamic "redirect" {
      for_each = each.value.action.redirect == null ? [] : [each.value.action.redirect]

      content {
        host        = redirect.value.host
        path        = redirect.value.path
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        query       = redirect.value.query
        status_code = redirect.value.status_code
      }
    }

    dynamic "fixed_response" {
      for_each = each.value.action.fixed_response == null ? [] : [each.value.action.fixed_response]

      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.conditions

    content {
      dynamic "host_header" {
        for_each = condition.value.host_header == null ? [] : [condition.value.host_header]

        content {
          values = host_header.value
        }
      }

      dynamic "http_header" {
        for_each = condition.value.http_header == null ? [] : [condition.value.http_header]

        content {
          http_header_name = http_header.value.http_header_name
          values           = http_header.value.values
        }
      }

      dynamic "http_request_method" {
        for_each = condition.value.http_request_method == null ? [] : [condition.value.http_request_method]

        content {
          values = http_request_method.value
        }
      }

      dynamic "path_pattern" {
        for_each = condition.value.path_pattern == null ? [] : [condition.value.path_pattern]

        content {
          values = path_pattern.value
        }
      }

      dynamic "query_string" {
        for_each = condition.value.query_string == null ? [] : condition.value.query_string

        content {
          key   = query_string.value.key
          value = query_string.value.value
        }
      }

      dynamic "source_ip" {
        for_each = condition.value.source_ip == null ? [] : [condition.value.source_ip]

        content {
          values = source_ip.value
        }
      }
    }
  }

}

#endregion --- [ aws_lb_listener_rule - us-east-1 ] -------------------------------------------- #

#endregion --- [ aws_lb_listener_rule ] -------------------------------------------------------- #


#region ------ [ aws_lb_listener_certificate ] ------------------------------------------------- #

#region ------ [ aws_lb_listener_certificate - us-east-1 ] ------------------------------------- #

resource "aws_lb_listener_certificate" "us_east_1" {

  # Iterate through all Elastic Load Balancer Listener Certificates in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.lb_listener_certificates.us_east_1

  # Define the Elastic Load Balancer Listener Certificate Properties
  certificate_arn = each.value.certificate_arn
  listener_arn    = aws_lb_listener.us_east_1[each.value.listener_key].arn

}

#endregion --- [ aws_lb_listener_certificate - us-east-1 ] ------------------------------------- #

#endregion --- [ aws_lb_listener_certificate ] ------------------------------------------------- #


#region ------ [ aws_ebs_volume ] -------------------------------------------------------------- #

#region ------ [ aws_ebs_volume - us-east-1 ] -------------------------------------------------- #

resource "aws_ebs_volume" "us_east_1" {

  # Iterate through all Elastic Block Store Volumes in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.ebs_block_devices.us_east_1

  # Define the Elastic Block Store Volume Properties
  availability_zone = each.value.availability_zone
  encrypted         = true
  iops              = each.value.iops
  kms_key_id        = data.aws_kms_alias.us_east_1[each.value.kms_key_id].target_key_arn
  size              = each.value.volume_size
  snapshot_id       = each.value.snapshot_id
  tags              = each.value.tags
  throughput        = each.value.throughput
  type              = each.value.volume_type

}

#endregion --- [ aws_ebs_volume - us-east-1 ] -------------------------------------------------- #

#endregion --- [ aws_ebs_volume ] -------------------------------------------------------------- #


#region ------ [ aws_instance ] ---------------------------------------------------------------- #

#region ------ [ aws_instance - us-east-1 ] ---------------------------------------------------- #

resource "aws_instance" "us_east_1" {

  # Iterate through all Elastic Compute Cloud Instances in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.elastic_compute_cloud_stable.us_east_1

  # Define the Elastic Compute Cloud Instance Properties
  ami                         = local.amazon_machine_images[each.value.ami]["us_east_1"].id
  availability_zone           = each.value.availability_zone
  get_password_data           = each.value.get_password_data
  iam_instance_profile        = data.aws_iam_instance_profile.us_east_1[each.value.iam_instance_profile].name
  instance_type               = each.value.instance_type
  key_name                    = local.key_pair_names.us_east_1[each.value.key_name]
  tags                        = each.value.tags
  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  # A volume created by ebs_block_device with delete_on_termination = false is not reattached
  # when the instance is replaced: the old volume is abandoned and a new one is created.
  dynamic "ebs_block_device" {
    for_each = each.value.ami_block_device_overrides

    content {
      delete_on_termination = ebs_block_device.value.delete_on_termination
      device_name           = ebs_block_device.value.device_name
      encrypted             = true
      iops                  = ebs_block_device.value.iops
      kms_key_id            = data.aws_kms_alias.us_east_1[ebs_block_device.value.kms_key_id].target_key_arn
      tags                  = ebs_block_device.value.tags
      throughput            = ebs_block_device.value.throughput
      volume_size           = ebs_block_device.value.volume_size
      volume_type           = ebs_block_device.value.volume_type
    }
  }

  # http_tokens, http_protocol_ipv6, and instance_metadata_tags are module-owned
  # (ADR repo/0001): IMDSv2 is always enforced, the IMDS IPv6 endpoint stays off in this
  # IPv4-only framework, and instance tags are never exposed through the metadata service.
  # Only the hop limit is consumer-set (validated 1-2 in variables.tf).
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = each.value.imds_hop_limit
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  # Attach the existing index-zero ENI during launch so EC2 does not create a default interface.
  # Secondary ENIs are managed by aws_network_interface_attachment resources below.
  #
  # delete_on_termination is not set: the provider computes it, because AWS decides it. Attaching
  # an ENI that already exists by id defaults it to false, unlike an interface AWS creates at
  # launch, so the ENI outlives the instance and its pinned private address survives a refresh.
  primary_network_interface {
    network_interface_id = aws_network_interface.us_east_1["${each.key}-eni-0"].id
  }

  root_block_device {
    delete_on_termination = each.value.root_block_device.delete_on_termination
    encrypted             = true
    iops                  = each.value.root_block_device.iops
    kms_key_id            = data.aws_kms_alias.us_east_1[each.value.root_block_device.kms_key_id].target_key_arn
    tags                  = each.value.root_block_device.tags
    throughput            = each.value.root_block_device.throughput
    volume_size           = each.value.root_block_device.volume_size
    volume_type           = each.value.root_block_device.volume_type
  }

  lifecycle {
    precondition {
      condition = !each.value.is_windows || (
        length(each.value.hostname) <= 15 &&
        can(regex("^[0-9A-Za-z][0-9A-Za-z-]*$", each.value.hostname)) &&
        !can(regex("^[0-9]+$", each.value.hostname))
      )
      error_message = join(" ", [
        "Windows system hostnames must be 15 characters or less, contain only letters, numbers,",
        "and hyphens, and not be all numeric.",
      ])
    }

    # WinRM is Windows-only, and the operating system is data-resolved, so a variable validation
    # cannot see it. Checked on the instance rather than on the readiness gate because a system
    # reached over SSM has no gate - the rule has to cover "winrm-ssm" too.
    precondition {
      condition = each.value.connection_protocol != "winrm" || each.value.is_windows
      error_message = format(
        join(" ", [
          "System %s selects the WinRM protocol via connection_type = \"%s\", but its AMI",
          "resolves to a non-Windows platform. WinRM is Windows-only; use \"ssh\", \"ssh-ssm\",",
          "or null on Linux systems.",
        ]),
        each.key,
        each.value.connection_type,
      )
    }


    precondition {
      condition = length(each.value.uncovered_ami_block_devices) == 0
      error_message = format(
        join(" ", [
          "System %s launches AMI %s, which declares non-root block-device mapping(s) %s that",
          "ami_block_device_overrides does not cover. RunInstances would create them from the AMI",
          "snapshots with those snapshots' own encryption state, outside this module's",
          "all-volumes-encrypted invariant. Add an ami_block_device_overrides entry whose",
          "device_name matches each listed name exactly.",
        ]),
        each.value.hostname,
        each.value.ami,
        join(", ", each.value.uncovered_ami_block_devices),
      )
    }
  }

}

resource "aws_instance" "us_east_1_refresh" {

  # Iterate through all Elastic Compute Cloud Instances in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.elastic_compute_cloud_refresh.us_east_1

  # Define the Elastic Compute Cloud Instance Properties
  ami                         = local.amazon_machine_images[each.value.ami]["us_east_1"].id
  availability_zone           = each.value.availability_zone
  get_password_data           = each.value.get_password_data
  iam_instance_profile        = data.aws_iam_instance_profile.us_east_1[each.value.iam_instance_profile].name
  instance_type               = each.value.instance_type
  key_name                    = local.key_pair_names.us_east_1[each.value.key_name]
  tags                        = each.value.tags
  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  # A volume created by ebs_block_device with delete_on_termination = false is not reattached
  # when the instance is replaced: the old volume is abandoned and a new one is created.
  dynamic "ebs_block_device" {
    for_each = each.value.ami_block_device_overrides

    content {
      delete_on_termination = ebs_block_device.value.delete_on_termination
      device_name           = ebs_block_device.value.device_name
      encrypted             = true
      iops                  = ebs_block_device.value.iops
      kms_key_id            = data.aws_kms_alias.us_east_1[ebs_block_device.value.kms_key_id].target_key_arn
      tags                  = ebs_block_device.value.tags
      throughput            = ebs_block_device.value.throughput
      volume_size           = ebs_block_device.value.volume_size
      volume_type           = ebs_block_device.value.volume_type
    }
  }

  # http_tokens, http_protocol_ipv6, and instance_metadata_tags are module-owned
  # (ADR repo/0001): IMDSv2 is always enforced, the IMDS IPv6 endpoint stays off in this
  # IPv4-only framework, and instance tags are never exposed through the metadata service.
  # Only the hop limit is consumer-set (validated 1-2 in variables.tf).
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = each.value.imds_hop_limit
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  # Attach the existing index-zero ENI during launch so EC2 does not create a default interface.
  # Secondary ENIs are managed by aws_network_interface_attachment resources below.
  #
  # delete_on_termination is not set: the provider computes it, because AWS decides it. Attaching
  # an ENI that already exists by id defaults it to false, unlike an interface AWS creates at
  # launch, so the ENI outlives the instance and its pinned private address survives a refresh.
  primary_network_interface {
    network_interface_id = aws_network_interface.us_east_1["${each.key}-eni-0"].id
  }

  root_block_device {
    delete_on_termination = each.value.root_block_device.delete_on_termination
    encrypted             = true
    iops                  = each.value.root_block_device.iops
    kms_key_id            = data.aws_kms_alias.us_east_1[each.value.root_block_device.kms_key_id].target_key_arn
    tags                  = each.value.root_block_device.tags
    throughput            = each.value.root_block_device.throughput
    volume_size           = each.value.root_block_device.volume_size
    volume_type           = each.value.root_block_device.volume_type
  }

  lifecycle {
    replace_triggered_by = [
      terraform_data.refresh
    ]

    precondition {
      condition = !each.value.is_windows || (
        length(each.value.hostname) <= 15 &&
        can(regex("^[0-9A-Za-z][0-9A-Za-z-]*$", each.value.hostname)) &&
        !can(regex("^[0-9]+$", each.value.hostname))
      )
      error_message = join(" ", [
        "Windows system hostnames must be 15 characters or less, contain only letters, numbers,",
        "and hyphens, and not be all numeric.",
      ])
    }

    # WinRM is Windows-only, and the operating system is data-resolved, so a variable validation
    # cannot see it. Checked on the instance rather than on the readiness gate because a system
    # reached over SSM has no gate - the rule has to cover "winrm-ssm" too.
    precondition {
      condition = each.value.connection_protocol != "winrm" || each.value.is_windows
      error_message = format(
        join(" ", [
          "System %s selects the WinRM protocol via connection_type = \"%s\", but its AMI",
          "resolves to a non-Windows platform. WinRM is Windows-only; use \"ssh\", \"ssh-ssm\",",
          "or null on Linux systems.",
        ]),
        each.key,
        each.value.connection_type,
      )
    }


    precondition {
      condition = length(each.value.uncovered_ami_block_devices) == 0
      error_message = format(
        join(" ", [
          "System %s launches AMI %s, which declares non-root block-device mapping(s) %s that",
          "ami_block_device_overrides does not cover. RunInstances would create them from the AMI",
          "snapshots with those snapshots' own encryption state, outside this module's",
          "all-volumes-encrypted invariant. Add an ami_block_device_overrides entry whose",
          "device_name matches each listed name exactly.",
        ]),
        each.value.hostname,
        each.value.ami,
        join(", ", each.value.uncovered_ami_block_devices),
      )
    }
  }

}

#endregion --- [ aws_instance - us-east-1 ] ---------------------------------------------------- #

#endregion --- [ aws_instance ] ---------------------------------------------------------------- #


#region ------ [ aws_network_interface_attachment ] -------------------------------------------- #

#region ------ [ aws_network_interface_attachment - us-east-1 ] -------------------------------- #

resource "aws_network_interface_attachment" "us_east_1" {

  # Iterate through stable EC2 instances' secondary network interfaces in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.network_interface_attachments_stable.us_east_1

  # Define the Elastic Network Interface Attachment Properties
  device_index         = each.value.index
  instance_id          = aws_instance.us_east_1[each.value.hostname].id
  network_card_index   = 0
  network_interface_id = aws_network_interface.us_east_1[each.key].id

}

resource "aws_network_interface_attachment" "us_east_1_refresh" {

  # Iterate through refresh EC2 instances' secondary network interfaces in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.network_interface_attachments_refresh.us_east_1

  # Define the Elastic Network Interface Attachment Properties
  device_index         = each.value.index
  instance_id          = aws_instance.us_east_1_refresh[each.value.hostname].id
  network_card_index   = 0
  network_interface_id = aws_network_interface.us_east_1[each.key].id

}

#endregion --- [ aws_network_interface_attachment - us-east-1 ] -------------------------------- #

#endregion --- [ aws_network_interface_attachment ] -------------------------------------------- #


#region ------ [ terraform_data.readiness_gate ] ----------------------------------------------- #

#region ------ [ terraform_data.readiness_gate - us-east-1 ] ----------------------------------- #

# Block `apply` until each instance finishes provisioning and is reachable over SSH — the single
# readiness transport for every platform (WinRM is decommissioned). The connection retry
# (10-minute timeout) waits for sshd; the OS-native inline command then waits for the launch agent
# to finish (cloud-init on Linux, EC2Launch v2 on Windows) and fails the apply on a non-zero exit.
# Both platforms authenticate with the launch key pair (path supplied by
# each system's readiness_private_key_path; the Windows bootstrap installs the launch public key
# for Administrator). No `host_key` is pinned: the instance host key is generated at first boot
# and is not retrievable through the provider, so the gate trusts the first host answering at the
# private IP. Public-key auth means the launch key cannot be captured, and the channel carries
# only the launch-agent wait command. Systems with readiness_gate = false are absent from
# readiness_targets and create no gate at all. On a SEPARATE terraform_data so a gate failure
# taints only this resource, never the EC2 instance.
resource "terraform_data" "readiness_gate" {

  # Iterate through all Readiness Gates in the US-East-1 region.
  for_each = local.readiness_targets.us_east_1

  # Define the Readiness Gate Properties
  triggers_replace = {
    instance_id = each.value.id
  }

  lifecycle {
    # The WinRM/Windows rule lives on the instance, not here: a system reached over SSM has no
    # readiness gate, so a copy of it on this resource would not cover "winrm-ssm".
    precondition {
      condition     = each.value.private_key_path == null || fileexists(each.value.private_key_path)
      error_message = "readiness_private_key_path for host ${each.key} points at ${coalesce(each.value.private_key_path, "null")}, which does not exist on the machine running Terraform; fix the path or set it null, otherwise the readiness gate only fails after its ten-minute timeout."
    }
  }

  provisioner "remote-exec" {
    inline = [
      each.value.readiness_command,
    ]

    connection {
      host            = each.value.private_ip
      https           = each.value.use_winrm
      insecure        = each.value.use_winrm
      password        = each.value.password
      port            = each.value.use_winrm ? each.value.winrm_port : null
      private_key     = each.value.use_winrm || each.value.private_key_path == null ? null : file(each.value.private_key_path)
      script_path     = each.value.script_path
      target_platform = each.value.target_platform
      timeout         = "10m"
      type            = each.value.use_winrm ? "winrm" : "ssh"
      use_ntlm        = each.value.use_winrm
      user            = each.value.readiness_user
    }
  }

}

#endregion --- [ terraform_data.readiness_gate - us-east-1 ] ----------------------------------- #

#endregion --- [ terraform_data.readiness_gate ] ----------------------------------------------- #


#region ------ [ aws_volume_attachment ] ------------------------------------------------------- #

#region ------ [ aws_volume_attachment - us-east-1 ] ------------------------------------------- #

resource "aws_volume_attachment" "us_east_1" {

  # Iterate through all Elastic Block Store Volume Attachments in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.ebs_block_devices_stable.us_east_1

  # Define the Elastic Block Store Volume Attachment Properties
  # Stopping the instance before detaching prevents VolumeInUse wedges and force-detach
  # filesystem corruption on a mounted volume.
  device_name                    = each.value.device_name
  instance_id                    = aws_instance.us_east_1[each.value.hostname].id
  skip_destroy                   = each.value.skip_destroy
  stop_instance_before_detaching = true
  volume_id                      = aws_ebs_volume.us_east_1[each.key].id

}

resource "aws_volume_attachment" "us_east_1_refresh" {

  # Iterate through all Elastic Block Store Volume Attachments in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.ebs_block_devices_refresh.us_east_1

  # Define the Elastic Block Store Volume Attachment Properties
  # Stopping the instance before detaching prevents VolumeInUse wedges and force-detach
  # filesystem corruption on a mounted volume.
  device_name                    = each.value.device_name
  instance_id                    = aws_instance.us_east_1_refresh[each.value.hostname].id
  skip_destroy                   = each.value.skip_destroy
  stop_instance_before_detaching = true
  volume_id                      = aws_ebs_volume.us_east_1[each.key].id

}

#endregion --- [ aws_volume_attachment - us-east-1 ] ------------------------------------------- #

#endregion --- [ aws_volume_attachment ] ------------------------------------------------------- #


#region ------ [ aws_db_instance ] ------------------------------------------------------------- #

#region ------ [ aws_db_instance - us-east-1 ] ------------------------------------------------- #

resource "aws_db_instance" "us_east_1" {

  # Iterate through all Relational Database Service Instances in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.relational_database_service.us_east_1

  # Define the Relational Database Service Instance Properties
  allocated_storage                   = each.value.allocated_storage
  availability_zone                   = each.value.availability_zone
  backup_retention_period             = each.value.backup_retention_period
  backup_window                       = each.value.backup_window
  ca_cert_identifier                  = each.value.ca_cert_identifier
  db_name                             = each.value.db_name
  db_subnet_group_name                = each.value.db_subnet_group_name
  dedicated_log_volume                = each.value.dedicated_log_volume
  delete_automated_backups            = each.value.delete_automated_backups
  deletion_protection                 = each.value.deletion_protection
  engine                              = each.value.engine
  engine_version                      = each.value.engine_version
  final_snapshot_identifier           = each.value.final_snapshot_identifier
  iam_database_authentication_enabled = each.value.iam_database_authentication_enabled
  identifier                          = each.value.identifier
  instance_class                      = each.value.instance_class
  kms_key_id                          = data.aws_kms_alias.us_east_1[each.value.kms_key_id].target_key_arn
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = data.aws_kms_alias.us_east_1[each.value.kms_key_id].target_key_arn
  max_allocated_storage               = each.value.max_allocated_storage
  publicly_accessible                 = false
  skip_final_snapshot                 = each.value.skip_final_snapshot
  storage_encrypted                   = true
  storage_type                        = each.value.storage_type
  tags                                = each.value.tags
  username                            = local.relational_database_service_credentials.us_east_1[each.key].username
  vpc_security_group_ids              = each.value.vpc_security_group_ids

  dynamic "blue_green_update" {
    for_each = each.value.blue_green_update ? [each.value.blue_green_update] : []

    content {
      enabled = blue_green_update.value
    }
  }

}

#endregion --- [ aws_db_instance - us-east-1 ] ------------------------------------------------- #

#endregion --- [ aws_db_instance ] ------------------------------------------------------------- #


#region ------ [ aws_ec2_instance_state ] ------------------------------------------------------ #

#region ------ [ aws_ec2_instance_state - us-east-1 ] ------------------------------------------ #

resource "aws_ec2_instance_state" "us_east_1" {

  # Iterate through all EC2 Instance States in the US-East-1 region.
  provider = aws.us_east_1
  for_each = local.ec2_instance_states.us_east_1

  # Define the EC2 Instance State Properties
  instance_id = each.value.instance_id
  state       = each.value.state

  # The gate, not the instance, marks the machine ready; starting or stopping it before the gate
  # returns races the launch agent.
  depends_on = [terraform_data.readiness_gate]

}

#endregion --- [ aws_ec2_instance_state - us-east-1 ] ------------------------------------------ #

#endregion --- [ aws_ec2_instance_state ] ------------------------------------------------------ #
