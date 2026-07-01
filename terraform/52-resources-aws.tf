#% =========================================================================================== %#
#% = File: 52-aws-resources.tf                                   | Category: Resources (50-59) %#
#% ----- [ Description ] --------------------------------------------------------------------- %#
#% Resources are the most important element in the Terraform language. Each resource block     %#
#%   describes one or more infrastructure objects, such as virtual networks, compute           %#
#%   instances, or higher-level components such as DNS records.                                %#
#% =========================================================================================== %#


#region ------ [ Create All Elastic Network Interfaces (ENIs) ] ------------------------------- #

#region ------ [ Create All Elastic Network Interfaces (ENIs) - us-west-2 ] ------------- #

resource "aws_network_interface" "us_west_2" {

  # Itterate through all network interfaces in the target region.
  for_each = local.elastic_network_interfaces.us_west_2

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Define the Network Interface Properties
  subnet_id       = each.value.subnet_id
  description     = each.value.description
  interface_type  = each.value.interface_type
  private_ips     = each.value.private_ips
  security_groups = each.value.security_groups
  tags            = each.value.tags

}

#endregion --- [ Create All Elastic Network Interfaces (ENIs) - us-west-2 ] ------------- #

#region ------ [ Create All Elastic Network Interfaces (ENIs) - us-east-1 ] ------------- #

resource "aws_network_interface" "us_east_1" {

  # Itterate through all network interfaces in the target region.
  for_each = local.elastic_network_interfaces.us_east_1

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Define the Network Interface Properties
  subnet_id       = each.value.subnet_id
  description     = each.value.description
  interface_type  = each.value.interface_type
  private_ips     = each.value.private_ips
  security_groups = each.value.security_groups
  tags            = each.value.tags

}

#endregion --- [ Create All Elastic Network Interfaces (ENIs) - us-east-1 ] ------------- #

#endregion --- [ Create All Elastic Network Interfaces (ENIs) ] ------------------------------- #


#region ------ [ Create All Elastic Load Balancers (ELBs) ] ---------------------------------- #

#region ------ [ Create All Elastic Load Balancers (ELBs) - us-west-2 ] ---------------- #

