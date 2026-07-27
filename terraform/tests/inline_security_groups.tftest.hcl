mock_provider "aws" {
  alias = "us_east_1"

  # The inline-group VPC derivation reads the system's subnet when subnet_id is a literal id.
  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-fromsubnetlookup"
    }
  }
}

variables {
  environment = "TEST"
}

# CASE 1 (renders and attaches): an inline group is created, deterministically named, tagged like a
# managed group, its rules materialize at stable <sg>/<direction>-<index> addresses, and it is
# auto-attached to the system's ENI alongside the standing group the consumer did list.
run "inline_group_is_created_named_tagged_and_auto_attached" {
  command = apply

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "inline-sg-us-east-1"
      owner         = "platform-engineering"
      commit_sha    = null
      run_id        = null
    }


    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "inline-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "System owning its firewall inline"
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

        ebs_block_devices = []

        # The consumer lists ONLY the foreign/standing group; its own group is inline.
        network_interfaces = [
          {
            private_ip      = "10.0.0.41"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Wazuh AIO system-specific inbound firewall."
          ingress = [
            {
              description                  = "Wazuh agent events + enrollment from the deploy subnet"
              ip_protocol                  = "tcp"
              from_port                    = 1514
              to_port                      = 1515
              cidr_ipv4                    = "10.1.10.0/24"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          egress = []
          tags = {
            Role = "wazuh-aio"
          }
        }

        associate_public_ip = false
      }
    ]
  }

  # Deterministic naming: "<hostname>-sg-<index>", created through the regional security-group
  # resource.
  assert {
    condition     = length(aws_security_group.us_east_1) == 1 && contains(keys(aws_security_group.us_east_1), "inline-host-sg-0")
    error_message = "An inline managed_security_group must be created as aws_security_group.us_east_1[\"<hostname>-sg-0\"]."
  }

  assert {
    condition     = aws_security_group.us_east_1["inline-host-sg-0"].name == "inline-host-sg-0"
    error_message = "The created group's AWS name must be the raw zero-based, position-derived <hostname>-sg-0, not the hostname or bare <hostname>-sg."
  }

  assert {
    condition     = aws_security_group.us_east_1["inline-host-sg-0"].description == "Wazuh AIO system-specific inbound firewall."
    error_message = "The inline description must reach the created group."
  }

  # VPC derived from the system's own subnet - never restated by the consumer.
  assert {
    condition     = aws_security_group.us_east_1["inline-host-sg-0"].vpc_id == "vpc-fromsubnetlookup"
    error_message = "A literal subnet_id must derive the inline group's vpc_id from the subnet lookup."
  }

  # Framework Name/Environment/Terraform tags and consumer tags reach the group directly; the
  # nwarila: deployment identity is applied through provider default_tags.
  assert {
    condition = alltrue([
      aws_security_group.us_east_1["inline-host-sg-0"].tags["Name"] == "inline-host-sg-0",
      aws_security_group.us_east_1["inline-host-sg-0"].tags["Environment"] == "TEST",
      aws_security_group.us_east_1["inline-host-sg-0"].tags["Terraform"] == "True",
      aws_security_group.us_east_1["inline-host-sg-0"].tags["Role"] == "wazuh-aio",
    ])
    error_message = "An inline-created group must carry the framework Name/Environment/Terraform tags plus the consumer's own tags."
  }

  # The nwarila: deployment identity reaches this group through provider default_tags, which the
  # mocked provider does not merge into tags_all. What IS provable here - and what the IAM create
  # conditions actually key on - is that the group is created by the regional aws_security_group
  # resource under the provider configured with that default_tags set. local.deployment_tags being
  # non-empty is asserted in tagging.tftest.hcl.
  assert {
    condition     = length(local.deployment_tags) == 6 && local.deployment_tags["nwarila:management:stack"] == "inline-sg-us-east-1"
    error_message = "The deployment identity that provider default_tags stamps onto the inline group must be populated."
  }

  # Rules flow through the shared flattening path at <sg>/<direction>-<index>.
  assert {
    condition = alltrue([
      length(aws_vpc_security_group_ingress_rule.us_east_1) == 1,
      length(aws_vpc_security_group_egress_rule.us_east_1) == 0,
      aws_vpc_security_group_ingress_rule.us_east_1["inline-host-sg-0/ingress-0"].from_port == 1514,
      aws_vpc_security_group_ingress_rule.us_east_1["inline-host-sg-0/ingress-0"].to_port == 1515,
      aws_vpc_security_group_ingress_rule.us_east_1["inline-host-sg-0/ingress-0"].cidr_ipv4 == "10.1.10.0/24",
      aws_vpc_security_group_ingress_rule.us_east_1["inline-host-sg-0/ingress-0"].security_group_id == aws_security_group.us_east_1["inline-host-sg-0"].id,
    ])
    error_message = "Inline rules must materialize at stable <sg>/<direction>-<index> addresses bound to the inline group."
  }

  # Auto-attach: the consumer listed only the standing group; the framework appended its own.
  assert {
    condition = alltrue([
      length(aws_network_interface.us_east_1["inline-host-eni-0"].security_groups) == 2,
      contains(aws_network_interface.us_east_1["inline-host-eni-0"].security_groups, "sg-0123456789abcdef0"),
      contains(aws_network_interface.us_east_1["inline-host-eni-0"].security_groups, aws_security_group.us_east_1["inline-host-sg-0"].id),
    ])
    error_message = "The inline group must be auto-attached to the system's ENI alongside the foreign groups the consumer listed."
  }
}

