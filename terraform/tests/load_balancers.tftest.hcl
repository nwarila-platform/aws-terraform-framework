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