resource "aws_lb" "us_west_2" {

  # Itterate through all Elastic Load Balancers in the target region.
  for_each = local.elastic_load_balancers.us_west_2

  # Set the provider in which to deploy the load balancer.
  provider = aws.us_west_2

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
  enforce_security_group_inbound_rules_on_private_link_traffic = each.value.enforce_security_group_inbound_rules_on_private_link_traffic
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

#endregion --- [ Create All Elastic Load Balancers (ELBs) - us-west-2 ] ---------------- #

#region ------ [ Create All Elastic Load Balancers (ELBs) - us-east-1 ] ---------------- #

resource "aws_lb" "us_east_1" {

  # Itterate through all Elastic Load Balancers in the target region.
  for_each = local.elastic_load_balancers.us_east_1

  # Set the provider in which to deploy the load balancer.
  provider = aws.us_east_1

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
  enforce_security_group_inbound_rules_on_private_link_traffic = each.value.enforce_security_group_inbound_rules_on_private_link_traffic
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

#endregion --- [ Create All Elastic Load Balancers (ELBs) - us-east-1 ] ---------------- #

#endregion --- [ Create All Elastic Load Balancers (ELBs) ] ---------------------------------- #


#region ------ [ Create All Elastic Load Balancer Target Groups ] ----------------------------- #

#region ------ [ Create All Elastic Load Balancer Target Groups - us-west-2 ] ---------- #

resource "aws_lb_target_group" "us_west_2" {

  # Itterate through all Elastic Load Balancer target groups in the target region.
  for_each = local.lb_target_groups.us_west_2

  # Set the provider in which to deploy the target group.
  provider = aws.us_west_2

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

resource "aws_lb_target_group_attachment" "us_west_2" {

  # Itterate through all Elastic Load Balancer target group attachments in the target region.
  for_each = local.lb_target_group_attachments.us_west_2

  # Set the provider in which to deploy the target group attachment.
  provider = aws.us_west_2

  # Define the Elastic Load Balancer Target Group Attachment Properties
  target_group_arn = aws_lb_target_group.us_west_2[each.value.tg_key].arn
  target_id        = merge(aws_instance.us_west_2, aws_instance.us_west_2_refresh)[each.value.hostname].id
  port             = each.value.port

}

#endregion --- [ Create All Elastic Load Balancer Target Groups - us-west-2 ] ---------- #

#region ------ [ Create All Elastic Load Balancer Target Groups - us-east-1 ] ---------- #

resource "aws_lb_target_group" "us_east_1" {

  # Itterate through all Elastic Load Balancer target groups in the target region.
  for_each = local.lb_target_groups.us_east_1

  # Set the provider in which to deploy the target group.
  provider = aws.us_east_1

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

resource "aws_lb_target_group_attachment" "us_east_1" {

  # Itterate through all Elastic Load Balancer target group attachments in the target region.
  for_each = local.lb_target_group_attachments.us_east_1

  # Set the provider in which to deploy the target group attachment.
  provider = aws.us_east_1

  # Define the Elastic Load Balancer Target Group Attachment Properties
  target_group_arn = aws_lb_target_group.us_east_1[each.value.tg_key].arn
  target_id        = merge(aws_instance.us_east_1, aws_instance.us_east_1_refresh)[each.value.hostname].id
  port             = each.value.port

}

#endregion --- [ Create All Elastic Load Balancer Target Groups - us-east-1 ] ---------- #

#endregion --- [ Create All Elastic Load Balancer Target Groups ] ----------------------------- #


#region ------ [ Create All Elastic Load Balancer Listeners ] --------------------------------- #

#region ------ [ Create All Elastic Load Balancer Listeners - us-west-2 ] -------------- #

resource "aws_lb_listener" "us_west_2" {

  # Itterate through all Elastic Load Balancer listeners in the target region.
  for_each = local.lb_listeners.us_west_2

  # Set the provider in which to deploy the listener.
  provider = aws.us_west_2

  # Define the Elastic Load Balancer Listener Properties
  alpn_policy       = each.value.alpn_policy
  certificate_arn   = each.value.certificate_arn
  load_balancer_arn = aws_lb.us_west_2[each.value.lb_key].arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.ssl_policy

  default_action {
    target_group_arn = each.value.default_action.type == "forward" ? aws_lb_target_group.us_west_2[each.value.default_action.target_group_key].arn : null
    type             = each.value.default_action.type

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

    dynamic "fixed_response" {
      for_each = each.value.default_action.fixed_response == null ? [] : [each.value.default_action.fixed_response]

      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

}

resource "aws_lb_listener_rule" "us_west_2" {

  # Itterate through all Elastic Load Balancer listener rules in the target region.
  for_each = local.lb_listener_rules.us_west_2

  # Set the provider in which to deploy the listener rule.
  provider = aws.us_west_2

  # Define the Elastic Load Balancer Listener Rule Properties
  listener_arn = aws_lb_listener.us_west_2[each.value.listener_key].arn
  priority     = each.value.priority

  action {
    target_group_arn = each.value.action.type == "forward" ? aws_lb_target_group.us_west_2[each.value.action.target_group_key].arn : null
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

resource "aws_lb_listener_certificate" "us_west_2" {

  # Itterate through all Elastic Load Balancer listener certificates in the target region.
  for_each = local.lb_listener_certificates.us_west_2

  # Set the provider in which to deploy the listener certificate.
  provider = aws.us_west_2

  # Define the Elastic Load Balancer Listener Certificate Properties
  certificate_arn = each.value.certificate_arn
  listener_arn    = aws_lb_listener.us_west_2[each.value.listener_key].arn

}

#endregion --- [ Create All Elastic Load Balancer Listeners - us-west-2 ] -------------- #

#region ------ [ Create All Elastic Load Balancer Listeners - us-east-1 ] -------------- #

resource "aws_lb_listener" "us_east_1" {

  # Itterate through all Elastic Load Balancer listeners in the target region.
  for_each = local.lb_listeners.us_east_1

  # Set the provider in which to deploy the listener.
  provider = aws.us_east_1

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

    dynamic "fixed_response" {
      for_each = each.value.default_action.fixed_response == null ? [] : [each.value.default_action.fixed_response]

      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

}

resource "aws_lb_listener_rule" "us_east_1" {

  # Itterate through all Elastic Load Balancer listener rules in the target region.
  for_each = local.lb_listener_rules.us_east_1

  # Set the provider in which to deploy the listener rule.
  provider = aws.us_east_1

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

resource "aws_lb_listener_certificate" "us_east_1" {

  # Itterate through all Elastic Load Balancer listener certificates in the target region.
  for_each = local.lb_listener_certificates.us_east_1

  # Set the provider in which to deploy the listener certificate.
  provider = aws.us_east_1

  # Define the Elastic Load Balancer Listener Certificate Properties
  certificate_arn = each.value.certificate_arn
  listener_arn    = aws_lb_listener.us_east_1[each.value.listener_key].arn

}

#endregion --- [ Create All Elastic Load Balancer Listeners - us-east-1 ] -------------- #

#endregion --- [ Create All Elastic Load Balancer Listeners ] --------------------------------- #


#region ------ [ Create All Elastic Block Store (EBS) Objects ] ------------------------------- #

#region ------ [ Create All Elastic Block Store (EBS) Objects - us-west-2 ] ------------- #

resource "aws_ebs_volume" "us_west_2" {

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_west_2 : k => v
    if v.refresh == false
  }

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Define the Elastic Block Store Properties
  availability_zone = each.value.availability_zone
  encrypted         = true
  iops              = each.value.iops
  kms_key_id        = data.aws_kms_alias.us_west_2[each.value.kms_key_id].target_key_arn
  snapshot_id       = each.value.snapshot_id
  tags              = each.value.tags
  throughput        = each.value.throughput
  size              = each.value.volume_size
  type              = each.value.volume_type

}

resource "aws_ebs_volume" "us_west_2_refresh" {

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_west_2 : k => v
    if v.refresh == true
  }

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Define the Elastic Block Store Properties
  availability_zone = each.value.availability_zone
  encrypted         = true
  iops              = each.value.iops
  kms_key_id        = data.aws_kms_alias.us_west_2[each.value.kms_key_id].target_key_arn
  snapshot_id       = each.value.snapshot_id
  tags              = each.value.tags
  throughput        = each.value.throughput
  size              = each.value.volume_size
  type              = each.value.volume_type

}

#endregion --- [ Create All Elastic Block Store (EBS) Objects - us-west-2 ] ------------- #

#region ------ [ Create All Elastic Block Store (EBS) Objects - us-east-1 ] ------------- #

resource "aws_ebs_volume" "us_east_1" {

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_east_1 : k => v
    if v.refresh == false
  }

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Define the Elastic Block Store Properties
  availability_zone = each.value.availability_zone
  encrypted         = true
  iops              = each.value.iops

  snapshot_id = each.value.snapshot_id
  tags        = each.value.tags
  throughput  = each.value.throughput
  size        = each.value.volume_size
  type        = each.value.volume_type

  # ?Note: Using the lookup function, search inside the 'local.all_kms_keys' object map for a
  # ?  object with the key matching the value of 'system.aws_kms_alias'.
  kms_key_id = data.aws_kms_alias.us_east_1[each.value.kms_key_id].target_key_arn

}

resource "aws_ebs_volume" "us_east_1_refresh" {

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_east_1 : k => v
    if v.refresh == true
  }

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Define the Elastic Block Store Properties
  availability_zone = each.value.availability_zone
  encrypted         = true
  iops              = each.value.iops

  snapshot_id = each.value.snapshot_id
  tags        = each.value.tags
  throughput  = each.value.throughput
  size        = each.value.volume_size
  type        = each.value.volume_type

  # ?Note: Using the lookup function, search inside the 'local.all_kms_keys' object map for a
  # ?  object with the key matching the value of 'system.aws_kms_alias'.
  kms_key_id = data.aws_kms_alias.us_east_1[each.value.kms_key_id].target_key_arn

}

#endregion --- [ Create All Elastic Block Store (EBS) Objects - us-west-2 ] ------------- #

#endregion --- [ Create All Elastic Block Store (EBS) Objects ] ------------------------------- #


#region ------ [ Create All Elastic Computer Cloud (EC2s) ] ----------------------------------- #

resource "aws_instance" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.elastic_compute_cloud.us_west_2 : k => v
    if v.refresh == false
  }

  ami                         = local.amazon_machine_images[each.value.ami]["us_west_2"].id
  instance_type               = each.value.instance_type
  availability_zone           = each.value.availability_zone
  get_password_data           = each.value.get_password_data
  tags                        = each.value.tags
  key_name                    = data.aws_key_pair.us_west_2[each.value.key_name].key_name
  iam_instance_profile        = data.aws_iam_instance_profile.us_west_2[each.value.iam_instance_profile].name
  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = each.value.root_block_device.volume_type
    volume_size           = each.value.root_block_device.volume_size
    encrypted             = true
    delete_on_termination = each.value.root_block_device.delete_on_termination
    iops                  = each.value.root_block_device.iops
    tags                  = each.value.root_block_device.tags
    throughput            = each.value.root_block_device.throughput
    kms_key_id = (
      data.aws_kms_alias.us_west_2[each.value.root_block_device.kms_key_id].target_key_arn
    )
  }

  # ?Note: Network interface(s) need to be attached on creation otherwise a default interface
  # ?  will be created reguardless of what else has been configured, and network interfaces
  # ?  can only be attached while the system is powered off causing serious workflow issues.
  dynamic "network_interface" {
    for_each = {
      for eni_key, network_interface in aws_network_interface.us_west_2 :
      eni_key => {
        id    = network_interface.id
        index = local.elastic_network_interfaces.us_west_2[eni_key].index
      }
      if local.elastic_network_interfaces.us_west_2[eni_key].hostname == each.value.hostname
    }
    content {
      delete_on_termination = false
      device_index          = network_interface.value.index
      network_card_index    = network_interface.value.index
      network_interface_id  = network_interface.value.id
    }
  }

  # ?Note: Volumes created with ebs_block_device and have 'delete_on_termination = false'
  # ?  configured will not automatically reattach the volume when the EC2 instance is
  # ?  recreated, it will just abandon the volume and create/attach a new volume.
  # dynamic "ebs_block_device" {}

}

resource "aws_instance" "us_west_2_refresh" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.elastic_compute_cloud.us_west_2 : k => v
    if v.refresh == true
  }

  ami                         = local.amazon_machine_images[each.value.ami]["us_west_2"].id
  instance_type               = each.value.instance_type
  availability_zone           = each.value.availability_zone
  get_password_data           = each.value.get_password_data
  tags                        = each.value.tags
  key_name                    = data.aws_key_pair.us_west_2[each.value.key_name].key_name
  iam_instance_profile        = data.aws_iam_instance_profile.us_west_2[each.value.iam_instance_profile].name
  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = each.value.root_block_device.volume_type
    volume_size           = each.value.root_block_device.volume_size
    encrypted             = true
    delete_on_termination = each.value.root_block_device.delete_on_termination
    iops                  = each.value.root_block_device.iops
    tags                  = each.value.root_block_device.tags
    throughput            = each.value.root_block_device.throughput
    kms_key_id = (
      data.aws_kms_alias.us_west_2[each.value.root_block_device.kms_key_id].target_key_arn
    )
  }

  # ?Note: Network interface(s) need to be attached on creation otherwise a default interface
  # ?  will be created reguardless of what else has been configured, and network interfaces
  # ?  can only be attached while the system is powered off causing serious workflow issues.
  dynamic "network_interface" {
    for_each = {
      for eni_key, network_interface in aws_network_interface.us_west_2 :
      eni_key => {
        id    = network_interface.id
        index = local.elastic_network_interfaces.us_west_2[eni_key].index
      }
      if local.elastic_network_interfaces.us_west_2[eni_key].hostname == each.value.hostname
    }
    content {
      delete_on_termination = false
      device_index          = network_interface.value.index
      network_card_index    = network_interface.value.index
      network_interface_id  = network_interface.value.id
    }
  }

  # ?Note: Volumes created with ebs_block_device and have 'delete_on_termination = false'
  # ?  configured will not automatically reattach the volume when the EC2 instance is
  # ?  recreated, it will just abandon the volume and create/attach a new volume.
  # dynamic "ebs_block_device" {}

  lifecycle {
    replace_triggered_by = [
      terraform_data.refresh
    ]
  }

}

