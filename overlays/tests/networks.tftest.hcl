mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  environment = "TEST"

  networks = {
    "poc-net" = {
      availability_zone = "us-east-1a"
      vpc_cidr          = "10.20.0.0/24"
      subnet_cidr       = "10.20.0.0/28"
      tags              = {}
    }
  }
}

run "empty_map_is_the_zero_resource_anchor" {
  command = plan

  variables {
    networks = {}
  }

  assert {
    condition = alltrue([
      length(aws_vpc.us_east_1) == 0,
      length(aws_internet_gateway.us_east_1) == 0,
      length(aws_subnet.us_east_1) == 0,
      length(aws_route_table.us_east_1) == 0,
      length(aws_route.us_east_1_default) == 0,
      length(aws_route_table_association.us_east_1) == 0,
    ])
    error_message = "An empty networks map must create zero resources in all six collections."
  }
}

run "public_network_creates_vpc_subnet_igw_route_and_association" {
  command = apply

  assert {
    condition = alltrue([
      aws_vpc.us_east_1["poc-net"].cidr_block == "10.20.0.0/24",
      aws_subnet.us_east_1["poc-net"].cidr_block == "10.20.0.0/28",
      aws_subnet.us_east_1["poc-net"].availability_zone == "us-east-1a",
      aws_subnet.us_east_1["poc-net"].map_public_ip_on_launch == false,
      contains(keys(aws_internet_gateway.us_east_1), "poc-net"),
      contains(keys(aws_route_table.us_east_1), "poc-net"),
      aws_route.us_east_1_default["poc-net"].destination_cidr_block == "0.0.0.0/0",
      contains(keys(aws_route_table_association.us_east_1), "poc-net"),
    ])
    error_message = "A network entry must create its VPC, subnet, gateway, route table, default route, and association."
  }
}

run "output_matches_the_framework_alias_contract" {
  command = apply

  assert {
    condition     = toset(keys(output.network_aliases["poc-net"])) == toset(["availability_zone", "subnet_cidr", "subnet_id", "vpc_id"])
    error_message = "The alias output must expose exactly the four framework contract fields."
  }

  assert {
    condition = alltrue([
      output.network_aliases["poc-net"].subnet_cidr == "10.20.0.0/28",
      output.network_aliases["poc-net"].availability_zone == "us-east-1a",
      output.network_aliases["poc-net"].vpc_id != null,
    ])
    error_message = "Alias metadata must echo the inputs and always include a non-null VPC id."
  }
}

run "deployment_tags_match_the_framework_contract" {
  command = apply

  variables {
    environment = "poc"
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "1"
      stack         = "ci"
      owner         = "platform"
      commit_sha    = "0123456789abcdef0123456789abcdef01234567"
      run_id        = "123"
    }
  }

  assert {
    condition = alltrue([
      toset(keys(output.deployment_tags)) == toset([
        "nwarila:management:environment",
        "nwarila:management:managed-by",
        "nwarila:management:repository",
        "nwarila:management:repository-id",
        "nwarila:management:stack",
        "nwarila:operations:owner",
        "nwarila:provenance:commit-sha",
        "nwarila:provenance:run-id",
      ]),
      output.deployment_tags["nwarila:management:repository-id"] == "1",
      output.deployment_tags["nwarila:management:stack"] == "ci",
      output.deployment_tags["nwarila:management:environment"] == "poc",
    ])
    error_message = "The overlays deployment-tag contract must match the framework key set and values."
  }
}

run "framework_tags_are_merged_over_consumer_tags" {
  command = apply

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        tags = {
          Name     = "consumer-cannot-override"
          Workload = "test"
        }
      }
    }
  }

  assert {
    condition     = aws_vpc.us_east_1["poc-net"].tags["Name"] == "poc-net" && aws_vpc.us_east_1["poc-net"].tags["Workload"] == "test"
    error_message = "Framework Name/Environment/Terraform tags must win while unrelated consumer tags survive."
  }
}

run "rejects_a_subnet_shaped_network_key" {
  command = plan

  variables {
    networks = {
      "subnet-poc" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        tags              = {}
      }
    }
  }

  expect_failures = [var.networks]
}

run "rejects_null_attributes" {
  command = plan

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        tags              = null
      }
    }
  }

  expect_failures = [var.networks]
}

run "rejects_an_unsupported_availability_zone" {
  command = plan

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-west-2a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        tags              = {}
      }
    }
  }

  expect_failures = [var.networks]
}

run "rejects_a_malformed_or_ipv6_cidr" {
  command = plan

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "2001:db8::/64"
        subnet_cidr       = "not-a-cidr"
        tags              = {}
      }
    }
  }

  expect_failures = [var.networks]
}

run "rejects_subnet_outside_vpc" {
  command = plan

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.21.0.0/28"
        tags              = {}
      }
    }
  }

  expect_failures = [var.networks]
}

run "rejects_out_of_range_prefix_lengths" {
  command = plan

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.0.0.0/8"
        subnet_cidr       = "10.20.0.0/29"
        tags              = {}
      }
    }
  }

  expect_failures = [var.networks]
}

run "rejects_reserved_tag_namespace" {
  command = plan

  variables {
    networks = {
      "poc-net" = {
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        tags = {
          "nwarila:management:repository-id" = "consumer-owned"
        }
      }
    }
  }

  expect_failures = [var.resource_metadata]
}
