mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-preexisting"
    }
  }
}

# secure-wazuh-shaped baseline: a plain Linux system that references only pre-existing
# infrastructure, sets both interface rule collections to null, and sets none of the managed_*
# variables. It is the mechanical guarantee that this explicit pre-created-group path creates no
# additional resources and preserves existing resource keys.
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
          ingress         = null
          egress          = null
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
    error_message = "With no interface-owned group, the framework must create zero security groups and zero rules."
  }

  assert {
    condition     = length(data.aws_subnet.us_east_1_inline_security_group) == 0
    error_message = "With no interface-owned group, the framework must perform zero group VPC-derivation subnet lookups."
  }

  assert {
    condition     = length(aws_eip.us_east_1) == 0 && length(aws_eip_association.us_east_1) == 0
    error_message = "With no associate_public_ip, the framework must create zero networking resources."
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
            description     = "Managed by aws-terraform-framework"
            interface_type  = null
            ingress         = []
            egress = [
              { description = "SSM/HTTPS", ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
              { description = "DNS udp", ip_protocol = "udp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
              { description = "DNS tcp", ip_protocol = "tcp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0", cidr_ipv6 = null, prefix_list_id = null, referenced_security_group_id = null },
            ]
            tags = {}
          }
        ]


        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = contains(keys(aws_security_group.us_east_1), "managed-sg-host-eni-0-sg")
    error_message = "The interface security group must be created under its derived name."
  }

  assert {
    condition     = aws_security_group.us_east_1["managed-sg-host-eni-0-sg"].vpc_id == "vpc-preexisting"
    error_message = "The interface security group must derive its VPC from the parent system subnet."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.us_east_1) == 0
    error_message = "A managed group declaring no ingress must create zero ingress rules (zero-inbound posture)."
  }

  assert {
    condition = alltrue([
      length(aws_vpc_security_group_egress_rule.us_east_1) == 3,
      one([for rule in values(aws_vpc_security_group_egress_rule.us_east_1) : rule if rule.ip_protocol == "tcp" && rule.from_port == 443]).cidr_ipv4 == "0.0.0.0/0",
      one([for rule in values(aws_vpc_security_group_egress_rule.us_east_1) : rule if rule.ip_protocol == "udp" && rule.from_port == 53]).to_port == 53,
      one([for rule in values(aws_vpc_security_group_egress_rule.us_east_1) : rule if rule.ip_protocol == "tcp" && rule.from_port == 53]).to_port == 53,
    ])
    error_message = "Interface-owned egress rules must materialize with stable content-derived addresses and exact ports."
  }

  assert {
    condition     = contains(aws_network_interface.us_east_1["managed-sg-host-eni-0"].security_groups, aws_security_group.us_east_1["managed-sg-host-eni-0-sg"].id)
    error_message = "The interface security group must attach automatically when the explicit security_groups list is empty."
  }
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