resource "aws_instance" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.elastic_compute_cloud.us_east_1 : k => v
    if v.refresh == false
  }

  ami                         = local.amazon_machine_images[each.value.ami]["us_east_1"].id
  instance_type               = each.value.instance_type
  availability_zone           = each.value.availability_zone
  get_password_data           = each.value.get_password_data
  tags                        = each.value.tags
  key_name                    = data.aws_key_pair.us_east_1[each.value.key_name].key_name
  iam_instance_profile        = data.aws_iam_instance_profile.us_east_1[each.value.iam_instance_profile].name
  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = each.value.root_block_device.volume_type
    volume_size           = each.value.root_block_device.volume_size
    encrypted             = true
    delete_on_termination = each.value.root_block_device.delete_on_termination
    iops                  = each.value.root_block_device.iops
    tags                  = each.value.root_block_device.tags
    throughput            = each.value.root_block_device.throughput
    kms_key_id = (
      data.aws_kms_alias.us_east_1[each.value.root_block_device.kms_key_id].target_key_arn
    )
  }

  # ?Note: Network interface(s) need to be attached on creation otherwise a default interface
  # ?  will be created reguardless of what else has been configured, and network interfaces
  # ?  can only be attached while the system is powered off causing serious workflow issues.
  dynamic "network_interface" {
    for_each = {
      for eni_key, network_interface in aws_network_interface.us_east_1 :
      eni_key => {
        id    = network_interface.id
        index = local.elastic_network_interfaces.us_east_1[eni_key].index
      }
      if local.elastic_network_interfaces.us_east_1[eni_key].hostname == each.value.hostname
    }
    content {
      delete_on_termination = false
      device_index          = network_interface.value.index
      network_card_index    = network_interface.value.index
      network_interface_id  = network_interface.value.id
    }
  }

  # ?Note: Volumes created with ebs_block_device and have 'delete_on_termination = false'
  # ?  configured will not automatically reattach the volume when the EC2 instance is
  # ?  recreated, it will just abandon the volume and create/attach a new volume.
  # dynamic "ebs_block_device" {}

}

