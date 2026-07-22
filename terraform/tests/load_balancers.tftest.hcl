mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  environment = "TEST"

  all_load_balancers = [
    {
      region          = "us-east-1"
      resource_key    = "west_alb"
      name            = "west-alb"
      security_groups = ["sg-west"]
      subnets         = ["subnet-west-a", "subnet-west-b"]

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

      subnet_mapping = [
        {
          subnet_id = "subnet-east-a"
        },
        {
          subnet_id = "subnet-east-b"
        }
      ]

      tags = {
        Function = "East NLB"
      }
    }
  ]
}

run "load_balancers_bucket_by_region" {
  command = plan

  assert {
    condition     = contains(keys(local.elastic_load_balancers.us_east_1), "west_alb")
    error_message = "west_alb was not bucketed into us_east_1."
  }

  assert {
    condition     = contains(keys(local.elastic_load_balancers.us_east_1), "east_nlb")
    error_message = "east_nlb was not bucketed into us_east_1."
  }

  assert {
    condition     = local.elastic_load_balancers.us_east_1.west_alb.tags.Environment == "TEST"
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
    condition     = aws_lb.us_east_1["east_nlb"].dns_record_client_routing_policy == "any_availability_zone"
    error_message = "east_nlb should preserve dns_record_client_routing_policy."
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

        network_interfaces = [
          {
            private_ip      = "10.0.0.10"
            security_groups = ["sg-web"]
          }
        ]

        tags = {
          Function = "web"
        }
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

        network_interfaces = [
          {
            private_ip      = "10.0.0.11"
            security_groups = ["sg-web"]
          }
        ]

        tags = {
          Function = "web"
        }
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

        network_interfaces = [
          {
            private_ip      = "10.0.0.12"
            security_groups = ["sg-api"]
          }
        ]

        tags = {
          Function = "api"
        }
      }
    ]

    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "function_alb"
        name            = "function-alb"
        security_groups = ["sg-lb"]
        subnets         = ["subnet-web-a", "subnet-web-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "web"
            vpc_id       = "vpc-test"
            port         = 443
            protocol     = "HTTPS"
          },
          {
            resource_key = "cache"
            function     = "cache"
            vpc_id       = "vpc-test"
            port         = 6379
            protocol     = "TCP"
          }
        ]
      }
    ]
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
    condition     = length([for k, _ in aws_lb_target_group_attachment.us_east_1 : k if startswith(k, "function_alb/web/")]) == 2
    error_message = "Exactly the two Function=web systems should attach to the web target group."
  }

  assert {
    condition     = !contains(keys(aws_lb_target_group_attachment.us_east_1), "function_alb/web/api-a")
    error_message = "The non-matching api system should not attach to the web target group."
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

        network_interfaces = [
          {
            private_ip      = "10.0.0.20"
            security_groups = ["sg-web"]
          }
        ]

        tags = {
          Function = "web"
        }
      }
    ]

    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "routing_alb"
        name            = "routing-alb"
        security_groups = ["sg-lb"]
        subnets         = ["subnet-web-a", "subnet-web-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "web"
            vpc_id       = "vpc-test"
            port         = 8080
            protocol     = "HTTP"
          }
        ]

        listeners = [
          {
            resource_key    = "https"
            port            = 443
            protocol        = "HTTPS"
            ssl_policy      = "ELBSecurityPolicy-2016-08"
            certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/routing-default"
            additional_certificate_arns = [
              "arn:aws:acm:us-east-1:123456789012:certificate/routing-extra",
            ]
            default_action = {
              type             = "forward"
              target_group_key = "web"
            }
            rules = [
              {
                resource_key = "web_path"
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                }
                conditions = [
                  {
                    path_pattern = ["/web/*"]
                  }
                ]
              }
            ]
          },
          {
            resource_key = "http"
            port         = 80
            protocol     = "HTTP"
            default_action = {
              type = "redirect"
              redirect = {
                port        = "443"
                protocol    = "HTTPS"
                status_code = "HTTP_301"
              }
            }
          }
        ]
      }
    ]
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
    condition     = local.lb_listener_certificates.us_east_1["routing_alb/https/arn:aws:acm:us-east-1:123456789012:certificate/routing-extra"].listener_key == "routing_alb/https"
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
    condition     = contains(keys(aws_lb_listener_certificate.us_east_1), "routing_alb/https/arn:aws:acm:us-east-1:123456789012:certificate/routing-extra")
    error_message = "The HTTPS additional listener certificate should be planned with the composite routing_alb/https/<arn> key."
  }

  assert {
    condition     = length(output.aws_target_groups) == 1 && contains(keys(output.aws_target_groups), "routing_alb/web")
    error_message = "The aws_target_groups output should expose the planned target group under the composite routing_alb/web key."
  }

  assert {
    condition     = length(output.aws_target_group_arns) == 1 && contains(keys(output.aws_target_group_arns), "routing_alb/web")
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

        listeners = [
          {
            resource_key = "https"
            port         = 443
            protocol     = "HTTPS"
            default_action = {
              type             = "forward"
              target_group_key = "missing"
            }
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
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_connection_logs_on_network_type" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region             = "us-east-1"
        resource_key       = "network_connection_logs"
        name               = "network-connection-logs"
        load_balancer_type = "network"
        security_groups    = ["sg-network"]
        subnets            = ["subnet-network-a", "subnet-network-b"]

        connection_logs = {
          bucket = "lb-connection-logs"
        }
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_health_check_logs_on_network_type" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region             = "us-east-1"
        resource_key       = "network_health_logs"
        name               = "network-health-logs"
        load_balancer_type = "network"
        security_groups    = ["sg-network"]
        subnets            = ["subnet-network-a", "subnet-network-b"]

        health_check_logs = {
          bucket = "lb-health-check-logs"
        }
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_xff_header_processing_mode_on_network_type" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region                     = "us-east-1"
        resource_key               = "network_xff_mode"
        name                       = "network-xff-mode"
        load_balancer_type         = "network"
        security_groups            = ["sg-network"]
        subnets                    = ["subnet-network-a", "subnet-network-b"]
        xff_header_processing_mode = "append"
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_secondary_ips_on_application_type" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region                                 = "us-east-1"
        resource_key                           = "application_secondary_ips"
        name                                   = "application-secondary-ips"
        load_balancer_type                     = "application"
        security_groups                        = ["sg-application"]
        subnets                                = ["subnet-application-a", "subnet-application-b"]
        secondary_ips_auto_assigned_per_subnet = 1
      }
    ]
  }

  expect_failures = [
    var.all_load_balancers,
  ]
}

