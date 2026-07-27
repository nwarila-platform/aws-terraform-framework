mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-preexisting"
    }
  }
}

# secure-wazuh-shaped baseline: a plain Linux system that references only pre-existing
# infrastructure and sets none of the managed_* variables. Every managed capability added to this
# framework MUST keep this run passing untouched — it is the mechanical zero-diff guarantee that
# consumers which ignore the new variables see no new resources and no re-keyed addresses.
variables {
  environment = "TEST"

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "wazuh-like"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

      refresh        = false
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1
      set_state      = null

      tags = {
        Function = "wazuh-shaped baseline system"
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
          private_ip      = "10.0.0.10"
          security_groups = ["sg-01234567"]
          description     = null
          interface_type  = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    }
  ]
}

run "wazuh_preexisting_shape_is_zero_diff" {
  command = plan

  assert {
    condition     = length(aws_key_pair.us_east_1) == 0
    error_message = "With managed_keypairs unset, the framework must create zero key pairs."
  }

  assert {
    condition     = contains(keys(data.aws_key_pair.us_east_1), "preexisting-key")
    error_message = "Pre-existing key pairs must still resolve through the data lookup, keyed by name."
  }

  assert {
    condition     = contains(keys(aws_instance.us_east_1), "wazuh-like")
    error_message = "Existing instance addresses and for_each keys must be unchanged."
  }

  assert {
    condition     = length(aws_security_group.us_east_1) == 0 && length(aws_vpc_security_group_ingress_rule.us_east_1) == 0 && length(aws_vpc_security_group_egress_rule.us_east_1) == 0
    error_message = "With no inline managed_security_group, the framework must create zero security groups and zero rules."
  }

  assert {
    condition     = length(data.aws_subnet.us_east_1_inline_security_group) == 0
    error_message = "With no inline managed_security_group, the framework must perform zero inline VPC-derivation subnet lookups."
  }

  assert {
    condition     = length(aws_vpc.us_east_1) == 0 && length(aws_subnet.us_east_1) == 0 && length(aws_internet_gateway.us_east_1) == 0 && length(aws_route_table.us_east_1) == 0 && length(aws_eip.us_east_1) == 0 && length(aws_eip_association.us_east_1) == 0
    error_message = "With managed_networks unset and no associate_public_ip, the framework must create zero networking resources."
  }
}

run "managed_key_pair_created_from_public_key" {
  command = plan

  variables {
    managed_keypairs = {
      "managed-key" = {
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderPublicKeyMaterialForPlanOnly deploy@mock"
        tags       = {}
      }
    }

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "managed-kp-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "managed-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "System using a framework-managed key pair"
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
            private_ip      = "10.0.0.11"
            security_groups = ["sg-01234567"]
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
    condition     = aws_key_pair.us_east_1["managed-key"].public_key != ""
    error_message = "Managed key pairs must be created in the supported region."
  }

  assert {
    condition     = length(data.aws_key_pair.us_east_1) == 0
    error_message = "A managed key-pair name must never be looked up as a pre-existing key pair."
  }

  assert {
    condition     = aws_instance.us_east_1["managed-kp-host"].key_name == "managed-key"
    error_message = "Instances must resolve managed key-pair names through local.key_pair_names."
  }
}

run "managed_key_pair_rejects_non_openssh_material" {
  command = plan

  variables {
    managed_keypairs = {
      "bad-key" = {
        public_key = "not-an-openssh-public-key"
        tags       = {}
      }
    }
  }

  expect_failures = [var.managed_keypairs]
}

run "managed_key_pair_accepts_rsa_public_key" {
  command = plan

  variables {
    managed_keypairs = {
      "rsa-key" = {
        public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 rsa@mock"
        tags       = {}
      }
    }
  }

  assert {
    condition     = aws_key_pair.us_east_1["rsa-key"].public_key != ""
    error_message = "EC2-supported RSA public keys must pass managed_keypairs lexical validation."
  }
}

run "managed_key_pair_accepts_terminal_lf" {
  command = plan

  variables {
    managed_keypairs = {
      "terminal-lf-key" = {
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderPublicKeyMaterialForPlanOnly\n"
        tags       = {}
      }
    }
  }

  assert {
    condition     = aws_key_pair.us_east_1["terminal-lf-key"].public_key != ""
    error_message = "A file-shaped OpenSSH public key with one terminal LF must pass managed_keypairs lexical validation."
  }
}

run "managed_key_pair_rejects_ecdsa" {
  command = plan

  variables {
    managed_keypairs = {
      "ecdsa-key" = {
        public_key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTY= ecdsa@mock"
        tags       = {}
      }
    }
  }

  expect_failures = [var.managed_keypairs]
}

run "managed_key_pair_rejects_embedded_lf" {
  command = plan

  variables {
    managed_keypairs = {
      "embedded-lf-key" = {
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderPublicKeyMaterialForPlanOnly first@mock\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 injected@mock"
        tags       = {}
      }
    }
  }

  expect_failures = [var.managed_keypairs]
}

