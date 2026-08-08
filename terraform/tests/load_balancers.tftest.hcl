mock_provider "aws" {
  alias = "us_east_1"

  # The ENI preconditions read the real subnet, so the mock has to return something coherent:
  # a CIDR wide enough to contain every fixture address (10.0-10.2) and the zone the fixtures
  # declare. Individual runs override this where they need a different subnet.
  mock_data "aws_subnet" {
    defaults = {
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
      vpc_id            = "vpc-test"
    }
  }
}

variables {
  repository    = "nwarila-platform/aws-terraform-framework"
  repository_id = "123456789"
  commit_sha    = "0123456789abcdef0123456789abcdef01234567"
  run_id        = "42"
  environment   = "test"

  all_load_balancers = [
    {
      region          = "us-east-1"
      resource_key    = "west_alb"
      name            = "west-alb"
      security_groups = ["sg-west"]
      subnets         = ["subnet-west-a", "subnet-west-b"]

      access_logs                                                  = null
      client_keep_alive                                            = null
      connection_logs                                              = null
      customer_owned_ipv4_pool                                     = null
      desync_mitigation_mode                                       = null
      dns_record_client_routing_policy                             = null
      drop_invalid_header_fields                                   = null
      enable_cross_zone_load_balancing                             = null
      enable_deletion_protection                                   = true
      enable_http2                                                 = null
      enable_tls_version_and_cipher_suite_headers                  = null
      enable_waf_fail_open                                         = null
      enable_xff_client_port                                       = null
      enable_zonal_shift                                           = null
      enforce_security_group_inbound_rules_on_private_link_traffic = null
      health_check_logs                                            = null
      idle_timeout                                                 = null
      internal                                                     = true
      ip_address_type                                              = "ipv4"
      ipam_pools                                                   = null
      load_balancer_type                                           = "application"
      minimum_load_balancer_capacity                               = null
      name_prefix                                                  = null
      preserve_host_header                                         = null
      secondary_ips_auto_assigned_per_subnet                       = null
      subnet_mapping                                               = []
      target_groups                                                = []
      listeners                                                    = []
      timeouts                                                     = null
      xff_header_processing_mode                                   = null

      tags = {
        Function = "West ALB"
      }
    },
    {
      region                           = "us_east_1"
      resource_key                     = "east_nlb"
      name                             = "east-nlb"
      dns_record_client_routing_policy = "any_availability_zone"
      load_balancer_type               = "network"
      security_groups                  = ["sg-east"]

      access_logs                                                  = null
      client_keep_alive                                            = null
      connection_logs                                              = null
      customer_owned_ipv4_pool                                     = null
      desync_mitigation_mode                                       = null
      drop_invalid_header_fields                                   = null
      enable_cross_zone_load_balancing                             = null
      enable_deletion_protection                                   = true
      enable_http2                                                 = null
      enable_tls_version_and_cipher_suite_headers                  = null
      enable_waf_fail_open                                         = null
      enable_xff_client_port                                       = null
      enable_zonal_shift                                           = null
      enforce_security_group_inbound_rules_on_private_link_traffic = null
      health_check_logs                                            = null
      idle_timeout                                                 = null
      internal                                                     = true
      ip_address_type                                              = "ipv4"
      ipam_pools                                                   = null
      minimum_load_balancer_capacity                               = null
      name_prefix                                                  = null
      preserve_host_header                                         = null
      secondary_ips_auto_assigned_per_subnet                       = null
      subnets                                                      = []
      target_groups                                                = []
      listeners                                                    = []
      timeouts                                                     = null
      xff_header_processing_mode                                   = null

      subnet_mapping = [
        {
          allocation_id        = null
          ipv6_address         = null
          private_ipv4_address = null
          subnet_id            = "subnet-east-a"
        },
        {
          allocation_id        = null
          ipv6_address         = null
          private_ipv4_address = null
          subnet_id            = "subnet-east-b"
        }
      ]

      tags = {
        Function = "East NLB"
      }
    },
    {
      region          = "us-east-1"
      resource_key    = "schema_alb"
      name            = "schema-alb"
      security_groups = ["sg-schema"]
      subnets         = ["subnet-schema-a", "subnet-schema-b"]

      access_logs                                                  = null
      client_keep_alive                                            = null
      connection_logs                                              = null
      customer_owned_ipv4_pool                                     = null
      desync_mitigation_mode                                       = null
      dns_record_client_routing_policy                             = null
      drop_invalid_header_fields                                   = null
      enable_cross_zone_load_balancing                             = null
      enable_deletion_protection                                   = true
      enable_http2                                                 = null
      enable_tls_version_and_cipher_suite_headers                  = null
      enable_waf_fail_open                                         = null
      enable_xff_client_port                                       = null
      enable_zonal_shift                                           = null
      enforce_security_group_inbound_rules_on_private_link_traffic = null
      health_check_logs                                            = null
      idle_timeout                                                 = null
      internal                                                     = true
      ip_address_type                                              = "ipv4"
      ipam_pools                                                   = null
      load_balancer_type                                           = "application"
      minimum_load_balancer_capacity                               = null
      name_prefix                                                  = null
      preserve_host_header                                         = null
      secondary_ips_auto_assigned_per_subnet                       = null
      subnet_mapping                                               = []
      tags                                                         = {}
      timeouts                                                     = null
      xff_header_processing_mode                                   = null

      target_groups = [
        {
          resource_key                      = "web"
          function                          = "Jenkins Server"
          vpc_id                            = "vpc-schema"
          port                              = 8080
          protocol                          = "HTTP"
          protocol_version                  = null
          target_type                       = "instance"
          deregistration_delay              = null
          slow_start                        = null
          load_balancing_algorithm_type     = null
          load_balancing_anomaly_mitigation = null
          load_balancing_cross_zone_enabled = null
          preserve_client_ip                = null
          proxy_protocol_v2                 = null
          connection_termination            = null
          ip_address_type                   = null
          health_check                      = null
          stickiness                        = null
          tags                              = {}
        }
      ]

      listeners = [
        {
          resource_key                = "https"
          port                        = 443
          protocol                    = "HTTPS"
          ssl_policy                  = null
          alpn_policy                 = null
          certificate_arn             = null
          additional_certificate_arns = []
          default_action = {
            type             = "forward"
            target_group_key = "web"
            redirect         = null
            fixed_response   = null
          }
          rules = []
        }
      ]
    }
  ]
}

