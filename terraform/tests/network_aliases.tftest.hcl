mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-preexisting"
    }
  }
}

variables {
  environment = "TEST"

  network_aliases = {
    "poc-net" = {
      subnet_id         = "subnet-0123456789abcdef0"
      vpc_id            = "vpc-0123456789abcdef0"
      subnet_cidr       = "10.20.0.0/28"
      availability_zone = "us-east-1a"
    }
  }

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "alias-host"
      availability_zone    = "us-east-1a"
      subnet_id            = "poc-net"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"
      refresh              = false
      instance_type        = "m6i.large"
      readiness_user       = null
      readiness_gate       = false
      imds_hop_limit       = 1
      set_state            = null
      tags                 = { Function = "Alias contract system", Backup = true }
      root_block_device = {
        delete_on_termination = true
        iops                  = null
        tags                  = {}
        throughput            = null
        volume_type           = "gp3"
        volume_size           = "100"
      }
      ebs_block_devices = []
      network_interfaces = [
        {
          private_ip      = "10.20.0.4"
          security_groups = []
          description     = "Alias-owned inline group"
          interface_type  = null
          ingress         = []
          egress          = []
          tags            = {}
        }
      ]
      associate_public_ip = false
    }
  ]
}

run "empty_alias_map_is_the_zero_resource_anchor" {
  command = plan

  variables {
    network_aliases = {}
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "literal-anchor"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 1
        set_state            = null
        tags                 = { Function = "Literal zero anchor", Backup = true }
        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }
        ebs_block_devices = []
        network_interfaces = [
          {
            private_ip      = null
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = alltrue([for interface in values(local.elastic_network_interfaces.us_east_1) : interface.subnet_id == "subnet-preexisting"])
    error_message = "An empty alias map must pass every literal subnet reference through unchanged."
  }

  assert {
    condition     = length(aws_eip.us_east_1) == 0 && length(aws_eip_association.us_east_1) == 0
    error_message = "The default-off alias path must create no Elastic IP resources."
  }
}

run "alias_resolves_subnet_id_on_every_interface" {
  command = apply

  assert {
    condition     = local.elastic_network_interfaces.us_east_1["alias-host-eni-0"].subnet_id == "subnet-0123456789abcdef0"
    error_message = "A symbolic subnet name must resolve to the alias subnet_id on every interface."
  }
}

run "alias_with_vpc_id_skips_the_subnet_lookup" {
  command = apply

  assert {
    condition     = length(data.aws_subnet.us_east_1_inline_security_group) == 0
    error_message = "An alias with vpc_id must keep the inline-group subnet lookup collection empty."
  }

  assert {
    condition     = aws_security_group.us_east_1["alias-host-eni-0-sg"].vpc_id == "vpc-0123456789abcdef0"
    error_message = "An interface-owned group must consume the VPC id supplied by its alias."
  }
}

run "alias_without_vpc_id_falls_back_to_the_subnet_lookup" {
  command = apply

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = null
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = "us-east-1a"
      }
    }
  }

  assert {
    condition     = length(data.aws_subnet.us_east_1_inline_security_group) == 1 && contains(keys(data.aws_subnet.us_east_1_inline_security_group), "subnet-0123456789abcdef0")
    error_message = "An alias without vpc_id must look up exactly the resolved subnet id."
  }

  assert {
    condition     = aws_security_group.us_east_1["alias-host-eni-0-sg"].vpc_id == "vpc-preexisting"
    error_message = "The interface-owned group must use the VPC returned by the resolved-subnet lookup."
  }
}

run "literal_subnet_id_still_works_with_an_empty_alias_map" {
  command = plan

  variables {
    network_aliases = {}
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "literal-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 1
        set_state            = null
        tags                 = { Function = "Literal compatibility", Backup = true }
        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }
        ebs_block_devices = []
        network_interfaces = [
          {
            private_ip      = null
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = local.elastic_network_interfaces.us_east_1["literal-host-eni-0"].subnet_id == "subnet-preexisting"
    error_message = "Literal subnet ids must remain byte-identical when network_aliases is empty."
  }
}

run "associate_public_ip_no_longer_requires_a_framework_owned_public_network" {
  command = apply

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "public-alias-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "poc-net"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 1
        set_state            = null
        tags                 = { Function = "Public alias", Backup = true }
        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }
        ebs_block_devices = []
        network_interfaces = [
          {
            private_ip      = null
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
        associate_public_ip = true
      }
    ]
  }

  assert {
    condition     = contains(keys(aws_eip.us_east_1), "public-alias-host") && contains(keys(aws_eip_association.us_east_1), "public-alias-host")
    error_message = "associate_public_ip must create the EIP and association without a framework-owned network."
  }
}