resource "aws_instance" "us_east_1_refresh" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Itterate through all network interfaces in the target region.
  for_each = {
    for k, v in local.elastic_compute_cloud.us_east_1 : k => v
    if v.refresh == true
  }

  ami                         = local.amazon_machine_images[each.value.ami]["us_east_1"].id
  instance_type               = each.value.instance_type
  availability_zone           = each.value.availability_zone
  get_password_data           = each.value.get_password_data
  tags                        = each.value.tags
  key_name                    = data.aws_key_pair.us_east_1[each.value.key_name].key_name
  iam_instance_profile        = data.aws_iam_instance_profile.us_east_1[each.value.iam_instance_profile].name
  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = each.value.root_block_device.volume_type
    volume_size           = each.value.root_block_device.volume_size
    encrypted             = true
    delete_on_termination = each.value.root_block_device.delete_on_termination
    iops                  = each.value.root_block_device.iops
    tags                  = each.value.root_block_device.tags
    throughput            = each.value.root_block_device.throughput
    kms_key_id = (
      data.aws_kms_alias.us_east_1[each.value.root_block_device.kms_key_id].target_key_arn
    )
  }

  # ?Note: Network interface(s) need to be attached on creation otherwise a default interface
  # ?  will be created reguardless of what else has been configured, and network interfaces
  # ?  can only be attached while the system is powered off causing serious workflow issues.
  dynamic "network_interface" {
    for_each = {
      for eni_key, network_interface in aws_network_interface.us_east_1 :
      eni_key => {
        id    = network_interface.id
        index = local.elastic_network_interfaces.us_east_1[eni_key].index
      }
      if local.elastic_network_interfaces.us_east_1[eni_key].hostname == each.value.hostname
    }
    content {
      delete_on_termination = false
      device_index          = network_interface.value.index
      network_card_index    = network_interface.value.index
      network_interface_id  = network_interface.value.id
    }
  }

  # ?Note: Volumes created with ebs_block_device and have 'delete_on_termination = false'
  # ?  configured will not automatically reattach the volume when the EC2 instance is
  # ?  recreated, it will just abandon the volume and create/attach a new volume.
  # dynamic "ebs_block_device" {}

  lifecycle {
    replace_triggered_by = [
      terraform_data.refresh
    ]
  }

}