# subnet-web-b lives in the second zone; the provider mock answers us-east-1a for every other
# subnet.
override_data {
  target = data.aws_subnet.us_east_1["subnet-web-b"]
  values = {
    cidr_block        = "10.0.0.0/8"
    availability_zone = "us-east-1b"
    vpc_id            = "vpc-test"
  }
}

run "load_balancers_bucket_by_region" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        enforce_security_group_inbound_rules_on_private_link_traffic = (
          load_balancer.resource_key == "east_nlb" ? "off" : null
        )
      })
      if load_balancer.resource_key != "schema_alb"
    ]
  }

  assert {
    condition     = contains(keys(local.elastic_load_balancers.us_east_1), "west_alb")
    error_message = "west_alb was not bucketed into us_east_1."
  }

  assert {
    condition     = contains(keys(local.elastic_load_balancers.us_east_1), "east_nlb")
    error_message = "east_nlb was not bucketed into us_east_1."
  }

  assert {
    condition     = local.elastic_load_balancers.us_east_1.west_alb.tags.Environment == "test"
    error_message = "west_alb did not inherit the environment tag."
  }

  assert {
    condition     = local.elastic_load_balancers.us_east_1.west_alb.subnets != null
    error_message = "west_alb subnets should be preserved."
  }

  assert {
    condition     = local.elastic_load_balancers.us_east_1.east_nlb.subnets == null
    error_message = "east_nlb subnets should normalize to null when subnet_mapping is used."
  }

  assert {
    condition     = aws_lb.us_east_1["west_alb"].load_balancer_type == "application"
    error_message = "west_alb should plan as an application load balancer."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_lb.us_east_1["west_alb"].tags[key] == {
        Name         = "west-alb"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "42"
      }[key]
    ])
    error_message = "Load balancer tags must carry all seven deployment-identity keys verbatim."
  }

  assert {
    condition     = aws_lb.us_east_1["east_nlb"].dns_record_client_routing_policy == "any_availability_zone"
    error_message = "east_nlb should preserve dns_record_client_routing_policy."
  }

  assert {
    condition = (
      aws_lb.us_east_1["east_nlb"]
      .enforce_security_group_inbound_rules_on_private_link_traffic == "on"
    )
    error_message = "Network load balancers must enforce inbound rules for PrivateLink traffic."
  }

  assert {
    condition     = length(local.lb_target_groups.us_east_1) == 0
    error_message = "Load balancers without target_groups should not emit target groups."
  }

  assert {
    condition     = length(local.lb_target_group_attachments.us_east_1) == 0
    error_message = "Load balancers without target_groups should not emit target group attachments."
  }

  assert {
    condition     = length(local.lb_listeners.us_east_1) == 0
    error_message = "Load balancers without listeners should not emit listeners."
  }

  assert {
    condition     = length(local.lb_listener_rules.us_east_1) == 0
    error_message = "Load balancers without listener rules should not emit listener rules."
  }

  assert {
    condition     = length(local.lb_listener_certificates.us_east_1) == 0
    error_message = "Load balancers without additional listener certificates should not emit listener certificates."
  }
}