run "managed_key_pair_rejects_embedded_crlf" {
  command = plan

  variables {
    managed_keypairs = {
      "embedded-crlf-key" = {
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderPublicKeyMaterialForPlanOnly first@mock\r\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 injected@mock"
        tags       = {}
      }
    }
  }

  expect_failures = [var.managed_keypairs]
}

run "inline_sg_zero_inbound_with_ssm_egress" {
  command = apply

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "managed-sg-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        readiness_gate       = false
        imds_hop_limit       = 1

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        set_state      = null

        tags = {
          Function = "Zero-inbound SSM system on a managed security group"
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
            private_ip      = "10.0.0.12"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        managed_security_group = {
          ingress = []
          egress = [
            { description = "SSM/HTTPS", ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
            { description = "DNS udp", ip_protocol = "udp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
            { description = "DNS tcp", ip_protocol = "tcp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
          ]
          description = "Managed by aws-terraform-framework"
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = contains(keys(aws_security_group.us_east_1), "managed-sg-host-sg-0")
    error_message = "The inline security group must be created under its derived name."
  }

  assert {
    condition     = aws_security_group.us_east_1["managed-sg-host-sg-0"].vpc_id == "vpc-preexisting"
    error_message = "The inline security group must derive its VPC from the system subnet."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.us_east_1) == 0
    error_message = "A managed group declaring no ingress must create zero ingress rules (zero-inbound posture)."
  }

  assert {
    condition = alltrue([
      length(aws_vpc_security_group_egress_rule.us_east_1) == 3,
      aws_vpc_security_group_egress_rule.us_east_1["managed-sg-host-sg-0/egress-0"].cidr_ipv4 == "0.0.0.0/0",
      aws_vpc_security_group_egress_rule.us_east_1["managed-sg-host-sg-0/egress-0"].from_port == 443,
      aws_vpc_security_group_egress_rule.us_east_1["managed-sg-host-sg-0/egress-1"].ip_protocol == "udp",
      aws_vpc_security_group_egress_rule.us_east_1["managed-sg-host-sg-0/egress-1"].from_port == 53,
      aws_vpc_security_group_egress_rule.us_east_1["managed-sg-host-sg-0/egress-2"].ip_protocol == "tcp",
    ])
    error_message = "Inline egress rules must materialize with stable <sg>/egress-<index> addresses and exact ports."
  }

  assert {
    condition     = contains(aws_network_interface.us_east_1["managed-sg-host-eni-0"].security_groups, aws_security_group.us_east_1["managed-sg-host-sg-0"].id)
    error_message = "The inline security group must attach automatically when the explicit security_groups list is empty."
  }
}

run "managed_public_network_creates_vpc_subnet_igw_route_and_eip" {
  command = apply

  variables {
    managed_networks = {
      "wsus-poc" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        public            = true
        vpc_id            = null
        tags              = {}
      }
    }

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "wsus-poc-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "wsus-poc"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        associate_public_ip  = true
        readiness_gate       = false
        imds_hop_limit       = 1

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        set_state      = null

        tags = {
          Function = "Fully managed-network system with public IPv4"
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
            security_groups = []
            description     = null
            interface_type  = null
            private_ip      = null
            tags            = {}
          }
        ]

        managed_security_group = {
          egress = [
            { description = "SSM/HTTPS", ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
          ]
          description = "Managed by aws-terraform-framework"
          ingress     = []
          tags        = {}
        }
      }
    ]
  }

  assert {
    condition = alltrue([
      aws_vpc.us_east_1["wsus-poc"].cidr_block == "10.20.0.0/24",
      aws_subnet.us_east_1["wsus-poc"].cidr_block == "10.20.0.0/28",
      aws_subnet.us_east_1["wsus-poc"].availability_zone == "us-east-1a",
      aws_subnet.us_east_1["wsus-poc"].map_public_ip_on_launch == false,
      contains(keys(aws_internet_gateway.us_east_1), "wsus-poc"),
      contains(keys(aws_route_table.us_east_1), "wsus-poc"),
      aws_route.us_east_1_default["wsus-poc"].destination_cidr_block == "0.0.0.0/0",
      contains(keys(aws_route_table_association.us_east_1), "wsus-poc"),
    ])
    error_message = "A public managed network must create VPC, subnet, IGW, route table, default route, and association."
  }

  assert {
    condition     = contains(keys(aws_eip.us_east_1), "wsus-poc-host") && contains(keys(aws_eip_association.us_east_1), "wsus-poc-host")
    error_message = "associate_public_ip must allocate an EIP and bind it to the primary ENI in the supported region."
  }

  assert {
    condition     = aws_security_group.us_east_1["wsus-poc-host-sg-0"].vpc_id == aws_vpc.us_east_1["wsus-poc"].id
    error_message = "The inline security group must derive the managed VPC ID from its system's managed-network subnet."
  }

  assert {
    condition     = local.elastic_network_interfaces.us_east_1["wsus-poc-host-eni-0"].private_ips == null
    error_message = "An omitted private_ip must let AWS pick the address (private_ips null on the ENI)."
  }
}