# A system whose ONLY group is its inline one is VALID, and its ENI carries exactly that group -
# never an empty list, which would make AWS attach the VPC default allow-all group.
run "inline_group_alone_satisfies_the_empty_list_assert" {
  command = apply

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "inline-only-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inline group is the system's only group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.43"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          },
          {
            private_ip      = "10.0.0.44"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Zero-inbound per-system group (SSM posture)."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  # Every NIC of the system, not just the primary, or the assert above becomes a hole.
  assert {
    condition = alltrue([
      aws_network_interface.us_east_1["inline-only-host-eni-0"].security_groups == toset([aws_security_group.us_east_1["inline-only-host-sg-0"].id]),
      aws_network_interface.us_east_1["inline-only-host-eni-1"].security_groups == toset([aws_security_group.us_east_1["inline-only-host-sg-0"].id]),
    ])
    error_message = "The inline group must attach to EVERY interface of its system; any interface left with an empty list receives the VPC default allow-all group."
  }
}

# CASE 2 (the sentinel still bites): no inline group and an empty list is still rejected.
run "nic_with_no_group_at_all_is_still_rejected" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "no-group-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "No listed groups and no inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.45"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# The inline group covers the SYSTEM, so a SECOND system with an empty list and no inline group of
# its own must still fail even while the first system is valid.
run "inline_group_does_not_cover_a_different_system" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "covered-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Has its own inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.46"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Covers only this system."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      },
      {
        region               = "us_east_1"
        hostname             = "uncovered-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "No group of any kind"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.47"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# Managed-network subnets need no subnet lookup: the VPC resolves through local.managed_vpc_ids.
run "inline_group_derives_vpc_from_managed_network_without_a_subnet_lookup" {
  command = apply

  variables {

    managed_networks = {
      "inline-net" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.70.0.0/24"
        subnet_cidr       = "10.70.0.0/28"
        vpc_id            = null
        public            = false
        tags              = {}
      }
    }

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "managed-net-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "inline-net"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inline group on a framework-managed network"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = null
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Derives its VPC from the managed network the system sits in."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = length(data.aws_subnet.us_east_1_inline_security_group) == 0
    error_message = "A managed_networks subnet_id must resolve the inline group's VPC without any subnet API lookup."
  }

  assert {
    condition     = aws_security_group.us_east_1["managed-net-host-sg-0"].vpc_id == aws_vpc.us_east_1["inline-net"].id
    error_message = "An inline group on a managed network must be created in that network's framework-created VPC."
  }
}

