mock_provider "aws" {
  alias = "us_east_1"

  # Interface-group VPC derivation reads the parent system's subnet when subnet_id is a literal id.
  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-fromsubnetlookup"
    }
  }
}

variables {
  environment = "TEST"
}

# CASE 1 (renders and attaches): an interface-owned group is created, deterministically named,
# tagged from its interface, materialized with a stable content-derived rule address, and attached
# to that ENI alongside the standing group the consumer did list.
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
          Function = "Interface owning its firewall inline"
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

        # The consumer lists ONLY the foreign/standing group; this interface declares its own.
        network_interfaces = [
          {
            private_ip      = "10.0.0.41"
            security_groups = ["sg-0123456789abcdef0"]
            description     = "Wazuh AIO interface-specific inbound firewall."
            interface_type  = null
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
        ]


        associate_public_ip = false
      }
    ]
  }

  # Deterministic naming: "<hostname>-eni-<index>-sg", created through the regional security-group
  # resource.
  assert {
    condition     = length(aws_security_group.us_east_1) == 1 && contains(keys(aws_security_group.us_east_1), "inline-host-eni-0-sg")
    error_message = "A first-interface group must be created as aws_security_group.us_east_1[\"<hostname>-eni-0-sg\"]."
  }

  assert {
    condition     = aws_security_group.us_east_1["inline-host-eni-0-sg"].name == "inline-host-eni-0-sg"
    error_message = "The created group's AWS name must be the raw zero-based, position-derived <hostname>-eni-0-sg, not the hostname or bare <hostname>-sg."
  }

  assert {
    condition     = aws_security_group.us_east_1["inline-host-eni-0-sg"].description == "Wazuh AIO interface-specific inbound firewall."
    error_message = "The interface description must reach the created group."
  }

  # VPC derived from the system's own subnet - never restated by the consumer.
  assert {
    condition     = aws_security_group.us_east_1["inline-host-eni-0-sg"].vpc_id == "vpc-fromsubnetlookup"
    error_message = "A literal subnet_id must derive the interface group's vpc_id from the subnet lookup."
  }

  # Framework Name/Environment/Terraform tags and consumer tags reach the group directly; the
  # nwarila: deployment identity is applied through provider default_tags.
  assert {
    condition = alltrue([
      aws_security_group.us_east_1["inline-host-eni-0-sg"].tags["Name"] == "inline-host-eni-0-sg",
      aws_security_group.us_east_1["inline-host-eni-0-sg"].tags["Environment"] == "TEST",
      aws_security_group.us_east_1["inline-host-eni-0-sg"].tags["Terraform"] == "True",
      aws_security_group.us_east_1["inline-host-eni-0-sg"].tags["Role"] == "wazuh-aio",
    ])
    error_message = "An interface-owned group must carry framework tags plus its interface's consumer tags."
  }

  # The nwarila: deployment identity reaches this group through provider default_tags, which the
  # mocked provider does not merge into tags_all. What IS provable here - and what the IAM create
  # conditions actually key on - is that the group is created by the regional aws_security_group
  # resource under the provider configured with that default_tags set. local.deployment_tags being
  # non-empty is asserted in tagging.tftest.hcl.
  assert {
    condition     = length(local.deployment_tags) == 6 && local.deployment_tags["nwarila:management:stack"] == "inline-sg-us-east-1"
    error_message = "The deployment identity that provider default_tags stamps onto the interface group must be populated."
  }

  # Rules flow through the shared content-identity flattening path.
  assert {
    condition = alltrue([
      length(aws_vpc_security_group_ingress_rule.us_east_1) == 1,
      length(aws_vpc_security_group_egress_rule.us_east_1) == 0,
      one(values(aws_vpc_security_group_ingress_rule.us_east_1)).from_port == 1514,
      one(values(aws_vpc_security_group_ingress_rule.us_east_1)).to_port == 1515,
      one(values(aws_vpc_security_group_ingress_rule.us_east_1)).cidr_ipv4 == "10.1.10.0/24",
      one(values(aws_vpc_security_group_ingress_rule.us_east_1)).security_group_id == aws_security_group.us_east_1["inline-host-eni-0-sg"].id,
      !contains(keys(one(values(aws_vpc_security_group_ingress_rule.us_east_1)).tags), "Name"),
    ])
    error_message = "Interface rules must use stable content-derived addresses, bind to their group, and omit the unbounded key from the Name tag."
  }

  # Auto-attach: the consumer listed only the standing group; the framework appended its own.
  assert {
    condition = alltrue([
      length(aws_network_interface.us_east_1["inline-host-eni-0"].security_groups) == 2,
      contains(aws_network_interface.us_east_1["inline-host-eni-0"].security_groups, "sg-0123456789abcdef0"),
      contains(aws_network_interface.us_east_1["inline-host-eni-0"].security_groups, aws_security_group.us_east_1["inline-host-eni-0-sg"].id),
    ])
    error_message = "The interface group must attach to its ENI alongside the foreign groups the consumer listed."
  }
}