#region ------ [ SSH Readiness Gate ] --------------------------------------------------------- #

# Combine each instance's runtime facts (id, private IP, key pair name) with its OS so the readiness
# gate can pick the right login user, wait command, and private key per instance.
locals {
  ssh_ready_targets = merge(
    {
      for hostname, instance in aws_instance.us_west_2 : hostname => {
        id         = instance.id
        private_ip = instance.private_ip
        key_name   = instance.key_name
        password   = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[hostname].ami))) ? try(sensitive(rsadecrypt(instance.password_data, file(var.ssh_readiness_private_key_paths[instance.key_name]))), null) : null
        is_windows = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[hostname].ami)))
      }
    },
    {
      for hostname, instance in aws_instance.us_west_2_refresh : hostname => {
        id         = instance.id
        private_ip = instance.private_ip
        key_name   = instance.key_name
        password   = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[hostname].ami))) ? try(sensitive(rsadecrypt(instance.password_data, file(var.ssh_readiness_private_key_paths[instance.key_name]))), null) : null
        is_windows = can(regex("windows", lower(local.elastic_compute_cloud.us_west_2[hostname].ami)))
      }
    },
    {
      for hostname, instance in aws_instance.us_east_1 : hostname => {
        id         = instance.id
        private_ip = instance.private_ip
        key_name   = instance.key_name
        password   = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[hostname].ami))) ? try(sensitive(rsadecrypt(instance.password_data, file(var.ssh_readiness_private_key_paths[instance.key_name]))), null) : null
        is_windows = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[hostname].ami)))
      }
    },
    {
      for hostname, instance in aws_instance.us_east_1_refresh : hostname => {
        id         = instance.id
        private_ip = instance.private_ip
        key_name   = instance.key_name
        password   = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[hostname].ami))) ? try(sensitive(rsadecrypt(instance.password_data, file(var.ssh_readiness_private_key_paths[instance.key_name]))), null) : null
        is_windows = can(regex("windows", lower(local.elastic_compute_cloud.us_east_1[hostname].ami)))
      }
    },
  )
}