run "rejects_a_subnet_id_that_is_neither_alias_nor_reference" {
  command = plan

  variables {
    network_aliases = {}
  }

  expect_failures = [var.network_aliases]
}

run "rejects_a_subnet_shaped_alias_key" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = "us-east-1a"
      }
      "subnet-poc" = {
        subnet_id         = "subnet-11111111111111111"
        vpc_id            = "vpc-11111111111111111"
        subnet_cidr       = "10.21.0.0/28"
        availability_zone = "us-east-1a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "a_subnet_shaped_name_cannot_degrade_silently_when_the_alias_map_is_empty" {
  command = plan

  variables {
    network_aliases = {}
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "literal-shaped-hazard"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-poc"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 1
        set_state            = null
        tags                 = { Function = "Document literal-shaped hazard", Backup = true }
        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }
        ebs_block_devices = []
        network_interfaces = [
          {
            private_ip      = null
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = local.elastic_network_interfaces.us_east_1["literal-shaped-hazard-eni-0"].subnet_id == "subnet-poc"
    error_message = "A subnet-shaped value passes as a literal, documenting why alias keys must reject this shape upstream."
  }
}

run "rejects_an_alias_subnet_id_that_is_not_a_subnet_reference" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "poc-net"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = "us-east-1a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "rejects_a_malformed_alias_vpc_id" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "not-a-vpc"
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = "us-east-1a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "rejects_an_out_of_region_availability_zone" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = "us-west-2a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "rejects_az_mismatch" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = "us-east-1b"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "allows_az_mismatch_when_the_alias_omits_the_availability_zone" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.0.0/28"
        availability_zone = null
      }
    }
  }

  assert {
    condition     = local.elastic_network_interfaces.us_east_1["alias-host-eni-0"].subnet_id == "subnet-0123456789abcdef0"
    error_message = "Null availability-zone metadata must skip only the alias AZ cross-check."
  }
}

run "rejects_private_ip_outside_subnet_cidr" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.1.0/28"
        availability_zone = "us-east-1a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "rejects_private_ip_in_the_first_four_reserved_addresses" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "10.20.0.4/30"
        availability_zone = "us-east-1a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}

run "rejects_the_last_reserved_private_ip" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "last-reserved"
        availability_zone    = "us-east-1a"
        subnet_id            = "poc-net"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 1
        set_state            = null
        tags                 = { Function = "Last reserved address", Backup = true }
        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }
        ebs_block_devices = []
        network_interfaces = [
          {
            private_ip      = "10.20.0.15"
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.network_aliases]
}

run "allows_assignable_pinned_and_auto_addresses_together" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "pin-ok"
        availability_zone    = "us-east-1a"
        subnet_id            = "poc-net"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 1
        set_state            = null
        tags                 = { Function = "Assignable and automatic addresses", Backup = true }
        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }
        ebs_block_devices = []
        network_interfaces = [
          {
            private_ip      = "10.20.0.4"
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          },
          {
            private_ip      = "10.20.0.14"
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          },
          {
            private_ip      = null
            security_groups = ["sg-preexisting"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      local.elastic_network_interfaces.us_east_1["pin-ok-eni-0"].private_ips[0] == "10.20.0.4",
      local.elastic_network_interfaces.us_east_1["pin-ok-eni-1"].private_ips[0] == "10.20.0.14",
      local.elastic_network_interfaces.us_east_1["pin-ok-eni-2"].private_ips == null,
    ])
    error_message = "The first and last assignable addresses must pass while null still delegates address selection to AWS."
  }
}

run "skips_the_private_ip_check_when_the_alias_omits_subnet_cidr" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = null
        availability_zone = "us-east-1a"
      }
    }
  }

  assert {
    condition     = local.elastic_network_interfaces.us_east_1["alias-host-eni-0"].private_ips[0] == "10.20.0.4"
    error_message = "Null subnet_cidr metadata must skip the private-IP containment check."
  }
}

run "reports_malformed_subnet_cidr_without_a_raw_function_error" {
  command = plan

  variables {
    network_aliases = {
      "poc-net" = {
        subnet_id         = "subnet-0123456789abcdef0"
        vpc_id            = "vpc-0123456789abcdef0"
        subnet_cidr       = "not-a-cidr"
        availability_zone = "us-east-1a"
      }
    }
  }

  expect_failures = [var.network_aliases]
}
