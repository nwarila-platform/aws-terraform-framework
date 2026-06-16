mock_provider "aws" {
  alias = "us_west_2"
}

mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  environment = "TEST"

  all_load_balancers = [
    {
      region          = "us-west-2"
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
    condition     = contains(keys(local.elastic_load_balancers.us_west_2), "west_alb")
    error_message = "west_alb was not bucketed into us_west_2."
  }

  assert {
    condition     = !contains(keys(local.elastic_load_balancers.us_east_1), "west_alb")
    error_message = "west_alb was also bucketed into us_east_1."
  }

  assert {
    condition     = contains(keys(local.elastic_load_balancers.us_east_1), "east_nlb")
    error_message = "east_nlb was not bucketed into us_east_1."
  }

  assert {
    condition     = local.elastic_load_balancers.us_west_2.west_alb.tags.Environment == "TEST"
    error_message = "west_alb did not inherit the environment tag."
  }

  assert {
    condition     = local.elastic_load_balancers.us_west_2.west_alb.subnets != null
    error_message = "west_alb subnets should be preserved."
  }

  assert {
    condition     = local.elastic_load_balancers.us_east_1.east_nlb.subnets == null
    error_message = "east_nlb subnets should normalize to null when subnet_mapping is used."
  }

  assert {
    condition     = aws_lb.us_west_2["west_alb"].load_balancer_type == "application"
    error_message = "west_alb should plan as an application load balancer."
  }

  assert {
    condition     = aws_lb.us_east_1["east_nlb"].dns_record_client_routing_policy == "any_availability_zone"
    error_message = "east_nlb should preserve dns_record_client_routing_policy."
  }
}

run "load_balancer_rejects_missing_default_target_group_key_reference" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region          = "us-west-2"
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

run "load_balancer_rejects_duplicate_target_group_resource_keys" {
  command = plan

  variables {
    all_load_balancers = [
      {
        region          = "us-west-2"
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
        region          = "us-west-2"
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
        region          = "us-west-2"
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
        region          = "us-west-2"
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
        region          = "us-west-2"
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
        region          = "us-west-2"
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
            certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/schema"
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