# Block `apply` until each instance finishes provisioning and is reachable over SSH, so the Terraform
# step owns and times the full boot + user_data window. The connection retry (10-minute timeout) waits
# for SSH; the OS-native inline command then waits for the launch agent to finish (cloud-init on Linux,
# EC2Launch v2 on Windows) and fails the apply on a non-zero exit. Authenticates with the instance's key
# pair (path supplied by var.ssh_readiness_private_key_paths). On a SEPARATE terraform_data so a gate
# failure taints only this resource, never the EC2 instance.
resource "terraform_data" "ssh_ready" {

  for_each = local.ssh_ready_targets

  triggers_replace = {
    instance_id = each.value.id
  }

  provisioner "remote-exec" {
    connection {
      type            = each.value.is_windows ? "winrm" : "ssh"
      host            = each.value.private_ip
      user            = each.value.is_windows ? "Administrator" : "ec2-user"
      password        = each.value.is_windows ? each.value.password : null
      private_key     = each.value.is_windows ? null : try(file(var.ssh_readiness_private_key_paths[each.value.key_name]), null)
      script_path     = each.value.is_windows ? null : "/tmp/terraform_%RAND%.sh"
      target_platform = each.value.is_windows ? "windows" : "unix"
      port            = each.value.is_windows ? 5985 : null
      https           = each.value.is_windows ? false : null
      use_ntlm        = each.value.is_windows ? true : null
      timeout         = "10m"
    }

    inline = [
      each.value.is_windows ? local.windows_ssh_ready_command : local.linux_ssh_ready_command,
    ]
  }
}