run "load_balancer_target_groups_attach_matching_function_systems" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "web-a"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-web-a"
        key_name             = "test-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "ebs"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.10"
            security_groups = ["sg-44444444"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]

        tags = {
          Function = "web"
          Backup   = true
        }

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        ebs_block_devices   = []
        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "web-refresh"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-web-b"
        key_name             = "test-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "ebs"
        ami                  = "test-linux"
        refresh              = true

        instance_type = "m6i.large"

        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.11"
            security_groups = ["sg-44444444"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]

        tags = {
          Function = "web"
          Backup   = true
        }

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        ebs_block_devices   = []
        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "api-a"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-api-a"
        key_name             = "test-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "ebs"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.12"
            security_groups = ["sg-55555555"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]

        tags = {
          Function = "web"
          Backup   = true
        }

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        ebs_block_devices   = []
        associate_public_ip = false
      }
    ]

    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "function_alb"
        name            = "function-alb"
        security_groups = ["sg-lb"]
        subnets         = ["subnet-web-a", "subnet-web-b"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        listeners                                                    = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null

        target_groups = [
          {
            resource_key                      = "web"
            function                          = "web"
            vpc_id                            = "vpc-test"
            port                              = 443
            protocol                          = "HTTPS"
            protocol_version                  = null
            target_type                       = "instance"
            deregistration_delay              = null
            slow_start                        = null
            load_balancing_algorithm_type     = null
            load_balancing_anomaly_mitigation = null
            load_balancing_cross_zone_enabled = null
            preserve_client_ip                = null
            proxy_protocol_v2                 = null
            connection_termination            = null
            ip_address_type                   = null
            health_check                      = null
            stickiness                        = null
            tags                              = {}
          },
          {
            resource_key                      = "cache"
            function                          = "cache"
            vpc_id                            = "vpc-test"
            port                              = 6379
            protocol                          = "TCP"
            protocol_version                  = null
            target_type                       = "instance"
            deregistration_delay              = null
            slow_start                        = null
            load_balancing_algorithm_type     = null
            load_balancing_anomaly_mitigation = null
            load_balancing_cross_zone_enabled = null
            preserve_client_ip                = null
            proxy_protocol_v2                 = null
            connection_termination            = null
            ip_address_type                   = null
            health_check                      = null
            stickiness                        = null
            tags                              = {}
          }
        ]
      }
    ]
  }

  override_data {
    target = data.aws_subnet.us_east_1["subnet-api-a"]
    values = {
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
      vpc_id            = "vpc-other"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["api-a"]
    override_during = plan
    values = {
      id = "i-11111111111111111"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["web-a"]
    override_during = plan
    values = {
      id = "i-22222222222222222"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1_refresh["web-refresh"]
    override_during = plan
    values = {
      id = "i-33333333333333333"
    }
  }

  override_resource {
    target          = aws_lb_target_group.us_east_1["function_alb/cache"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/cache/1111111111111111"
    }
  }

  override_resource {
    target          = aws_lb_target_group.us_east_1["function_alb/web"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/2222222222222222"
    }
  }

  assert {
    condition     = contains(keys(aws_lb_target_group.us_east_1), "function_alb/web")
    error_message = "The web target group should be planned with the composite function_alb/web key."
  }

  assert {
    condition     = aws_lb_target_group.us_east_1["function_alb/web"].port == 443
    error_message = "The web target group should preserve its configured target port."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_lb_target_group.us_east_1["function_alb/web"].tags[key] == {
        Name         = "function_alb/web"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "42"
      }[key]
    ])
    error_message = "Target group tags must carry all seven deployment-identity keys verbatim."
  }

  assert {
    condition     = contains(keys(aws_lb_target_group.us_east_1), "function_alb/cache")
    error_message = "The zero-match cache target group should still be planned."
  }

  assert {
    condition     = contains(keys(aws_lb_target_group_attachment.us_east_1), "function_alb/web/web-a")
    error_message = "The normal web instance should attach to the web target group."
  }

  assert {
    condition     = contains(keys(aws_lb_target_group_attachment.us_east_1), "function_alb/web/web-refresh")
    error_message = "The refresh web instance should attach to the web target group."
  }

  assert {
    condition = (
      aws_lb_target_group_attachment.us_east_1["function_alb/web/web-a"].target_id ==
      "i-22222222222222222"
    )
    error_message = "The web-a attachment should use the web-a instance ID."
  }

  assert {
    condition = (
      aws_lb_target_group_attachment.us_east_1["function_alb/web/web-a"].target_group_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/2222222222222222"
    )
    error_message = "The web-a attachment should use the web target group ARN."
  }

  assert {
    condition = (
      aws_lb_target_group_attachment.us_east_1["function_alb/web/web-refresh"].target_id ==
      "i-33333333333333333"
    )
    error_message = "The web-refresh attachment should use the refresh instance ID."
  }

  assert {
    condition = (
      aws_lb_target_group_attachment.us_east_1["function_alb/web/web-refresh"].target_group_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/2222222222222222"
    )
    error_message = "The web-refresh attachment should use the web target group ARN."
  }

  assert {
    condition     = length([for k, _ in aws_lb_target_group_attachment.us_east_1 : k if startswith(k, "function_alb/web/")]) == 2
    error_message = "Only the two Function=web systems in the target group's VPC should attach."
  }

  assert {
    condition     = !contains(keys(aws_lb_target_group_attachment.us_east_1), "function_alb/web/api-a")
    error_message = "A Function=web system in another VPC should not attach to the web target group."
  }

  assert {
    condition     = length([for k, _ in aws_lb_target_group_attachment.us_east_1 : k if startswith(k, "function_alb/cache/")]) == 0
    error_message = "A target group with no matching Function should produce zero attachments."
  }
}