run "managed_private_network_creates_no_igw_route_or_eip" {
  command = plan

  variables {
    managed_networks = {
      "quiet-net" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.30.0.0/24"
        subnet_cidr       = "10.30.0.0/28"
        vpc_id            = null
        public            = false
        tags              = {}
      }
    }

  }

  assert {
    condition     = contains(keys(aws_vpc.us_east_1), "quiet-net") && contains(keys(aws_subnet.us_east_1), "quiet-net")
    error_message = "A private managed network must still create its VPC and subnet."
  }

  assert {
    condition     = length(aws_internet_gateway.us_east_1) == 0 && length(aws_route_table.us_east_1) == 0 && length(aws_eip.us_east_1) == 0
    error_message = "public = false must create no IGW, route table, or EIP."
  }
}

run "managed_byo_vpc_creates_subnet_only" {
  command = plan

  variables {
    managed_networks = {
      "byo-net" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_id            = "vpc-preexisting"
        subnet_cidr       = "172.31.64.0/28"
        vpc_cidr          = null
        public            = false
        tags              = {}
      }
    }

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "byo-vpc-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "byo-net"
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
          Function = "Inline security group in a BYO VPC"
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
          description = "Inline group resolved through a BYO managed-network entry."
          ingress     = []
          egress      = []
          tags        = {}
        }

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = length(aws_vpc.us_east_1) == 0 && aws_subnet.us_east_1["byo-net"].vpc_id == "vpc-preexisting"
    error_message = "A BYO vpc_id network must create only the subnet, attached to the supplied VPC."
  }

  assert {
    condition     = aws_security_group.us_east_1["byo-vpc-host-sg-0"].vpc_id == "vpc-preexisting"
    error_message = "An inline group on a BYO managed-network subnet must resolve to that network's supplied VPC ID."
  }
}

run "managed_network_rejects_unsupported_region" {
  command = plan

  variables {
    aws_config = {
      regions = ["us_east_1", "eu_west_1"]
    }

    managed_networks = {
      "west-net" = {
        region            = "eu_west_1"
        availability_zone = "eu-west-1a"
        vpc_cidr          = "10.40.0.0/24"
        subnet_cidr       = "10.40.0.0/28"
        vpc_id            = null
        public            = false
        tags              = {}
      }
    }

  }

  expect_failures = [var.aws_config]
}

run "managed_network_rejects_subnet_outside_vpc" {
  command = plan

  variables {
    managed_networks = {
      "outside-net" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.50.0.0/24"
        subnet_cidr       = "10.50.1.0/28"
        vpc_id            = null
        public            = false
        tags              = {}
      }
    }
  }

  expect_failures = [var.managed_networks]
}

run "managed_network_rejects_public_ip_without_public_network" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "bad-eip-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        associate_public_ip  = true

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Public IP without managed public network"
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
            private_ip      = "10.0.0.13"
            security_groups = ["sg-01234567"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]
      }
    ]
  }

  expect_failures = [var.managed_networks]
}

run "managed_network_rejects_az_mismatch" {
  command = plan

  variables {
    managed_networks = {
      "wsus-poc" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        subnet_cidr       = "10.20.0.0/28"
        vpc_id            = null
        public            = false
        tags              = {}
      }
    }

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "wrong-az-host"
        availability_zone    = "us-east-1b"
        subnet_id            = "wsus-poc"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "AZ mismatch against managed network"
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
            security_groups = ["sg-01234567"]
            description     = null
            interface_type  = null
            private_ip      = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.managed_networks]
}

run "managed_network_rejects_both_vpc_cidr_and_vpc_id" {
  command = plan

  variables {
    managed_networks = {
      "conflicted" = {
        region            = "us_east_1"
        availability_zone = "us-east-1a"
        vpc_cidr          = "10.20.0.0/24"
        vpc_id            = "vpc-also-set"
        subnet_cidr       = "10.20.0.0/28"
        public            = false
        tags              = {}
      }
    }
  }

  expect_failures = [var.managed_networks]
}

run "managed_keypairs_rejects_null_tags" {
  command = plan

  variables {
    managed_keypairs = {
      "null-tags" = {
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderPublicKeyMaterialForPlanOnly deploy@mock"
        tags       = null
      }
    }
  }

  expect_failures = [var.managed_keypairs]
}

run "managed_networks_rejects_null_public" {
  command = plan

  variables {
    managed_networks = {
      "null-public" = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        subnet_cidr       = "10.60.0.0/28"
        vpc_cidr          = "10.60.0.0/24"
        vpc_id            = null
        public            = null
        tags              = {}
      }
    }
  }

  expect_failures = [var.managed_networks]
}