#endregion --- [ SSH Readiness Gate ] --------------------------------------------------------- #

#endregion --- [ Create All Elastic Computer Cloud (EC2s) ] ----------------------------------- #


#region ------ [ Attach All Elastic Block Store (EBS) Volumes ] ------------------------------- #

#region ------ [ Attach All Elastic Block Store (EBS) Volumes - us-west-2 ] ------------- #

resource "aws_volume_attachment" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Itterate through all Elastic Block Storeage (EBS) volumes in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_west_2 : k => v
    if v.refresh == false
  }

  skip_destroy = each.value.delete_on_termination
  instance_id  = aws_instance.us_west_2[each.value.hostname].id
  volume_id    = aws_ebs_volume.us_west_2[each.key].id
  device_name  = each.value.device_name

}

resource "aws_volume_attachment" "us_west_2_refresh" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Itterate through all Elastic Block Storeage (EBS) volumes in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_west_2 : k => v
    if v.refresh == true
  }

  skip_destroy = each.value.delete_on_termination
  instance_id  = aws_instance.us_west_2_refresh[each.value.hostname].id
  volume_id    = aws_ebs_volume.us_west_2_refresh[each.key].id
  device_name  = each.value.device_name

}

#endregion --- [ Attach All Elastic Block Store (EBS) Volumes - us-west-2 ] ------------- #

#region ------ [ Attach All Elastic Block Store (EBS) Volumes - us-east-1 ] ------------- #

resource "aws_volume_attachment" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Itterate through all Elastic Block Storeage (EBS) volumes in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_east_1 : k => v
    if v.refresh == false
  }

  skip_destroy = each.value.delete_on_termination
  instance_id  = aws_instance.us_east_1[each.value.hostname].id
  volume_id    = aws_ebs_volume.us_east_1[each.key].id
  device_name  = each.value.device_name

}

resource "aws_volume_attachment" "us_east_1_refresh" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Itterate through all Elastic Block Storeage (EBS) volumes in the target region.
  for_each = {
    for k, v in local.ebs_block_devices.us_east_1 : k => v
    if v.refresh == true
  }

  skip_destroy = each.value.delete_on_termination
  instance_id  = aws_instance.us_east_1_refresh[each.value.hostname].id
  volume_id    = aws_ebs_volume.us_east_1_refresh[each.key].id
  device_name  = each.value.device_name

}

#endregion --- [ Attach All Elastic Block Store (EBS) Volumes - us-west-2 ] ------------- #

#endregion --- [ Attach All Elastic Block Store (EBS) Volumes ] ------------------------------- #


#region ------ [ Create Relational Database Service (RDS) ] ----------------------------------- #