# Lowercase TCP rules must set both ports.
run "inline_group_rejects_portless_tcp" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "portless-tcp-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Portless TCP in an inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.49"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Portless TCP must fail."
          ingress     = []
          egress = [
            {
              description                  = "Portless TCP"
              ip_protocol                  = "tcp"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_portless_udp" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "portless-udp-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Portless UDP in an inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.72"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Portless UDP must fail."
          ingress     = []
          egress = [
            {
              description                  = "Portless UDP"
              ip_protocol                  = "udp"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_portless_numeric_tcp" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "portless-numeric-tcp-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Portless numeric TCP in an inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.73"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Portless numeric TCP must fail."
          ingress     = []
          egress = [
            {
              description                  = "Portless numeric TCP"
              ip_protocol                  = "6"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_portless_numeric_udp" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "portless-udp-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Portless numeric UDP in an inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.50"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Portless numeric UDP must fail."
          ingress     = []
          egress = [
            {
              description                  = "Portless numeric UDP"
              ip_protocol                  = "17"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_all_protocol_with_ports" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "all-protocol-with-ports-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "All-protocol rule with ports in an inline group"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.74"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "All-protocol rules must not set ports."
          ingress     = []
          egress = [
            {
              description                  = "All traffic with ports"
              ip_protocol                  = "-1"
              from_port                    = 443
              to_port                      = 443
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_world_open_ipv4_ingress" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "world-open-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "World-open inline ingress"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.51"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "World-open ingress must fail."
          egress      = []
          ingress = [
            {
              description                  = "World open"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_world_open_ipv6_ingress" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "world-open-ipv6-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "World-open IPv6 inline ingress"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.71"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "World-open IPv6 ingress must fail."
          egress      = []
          ingress = [
            {
              description                  = "World open IPv6"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = null
              cidr_ipv6                    = "::/0"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_zero_padded_world_open_ipv4_ingress" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "zero-padded-world-open-ipv4"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Zero-padded world-open IPv4 inline ingress"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.75"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Zero-padded world-open IPv4 ingress must fail."
          egress      = []
          ingress = [
            {
              description                  = "Zero-padded world-open IPv4"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/00"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_zero_padded_world_open_ipv6_ingress" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "zero-padded-world-open-ipv6"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Zero-padded world-open IPv6 inline ingress"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.76"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Zero-padded world-open IPv6 ingress must fail."
          egress      = []
          ingress = [
            {
              description                  = "Zero-padded world-open IPv6"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = null
              cidr_ipv6                    = "::/00"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_noncanonical_world_open_ipv4_ingress" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "noncanonical-world-open-ipv4"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Noncanonical world-open IPv4 inline ingress"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.77"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Noncanonical world-open IPv4 ingress must fail."
          egress      = []
          ingress = [
            {
              description                  = "Noncanonical world-open IPv4"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "1.2.3.4/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_noncanonical_world_open_ipv6_ingress" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "noncanonical-world-open-ipv6"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Noncanonical world-open IPv6 inline ingress"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.78"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Noncanonical world-open IPv6 ingress must fail."
          egress      = []
          ingress = [
            {
              description                  = "Noncanonical world-open IPv6"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = null
              cidr_ipv6                    = "2001:db8::1/0"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_whitespace_ipv4_ingress_prefix" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "whitespace-ipv4-prefix-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Whitespace-bearing IPv4 inline ingress prefix"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.79"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Whitespace-bearing IPv4 ingress prefix must fail."
          egress      = []
          ingress = [
            {
              description                  = "Whitespace-bearing IPv4 prefix"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/ 0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_whitespace_ipv6_ingress_prefix" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "whitespace-ipv6-prefix-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Whitespace-bearing IPv6 inline ingress prefix"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.80"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Whitespace-bearing IPv6 ingress prefix must fail."
          egress      = []
          ingress = [
            {
              description                  = "Whitespace-bearing IPv6 prefix"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = null
              cidr_ipv6                    = "::/ 0"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_hex_ipv4_ingress_prefix" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "hex-ipv4-prefix-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Hexadecimal IPv4 inline ingress prefix"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.81"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Hexadecimal IPv4 ingress prefix must fail."
          egress      = []
          ingress = [
            {
              description                  = "Hexadecimal IPv4 prefix"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0x0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_hex_ipv6_ingress_prefix" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "hex-ipv6-prefix-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Hexadecimal IPv6 inline ingress prefix"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.82"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Hexadecimal IPv6 ingress prefix must fail."
          egress      = []
          ingress = [
            {
              description                  = "Hexadecimal IPv6 prefix"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = null
              cidr_ipv6                    = "::/0x0"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_rejects_rule_without_exactly_one_destination" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "no-destination-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inline rule with no destination"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.52"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Destination-less rule must fail."
          ingress     = []
          egress = [
            {
              description                  = "No destination"
              ip_protocol                  = "tcp"
              from_port                    = 443
              to_port                      = 443
              cidr_ipv4                    = null
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_group_tags_reject_the_reserved_namespace" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "s"
      owner         = "o"
      commit_sha    = null
      run_id        = null
    }

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "reserved-tag-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Reserved namespace in inline group tags"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.53"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Reserved tag namespace must fail."
          ingress     = []
          egress      = []
          tags = {
            "nwarila:management:owner-override" = "me"
          }
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.resource_metadata]
}

# Positive control for the rule above: the CIDR-prefix ban is ingress-only, so an inline group may
# still declare unrestricted EGRESS (the documented posture for outbound-only systems).
run "inline_group_allows_world_open_egress" {
  command = apply

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "egress-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Zero inbound, unrestricted outbound"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.54"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Zero-inbound with unrestricted egress."
          ingress     = []
          egress = [
            {
              description                  = "All outbound"
              ip_protocol                  = "-1"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "0.0.0.0/0"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(aws_vpc_security_group_egress_rule.us_east_1) == 1,
      aws_vpc_security_group_egress_rule.us_east_1["egress-host-sg-0/egress-0"].cidr_ipv4 == "0.0.0.0/0",
      length(aws_vpc_security_group_ingress_rule.us_east_1) == 0,
    ])
    error_message = "Unrestricted egress must remain supported on the inline path; only ingress is banned from world-open sources."
  }
}

# The derived name is "<hostname>-sg-<index>", so a hostname EC2 will not accept inside a group name has to
# be rejected at plan. "sg-" is reserved for group IDs.
run "inline_group_rejects_an_sg_prefixed_hostname" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "sg-reserved-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Hostname that cannot become a legal group name"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.55"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Would be named sg-reserved-host-sg-0, which EC2 rejects."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# The current rendered name includes the five-character "-sg-0" suffix. A 251-character hostname
# produces 256 characters and must fail before EC2 rejects CreateSecurityGroup. The validation
# measures the rendered name, so a future two-digit index automatically reduces the budget.
run "inline_group_rejects_a_hostname_over_the_250_character_budget" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = join("", [for index in range(251) : "a"])
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inline group name over the EC2 length limit"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.66"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Its rendered name would be 256 characters."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# An inline group is attached automatically, so explicitly listing its derived name is invalid.
run "naming_an_inline_group_in_a_security_groups_list_is_rejected" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "stale-ref-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inline group also named in the list"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.56"
            security_groups = ["stale-ref-host-sg-0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Attached automatically; must not be listed."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# A dangling reference that is not a pre-existing sg- ID would otherwise be passed to EC2 verbatim
# and fail only at apply.
run "dangling_security_group_reference_is_rejected" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "dangling-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "References a group nothing defines"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.57"
            security_groups = ["deleted-map-key"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "preexisting_security_group_id_shape_is_accepted" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "valid-sg-id-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Valid pre-existing security-group ID syntax"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.83"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(aws_network_interface.us_east_1["valid-sg-id-host-eni-0"].security_groups) == 1,
      contains(aws_network_interface.us_east_1["valid-sg-id-host-eni-0"].security_groups, "sg-0123456789abcdef0"),
    ])
    error_message = "A pre-existing security-group ID with 17 lowercase hexadecimal characters must pass syntax validation unchanged."
  }
}

run "malformed_sg_prefixed_security_group_id_is_rejected" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "malformed-sg-id-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Malformed sg-prefixed security-group reference"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.84"
            security_groups = ["sg-production"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# The port-pair rule, isolated from the tcp/udp rule: icmp with only one end of the range set.
run "inline_group_rejects_a_half_open_port_pair" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "half-open-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Half-open port pair"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.58"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Half-open port pair must fail."
          egress      = []
          ingress = [
            {
              description                  = "ICMP echo with only one end set"
              ip_protocol                  = "icmp"
              from_port                    = 8
              to_port                      = null
              cidr_ipv4                    = "10.1.10.0/24"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# The structural rule: the inline object is present but a collection is null. Consumers declare
# "no rules" with [], never null.
run "inline_group_rejects_a_null_rule_collection" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "null-collection-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Null ingress collection"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.59"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Null ingress must fail."
          ingress     = null
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# EC2 reserves the sg- prefix without regard to letter case.
run "inline_group_rejects_an_uppercase_sg_prefixed_hostname" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "SG-reserved"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Uppercase reserved security-group prefix"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.60"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "The derived name starts with the reserved prefix."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# Derived inline names collide at EC2 even when their casing differs.
run "inline_group_names_differing_only_by_case_are_rejected" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "Case-Twin"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "First case-variant hostname"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.62"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "First case-variant inline group."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      },
      {
        region               = "us_east_1"
        hostname             = "case-twin"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Second case-variant hostname"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.63"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Second case-variant inline group."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# Region is part of the validation key even though this module currently provisions only
# us-east-1. aws_config therefore remains the sole expected failure in this forward-compatibility
# probe; a cross-region collision reported by var.all_systems makes the run fail.
run "inline_group_names_differing_only_by_case_in_different_regions_do_not_collide" {
  command = plan

  variables {
    aws_config = {
      regions = ["us_east_1", "eu_west_1"]
    }


    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "Regional-Twin"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "East regional case variant"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.64"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "East regional case-variant inline group."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      },
      {
        region               = "eu_west_1"
        hostname             = "regional-twin"
        availability_zone    = "eu-west-1a"
        subnet_id            = "subnet-west"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "West regional case variant"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.1.0.64"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "West regional case-variant inline group."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.aws_config]
}

# Protocol spelling is case-insensitive, so uppercase TCP must also set both ports.
run "inline_group_rejects_portless_uppercase_tcp" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "uppercase-tcp-inline"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Portless uppercase TCP inline rule"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.64"
            security_groups = ["sg-0123456789abcdef0"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          description = "Uppercase TCP must still require ports."
          ingress     = []
          egress = [
            {
              description                  = "Portless uppercase TCP"
              ip_protocol                  = "TCP"
              from_port                    = null
              to_port                      = null
              cidr_ipv4                    = "10.0.0.0/8"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          tags = {}
        }

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}