# A system whose ONLY group is its interface-owned one is VALID, and its ENI carries exactly that group -
# never an empty list, which would make AWS attach the VPC default allow-all group.
run "interface_group_alone_satisfies_the_empty_list_assert" {
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
          Function = "Interface group is the system's only group"
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
            description     = "Zero-inbound interface group (SSM posture)."
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

  assert {
    condition     = aws_network_interface.us_east_1["inline-only-host-eni-0"].security_groups == toset([aws_security_group.us_east_1["inline-only-host-eni-0-sg"].id])
    error_message = "An interface-owned group must satisfy the no-default-group guard when security_groups is empty."
  }
}

# Each interface owns a distinct group at its raw interface index. Rules and attachments must never
# bleed between interfaces.
run "multiple_interfaces_get_distinct_groups_rules_and_attachments" {
  command = apply

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "multi-eni-host"
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
          Function = "Distinct firewall per interface"
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
            description     = "Primary interface firewall."
            interface_type  = null
            ingress = [
              {
                description                  = "HTTPS to the primary interface"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = "10.0.0.0/8"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            egress = []
            tags = {
              Role = "primary"
            }
          },
          {
            private_ip      = "10.0.0.44"
            security_groups = []
            description     = null
            interface_type  = null
            ingress         = []
            egress = [
              {
                description                  = "DNS from the secondary interface"
                ip_protocol                  = "udp"
                from_port                    = 53
                to_port                      = 53
                cidr_ipv4                    = "0.0.0.0/0"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            tags = {
              Role = "secondary"
            }
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(aws_security_group.us_east_1) == 2,
      aws_security_group.us_east_1["multi-eni-host-eni-0-sg"].name == "multi-eni-host-eni-0-sg",
      aws_security_group.us_east_1["multi-eni-host-eni-1-sg"].name == "multi-eni-host-eni-1-sg",
      aws_security_group.us_east_1["multi-eni-host-eni-0-sg"].description == "Primary interface firewall.",
      aws_security_group.us_east_1["multi-eni-host-eni-1-sg"].description == "Managed by aws-terraform-framework.",
      aws_security_group.us_east_1["multi-eni-host-eni-0-sg"].tags["Role"] == "primary",
      aws_security_group.us_east_1["multi-eni-host-eni-1-sg"].tags["Role"] == "secondary",
    ])
    error_message = "Each interface must create its own indexed group with its own description and tags."
  }

  assert {
    condition = alltrue([
      length(aws_vpc_security_group_ingress_rule.us_east_1) == 1,
      length(aws_vpc_security_group_egress_rule.us_east_1) == 1,
      one(values(aws_vpc_security_group_ingress_rule.us_east_1)).security_group_id == aws_security_group.us_east_1["multi-eni-host-eni-0-sg"].id,
      one(values(aws_vpc_security_group_ingress_rule.us_east_1)).from_port == 443,
      one(values(aws_vpc_security_group_egress_rule.us_east_1)).security_group_id == aws_security_group.us_east_1["multi-eni-host-eni-1-sg"].id,
      one(values(aws_vpc_security_group_egress_rule.us_east_1)).from_port == 53,
    ])
    error_message = "Each interface's rules must bind only to that interface's own group."
  }

  assert {
    condition = alltrue([
      aws_network_interface.us_east_1["multi-eni-host-eni-0"].security_groups == toset([aws_security_group.us_east_1["multi-eni-host-eni-0-sg"].id]),
      aws_network_interface.us_east_1["multi-eni-host-eni-1"].security_groups == toset([aws_security_group.us_east_1["multi-eni-host-eni-1-sg"].id]),
    ])
    error_message = "Each interface must attach only its own group, never another interface's group."
  }

  assert {
    condition = alltrue([
      toset([for nic in aws_instance.us_east_1["multi-eni-host"].network_interface : nic.device_index]) == toset([0, 1]),
      toset([for nic in aws_instance.us_east_1["multi-eni-host"].network_interface : nic.network_card_index]) == toset([0]),
    ])
    error_message = "Multiple ENIs must use distinct device indices on network card 0 so single-network-card instance types can launch them."
  }
}

# CASE 2 (the sentinel still bites): no interface-owned group and an empty list is still rejected.
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
          Function = "No listed groups and no interface-owned group"
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
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# A group declared by one interface cannot cover another interface on the same system.
run "interface_group_does_not_cover_another_interface" {
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
          Function = "Only the primary interface declares a group"
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
            description     = "Covers only this interface."
            interface_type  = null
            ingress         = []
            egress          = []
            tags            = {}
          },
          {
            private_ip      = "10.0.0.47"
            security_groups = []
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
            description     = "Derives its VPC from the managed network the system sits in."
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

  assert {
    condition     = length(data.aws_subnet.us_east_1_inline_security_group) == 0
    error_message = "A managed_networks subnet_id must resolve the inline group's VPC without any subnet API lookup."
  }

  assert {
    condition     = aws_security_group.us_east_1["managed-net-host-eni-0-sg"].vpc_id == aws_vpc.us_east_1["inline-net"].id
    error_message = "An inline group on a managed network must be created in that network's framework-created VPC."
  }
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
            description     = "World-open ingress must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "World-open IPv6 ingress must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Zero-padded world-open IPv4 ingress must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Zero-padded world-open IPv6 ingress must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Noncanonical world-open IPv4 ingress must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Noncanonical world-open IPv6 ingress must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Whitespace-bearing IPv4 ingress prefix must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Whitespace-bearing IPv6 ingress prefix must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Hexadecimal IPv4 ingress prefix must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
            description     = "Hexadecimal IPv6 ingress prefix must fail."
            interface_type  = null
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
            egress = []
            tags   = {}
          }
        ]


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
        hostname             = "all-protocol-port-host"
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
          Function = "Misleading all-protocol port range"
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
            description     = "All protocols with an apparent HTTPS-only range must fail."
            interface_type  = null
            ingress = [
              {
                description                  = "Apparently HTTPS-only, effectively all ports"
                ip_protocol                  = "-1"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = "10.0.0.0/8"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            egress = []
            tags   = {}
          }
        ]

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
            description     = "Reserved tag namespace must fail."
            interface_type  = null
            ingress         = []
            egress          = []
            tags = {
              "nwarila:management:owner-override" = "me"
            }
          }
        ]


        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.resource_metadata]
}