run "load_balancer_rejects_security_groups_on_gateway_type" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region             = "us-east-1"
        resource_key       = "gateway_security_groups"
        name               = "gateway-security-groups"
        load_balancer_type = "gateway"
        security_groups    = ["sg-gateway"]
        subnets            = ["subnet-gateway-a", "subnet-gateway-b"]
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
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8080
            protocol     = "HTTP"
          },
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8081
            protocol     = "HTTP"
          }
        ]

        listeners = [
          {
            resource_key = "https"
            port         = 443
            protocol     = "HTTPS"
            default_action = {
              type             = "forward"
              target_group_key = "web"
            }
          }
        ]
      }
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
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8080
            protocol     = "HTTP"
          }
        ]

        listeners = [
          {
            resource_key = "https"
            port         = 443
            protocol     = "HTTPS"
            default_action = {
              type             = "forward"
              target_group_key = "web"
            }
            rules = [
              {
                resource_key = "web_path"
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                }
                conditions = [
                  {
                    path_pattern = ["/web/*"]
                  }
                ]
              },
              {
                resource_key = "admin_path"
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                }
                conditions = [
                  {
                    path_pattern = ["/admin/*"]
                  }
                ]
              }
            ]
          }
        ]
      }
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
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8080
            protocol     = "HTTP"
          }
        ]

        listeners = [
          {
            resource_key = "https"
            port         = 443
            protocol     = "HTTPS"
            default_action = {
              type             = "forward"
              target_group_key = "web"
              redirect = {
                status_code = "HTTP_301"
              }
            }
          }
        ]
      }
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
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8080
            protocol     = "HTTP"
          }
        ]

        listeners = [
          {
            resource_key = "https"
            port         = 443
            protocol     = "HTTPS"
            default_action = {
              type             = "forward"
              target_group_key = "web"
            }
            rules = [
              {
                resource_key = "web_host_path"
                priority     = 10
                action = {
                  type             = "forward"
                  target_group_key = "web"
                }
                conditions = [
                  {
                    host_header  = ["app.example.com"]
                    path_pattern = ["/web/*"]
                  }
                ]
              }
            ]
          }
        ]
      }
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

        target_groups = [
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8080
            protocol     = "HTTP"
            target_type  = "ip"
          }
        ]

        listeners = [
          {
            resource_key = "https"
            port         = 443
            protocol     = "HTTPS"
            default_action = {
              type             = "forward"
              target_group_key = "web"
            }
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
      {
        region          = "us-east-1"
        resource_key    = "schema_alb"
        name            = "schema-alb"
        security_groups = ["sg-schema"]
        subnets         = ["subnet-schema-a", "subnet-schema-b"]

        target_groups = [
          {
            resource_key = "web"
            function     = "Jenkins Server"
            vpc_id       = "vpc-schema"
            port         = 8080
            protocol     = "HTTP"
          }
        ]

        listeners = [
          {
            resource_key    = "https"
            port            = 443
            protocol        = "HTTPS"
            certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/schema"
            default_action = {
              type             = "forward"
              target_group_key = "web"
            }
          },
          {
            resource_key = "http"
            port         = 80
            protocol     = "HTTP"
            default_action = {
              type = "redirect"
              redirect = {
                port        = "443"
                protocol    = "HTTPS"
                status_code = "HTTP_301"
              }
            }
          }
        ]
      }
    ]
  }
}