resource "aws_db_instance" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Itterate through all network interfaces in the target region.
  for_each = local.relational_database_service.us_west_2

  allocated_storage           = each.value.allocated_storage
  availability_zone           = each.value.availability_zone
  backup_retention_period     = each.value.backup_retention_period
  backup_window               = each.value.backup_window
  ca_cert_identifier          = each.value.ca_cert_identifier
  db_name                     = each.value.db_name
  db_subnet_group_name        = each.value.db_subnet_group_name
  dedicated_log_volume        = each.value.dedicated_log_volume
  delete_automated_backups    = each.value.delete_automated_backups
  deletion_protection         = each.value.deletion_protection
  engine                      = each.value.engine
  engine_version              = each.value.engine_version
  final_snapshot_identifier   = each.value.final_snapshot_identifier
  identifier                  = each.value.identifier
  instance_class              = each.value.instance_class
  manage_master_user_password = each.value.manage_master_user_password ? true : null
  max_allocated_storage       = each.value.max_allocated_storage
  password                    = each.value.manage_master_user_password ? null : local.relational_database_service_credentials.us_west_2[each.key].password
  skip_final_snapshot         = each.value.skip_final_snapshot
  storage_encrypted           = true
  storage_type                = each.value.storage_type
  tags                        = each.value.tags
  username                    = local.relational_database_service_credentials.us_west_2[each.key].username
  vpc_security_group_ids      = each.value.vpc_security_group_ids

  kms_key_id = data.aws_kms_alias.us_west_2[each.value.kms_key_id].target_key_arn

  dynamic "blue_green_update" {
    for_each = each.value.blue_green_update ? [each.value.blue_green_update] : []

    content {
      enabled = blue_green_update.value
    }
  }

}


resource "aws_db_instance" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Itterate through all network interfaces in the target region.
  for_each = local.relational_database_service.us_east_1

  allocated_storage           = each.value.allocated_storage
  availability_zone           = each.value.availability_zone
  backup_retention_period     = each.value.backup_retention_period
  backup_window               = each.value.backup_window
  ca_cert_identifier          = each.value.ca_cert_identifier
  db_name                     = each.value.db_name
  db_subnet_group_name        = each.value.db_subnet_group_name
  dedicated_log_volume        = each.value.dedicated_log_volume
  delete_automated_backups    = each.value.delete_automated_backups
  deletion_protection         = each.value.deletion_protection
  engine                      = each.value.engine
  engine_version              = each.value.engine_version
  final_snapshot_identifier   = each.value.final_snapshot_identifier
  identifier                  = each.value.identifier
  instance_class              = each.value.instance_class
  manage_master_user_password = each.value.manage_master_user_password ? true : null
  max_allocated_storage       = each.value.max_allocated_storage
  password                    = each.value.manage_master_user_password ? null : local.relational_database_service_credentials.us_east_1[each.key].password
  skip_final_snapshot         = each.value.skip_final_snapshot
  storage_encrypted           = true
  storage_type                = each.value.storage_type
  tags                        = each.value.tags
  username                    = local.relational_database_service_credentials.us_east_1[each.key].username
  vpc_security_group_ids      = each.value.vpc_security_group_ids

  kms_key_id = data.aws_kms_alias.us_east_1[each.value.kms_key_id].target_key_arn

  dynamic "blue_green_update" {
    for_each = each.value.blue_green_update ? [each.value.blue_green_update] : []

    content {
      enabled = blue_green_update.value
    }
  }

}

#endregion --- [ Create Relational Database Service (RDS) ] ----------------------------------- #


#region ------ [ Configure EC2 Instance State ] ----------------------------------------------- #

resource "aws_ec2_instance_state" "us_west_2" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_west_2

  # Itterate through all EC2 instances in 'us-west-2' where 'set_state' is defined.
  for_each = {
    for hostname, system in aws_instance.us_west_2 : hostname => system
    if local.elastic_compute_cloud["us_west_2"][hostname].set_state != null
  }

  instance_id = each.value.id
  state       = local.elastic_compute_cloud["us_west_2"][each.key].set_state

}

resource "aws_ec2_instance_state" "us_east_1" {

  # Set the provider in which to deploy the instance.
  provider = aws.us_east_1

  # Itterate through all EC2 instances in 'us-east-1' where 'set_state' is defined.
  for_each = {
    for hostname, system in aws_instance.us_east_1 : hostname => system
    if local.elastic_compute_cloud["us_east_1"][hostname].set_state != null
  }

  instance_id = each.value.id
  state       = local.elastic_compute_cloud["us_east_1"][each.key].set_state

}

#endregion --- [ Configure EC2 Instance State ] ----------------------------------------------- #