run "load_balancer_listeners_rules_and_certificates_wire_to_target_groups" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "web-listener"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-web-a"
        key_name             = "test-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "ebs"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.20"
            security_groups = ["sg-44444444"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]

        tags = {
          Function = "web"
          Backup   = true
        }

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        ebs_block_devices   = []
        associate_public_ip = false
      }
    ]

    all_load_balancers = [
      var.all_load_balancers[1],
      {
        region          = "us-east-1"
        resource_key    = "routing_alb"
        name            = "routing-alb"
        security_groups = ["sg-lb"]
        subnets         = ["subnet-web-a", "subnet-web-b"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null

        target_groups = [
          merge(var.all_load_balancers[2].target_groups[0], {
            resource_key = "unused"
            function     = "unused"
            vpc_id       = "vpc-test"
            port         = 9090
          }),
          {
            resource_key                      = "web"
            function                          = "web"
            vpc_id                            = "vpc-test"
            port                              = 8080
            protocol                          = "HTTP"
            protocol_version                  = null
            target_type                       = "instance"
            deregistration_delay              = null
            slow_start                        = null
            load_balancing_algorithm_type     = null
            load_balancing_anomaly_mitigation = null
            load_balancing_cross_zone_enabled = null
            preserve_client_ip                = null
            proxy_protocol_v2                 = null
            connection_termination            = null
            ip_address_type                   = null
            health_check                      = null
            stickiness                        = null
            tags                              = {}
          }
        ]

        listeners = [
          {
            resource_key    = "https"
            port            = 443
            protocol        = "HTTPS"
            ssl_policy      = "ELBSecurityPolicy-2016-08"
            alpn_policy     = null
            certificate_arn = "arn:aws:acm:us-east-1:${join("", ["123456", "789012"])}:certificate/routing-default"
            additional_certificate_arns = [
              "arn:aws:acm:us-east-1:${join("", ["123456", "789012"])}:certificate/routing-extra",
            ]
            default_action = {
              type             = "forward"
              target_group_key = "web"
              redirect         = null
              fixed_response   = null
            }
            rules = [
              {
                resource_key = "web_path"
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                  redirect         = null
                  fixed_response   = null
                }
                conditions = [
                  {
                    host_header         = null
                    path_pattern        = ["/web/*"]
                    http_request_method = null
                    source_ip           = null
                    http_header         = null
                    query_string        = null
                  }
                ]
              }
            ]
          },
          {
            resource_key                = "http"
            port                        = 80
            protocol                    = "HTTP"
            ssl_policy                  = null
            alpn_policy                 = null
            certificate_arn             = null
            additional_certificate_arns = []
            default_action = {
              type             = "redirect"
              target_group_key = null
              redirect = {
                host        = null
                path        = null
                port        = "443"
                protocol    = "HTTPS"
                query       = null
                status_code = "HTTP_301"
              }
              fixed_response = null
            }
            rules = []
          }
        ]
      }
    ]
  }

  override_resource {
    target          = aws_lb.us_east_1["east_nlb"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/east-nlb/1111111111111111"
    }
  }

  override_resource {
    target          = aws_lb.us_east_1["routing_alb"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/routing-alb/2222222222222222"
    }
  }

  override_resource {
    target          = aws_lb_target_group.us_east_1["routing_alb/unused"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/unused/3333333333333333"
    }
  }

  override_resource {
    target          = aws_lb_target_group.us_east_1["routing_alb/web"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/4444444444444444"
    }
  }

  override_resource {
    target          = aws_lb_listener.us_east_1["routing_alb/http"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/routing-alb/2222222222222222/5555555555555555"
    }
  }

  override_resource {
    target          = aws_lb_listener.us_east_1["routing_alb/https"]
    override_during = plan
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/routing-alb/2222222222222222/6666666666666666"
    }
  }

  assert {
    condition     = local.lb_listeners.us_east_1["routing_alb/https"].default_action.target_group_key == "routing_alb/web"
    error_message = "The HTTPS listener default forward action should resolve to the composite routing_alb/web target group key."
  }

  assert {
    condition     = local.lb_listeners.us_east_1["routing_alb/http"].default_action.target_group_key == null
    error_message = "The HTTP redirect listener should not resolve a target group key."
  }

  assert {
    condition     = local.lb_listener_rules.us_east_1["routing_alb/https/web_path"].listener_key == "routing_alb/https"
    error_message = "The listener rule should resolve to the composite routing_alb/https listener key."
  }

  assert {
    condition     = local.lb_listener_rules.us_east_1["routing_alb/https/web_path"].action.target_group_key == "routing_alb/web"
    error_message = "The listener rule forward action should resolve to the composite routing_alb/web target group key."
  }

  assert {
    condition     = local.lb_listener_certificates.us_east_1["routing_alb/https/arn:aws:acm:us-east-1:${join("", ["123456", "789012"])}:certificate/routing-extra"].listener_key == "routing_alb/https"
    error_message = "The additional certificate should carry the explicit composite listener key instead of parsing it from the map key."
  }

  assert {
    condition     = contains(keys(aws_lb_listener.us_east_1), "routing_alb/https")
    error_message = "The HTTPS listener should be planned with the composite routing_alb/https key."
  }

  assert {
    condition     = contains(keys(aws_lb_listener.us_east_1), "routing_alb/http")
    error_message = "The HTTP redirect listener should be planned with the composite routing_alb/http key."
  }

  assert {
    condition     = contains(keys(aws_lb_listener_rule.us_east_1), "routing_alb/https/web_path")
    error_message = "The HTTPS path listener rule should be planned with the composite routing_alb/https/web_path key."
  }

  assert {
    condition     = contains(keys(aws_lb_listener_certificate.us_east_1), "routing_alb/https/arn:aws:acm:us-east-1:${join("", ["123456", "789012"])}:certificate/routing-extra")
    error_message = "The HTTPS additional listener certificate should be planned with the composite routing_alb/https/<arn> key."
  }

  assert {
    condition = (
      aws_lb_listener.us_east_1["routing_alb/http"].load_balancer_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/routing-alb/2222222222222222"
    )
    error_message = "The HTTP listener should use the routing load balancer ARN."
  }

  assert {
    condition = (
      aws_lb_listener.us_east_1["routing_alb/https"].load_balancer_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/routing-alb/2222222222222222"
    )
    error_message = "The HTTPS listener should use the routing load balancer ARN."
  }

  assert {
    condition = (
      aws_lb_listener.us_east_1["routing_alb/https"].default_action[0].target_group_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/4444444444444444"
    )
    error_message = "The HTTPS listener default action should use the web target group ARN."
  }

  assert {
    condition = (
      aws_lb_listener_rule.us_east_1["routing_alb/https/web_path"].listener_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/routing-alb/2222222222222222/6666666666666666"
    )
    error_message = "The HTTPS path rule should use the HTTPS listener ARN."
  }

  assert {
    condition = (
      aws_lb_listener_rule.us_east_1["routing_alb/https/web_path"].action[0].target_group_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web/4444444444444444"
    )
    error_message = "The HTTPS path rule action should use the web target group ARN."
  }

  assert {
    condition = (
      aws_lb_listener_certificate.us_east_1["routing_alb/https/arn:aws:acm:us-east-1:${join("", ["123456", "789012"])}:certificate/routing-extra"].listener_arn ==
      "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/routing-alb/2222222222222222/6666666666666666"
    )
    error_message = "The additional certificate should use the HTTPS listener ARN."
  }

  assert {
    condition     = length(output.aws_target_groups) == 2 && contains(keys(output.aws_target_groups), "routing_alb/web")
    error_message = "The aws_target_groups output should expose the planned target group under the composite routing_alb/web key."
  }

  assert {
    condition     = length(output.aws_target_group_arns) == 2 && contains(keys(output.aws_target_group_arns), "routing_alb/web")
    error_message = "The aws_target_group_arns output should expose the planned target group ARN under the composite routing_alb/web key."
  }

  assert {
    condition     = length(output.aws_listeners) == 2 && contains(keys(output.aws_listeners), "routing_alb/http") && contains(keys(output.aws_listeners), "routing_alb/https")
    error_message = "The aws_listeners output should expose the planned listeners under their composite keys."
  }

  assert {
    condition     = length(output.aws_listener_arns) == 2 && contains(keys(output.aws_listener_arns), "routing_alb/http") && contains(keys(output.aws_listener_arns), "routing_alb/https")
    error_message = "The aws_listener_arns output should expose the planned listener ARNs under their composite keys."
  }
}