run "inline_group_tags_reject_the_reserved_namespace_with_null_metadata" {
  command = plan

  variables {
    resource_metadata = null

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "reserved-null-tag-host"
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
          Function = "Reserved namespace with null metadata"
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
            security_groups = ["sg-0123456789abcdef0"]
            description     = "Reserved tag namespace must fail with default metadata."
            interface_type  = null
            ingress         = []
            egress          = []
            tags = {
              "nwarila:management:owner-override" = "me"
            }
          }
        ]

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
            description     = "Zero-inbound with unrestricted egress."
            interface_type  = null
            ingress         = []
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
        ]


        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(aws_vpc_security_group_egress_rule.us_east_1) == 1,
      one(values(aws_vpc_security_group_egress_rule.us_east_1)).cidr_ipv4 == "0.0.0.0/0",
      length(aws_vpc_security_group_ingress_rule.us_east_1) == 0,
    ])
    error_message = "Unrestricted egress must remain supported on the inline path; only ingress is banned from world-open sources."
  }
}

# The derived name is "<hostname>-eni-<index>-sg", so a hostname EC2 will not accept inside a group name has to
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
            description     = "Would be named sg-reserved-host-eni-0-sg, which EC2 rejects."
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

  expect_failures = [var.all_systems]
}

# The current rendered name includes the nine-character "-eni-0-sg" suffix. A 247-character hostname
# produces 256 characters and must fail before EC2 rejects CreateSecurityGroup. The validation
# measures the rendered name, so a future two-digit index automatically reduces the budget.
run "inline_group_rejects_a_hostname_over_the_246_character_budget" {
  command = plan

  variables {

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = join("", [for index in range(247) : "a"])
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
            description     = "Its rendered name would be 256 characters."
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
            security_groups = ["stale-ref-host-eni-0-sg"]
            description     = "Attached automatically; must not be listed."
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

  expect_failures = [var.all_systems]
}

run "naming_an_inline_group_with_different_case_is_rejected" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "case-ref-host"
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
          Function = "Case-variant inline group also named in the list"
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
            security_groups = ["CASE-REF-HOST-ENI-0-SG"]
            description     = "Attached automatically; a case variant must not be listed."
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

  expect_failures = [var.all_systems]
}

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
            description     = "Null ingress must fail."
            interface_type  = null
            ingress         = null
            egress          = []
            tags            = {}
          }
        ]


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
            description     = "The derived name starts with the reserved prefix."
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
            description     = "First case-variant inline group."
            interface_type  = null
            ingress         = []
            egress          = []
            tags            = {}
          }
        ]


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
            description     = "Second case-variant inline group."
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
            description     = "East regional case-variant inline group."
            interface_type  = null
            ingress         = []
            egress          = []
            tags            = {}
          }
        ]


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
            description     = "West regional case-variant inline group."
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

  expect_failures = [var.aws_config]
}