run "load_balancer_rejects_missing_default_target_group_key_reference" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        target_groups                                                = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null

        listeners = [
          {
            resource_key                = "https"
            port                        = 443
            protocol                    = "HTTPS"
            ssl_policy                  = null
            alpn_policy                 = null
            certificate_arn             = null
            additional_certificate_arns = []
            default_action = {
              type             = "forward"
              target_group_key = "missing"
              redirect         = null
              fixed_response   = null
            }
            rules = []
          }
        ]
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_public_internal_false" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "public_alb"
        name            = "public-alb"
        internal        = false
        security_groups = ["sg-public"]
        subnets         = ["subnet-public-a", "subnet-public-b"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        target_groups                                                = []
        listeners                                                    = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_empty_security_groups" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region             = "us-east-1"
        resource_key       = "empty_sg_alb"
        name               = "empty-sg-alb"
        load_balancer_type = "application"
        security_groups    = []
        subnets            = ["subnet-empty-a", "subnet-empty-b"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        target_groups                                                = []
        listeners                                                    = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_duplicate_target_group_resource_keys" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        target_groups = concat(load_balancer.target_groups, [
          merge(load_balancer.target_groups[0], {
            port = 8081
          })
        ])
      })
      if load_balancer.resource_key == "schema_alb"
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_duplicate_rule_priorities" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          merge(load_balancer.listeners[0], {
            rules = [
              for rule in [
                {
                  resource_key = "web_path"
                  path_pattern = "/web/*"
                },
                {
                  resource_key = "admin_path"
                  path_pattern = "/admin/*"
                }
                ] : {
                resource_key = rule.resource_key
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                  redirect         = null
                  fixed_response   = null
                }
                conditions = [
                  {
                    host_header         = null
                    path_pattern        = [rule.path_pattern]
                    http_request_method = null
                    source_ip           = null
                    http_header         = null
                    query_string        = null
                  }
                ]
              }
            ]
          })
        ]
      })
      if load_balancer.resource_key == "schema_alb"
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_forward_action_with_redirect_payload" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          merge(load_balancer.listeners[0], {
            default_action = merge(load_balancer.listeners[0].default_action, {
              redirect = {
                host        = null
                path        = null
                port        = null
                protocol    = null
                query       = null
                status_code = "HTTP_301"
              }
            })
          })
        ]
      })
      if load_balancer.resource_key == "schema_alb"
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_condition_with_two_types" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          merge(load_balancer.listeners[0], {
            rules = [
              {
                resource_key = "web_host_path"
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                  redirect         = null
                  fixed_response   = null
                }
                conditions = [
                  {
                    host_header         = ["app.example.com"]
                    path_pattern        = ["/web/*"]
                    http_request_method = null
                    source_ip           = null
                    http_header         = null
                    query_string        = null
                  }
                ]
              }
            ]
          })
        ]
      })
      if load_balancer.resource_key == "schema_alb"
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_non_instance_target_type" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null

        target_groups = [
          {
            resource_key                      = "web"
            function                          = "Jenkins Server"
            vpc_id                            = "vpc-schema"
            port                              = 8080
            protocol                          = "HTTP"
            target_type                       = "ip"
            protocol_version                  = null
            deregistration_delay              = null
            slow_start                        = null
            load_balancing_algorithm_type     = null
            load_balancing_anomaly_mitigation = null
            load_balancing_cross_zone_enabled = null
            preserve_client_ip                = null
            proxy_protocol_v2                 = null
            connection_termination            = null
            ip_address_type                   = null
            health_check                      = null
            stickiness                        = null
            tags                              = {}
          }
        ]

        listeners = [
          {
            resource_key                = "https"
            port                        = 443
            protocol                    = "HTTPS"
            ssl_policy                  = null
            alpn_policy                 = null
            certificate_arn             = null
            additional_certificate_arns = []
            default_action = {
              type             = "forward"
              target_group_key = "web"
              redirect         = null
              fixed_response   = null
            }
            rules = []
          }
        ]
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_accepts_fully_wired_nested_routing_schema" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = concat([
          merge(load_balancer.listeners[0], {
            certificate_arn = "arn:aws:acm:us-east-1:${join("", ["123456", "789012"])}:certificate/schema"
          })
          ], [
          {
            resource_key                = "http"
            port                        = 80
            protocol                    = "HTTP"
            ssl_policy                  = null
            alpn_policy                 = null
            certificate_arn             = null
            additional_certificate_arns = []
            default_action = {
              type             = "redirect"
              target_group_key = null
              redirect = {
                host        = null
                path        = null
                port        = "443"
                protocol    = "HTTPS"
                query       = null
                status_code = "HTTP_301"
              }
              fixed_response = null
            }
            rules = []
          }
        ])
      })
      if load_balancer.resource_key == "schema_alb"
    ]
  }

  assert {
    condition     = aws_lb_listener.us_east_1["schema_alb/https"].default_action[0].type == "forward"
    error_message = "The HTTPS listener should forward to its configured target group."
  }

  assert {
    condition = (
      aws_lb_listener.us_east_1["schema_alb/http"].default_action[0].redirect[0].status_code == "HTTP_301" &&
      aws_lb_listener.us_east_1["schema_alb/http"].default_action[0].redirect[0].port == "443"
    )
    error_message = "The HTTP listener should redirect permanently to HTTPS on port 443."
  }

  assert {
    condition = (
      length(aws_lb_target_group.us_east_1) == 1 &&
      contains(keys(aws_lb_target_group.us_east_1), "schema_alb/web")
    )
    error_message = "The schema ALB should plan exactly its configured web target group."
  }
}

run "all_load_balancers_rejects_null_target_groups" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "null_target_groups"
        name            = "null-target-groups"
        security_groups = ["sg-test"]
        subnets         = ["subnet-test"]

        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        target_groups                                                = null
        listeners                                                    = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null
      }
    ]
  }

  expect_failures = [var.all_load_balancers]
}
