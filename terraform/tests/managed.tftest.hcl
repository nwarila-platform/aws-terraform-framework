mock_provider "aws" {
  alias = "us_west_2"
}

mock_provider "aws" {
  alias = "us_east_1"
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

      tags = {
        Function = "wazuh-shaped baseline system"
      }

      network_interfaces = [
        {
          private_ip      = "10.0.0.10"
          security_groups = ["sg-preexisting"]
        }
      ]
    }
  ]
}

run "wazuh_preexisting_shape_is_zero_diff" {
  command = plan

  assert {
    condition     = length(aws_key_pair.us_west_2) == 0 && length(aws_key_pair.us_east_1) == 0
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
    condition     = length(aws_security_group.us_west_2) == 0 && length(aws_security_group.us_east_1) == 0 && length(aws_vpc_security_group_ingress_rule.us_east_1) == 0 && length(aws_vpc_security_group_egress_rule.us_east_1) == 0
    error_message = "With managed_security_groups unset, the framework must create zero security groups and zero rules."
  }
}

run "managed_key_pair_created_from_public_key" {
  command = plan

  variables {
    managed_keypairs = {
      "managed-key" = {
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderPublicKeyMaterialForPlanOnly deploy@e2e"
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

        tags = {
          Function = "System using a framework-managed key pair"
        }

        network_interfaces = [
          {
            private_ip      = "10.0.0.11"
            security_groups = ["sg-preexisting"]
          }
        ]
      }
    ]
  }

  assert {
    condition     = aws_key_pair.us_east_1["managed-key"].public_key != "" && aws_key_pair.us_west_2["managed-key"].public_key != ""
    error_message = "Managed key pairs must be created in both supported regions."
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
        public_key = "-----BEGIN RSA PRIVATE KEY----- oops"
      }
    }
  }

  expect_failures = [var.managed_keypairs]
}

run "managed_sg_zero_inbound_with_ssm_egress" {
  command = plan

  variables {
    managed_security_groups = {
      "wsus-ssm" = {
        region  = "us_east_1"
        vpc_id  = "vpc-preexisting"
        ingress = []
        egress = [
          { description = "SSM/HTTPS", ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" },
          { description = "DNS udp", ip_protocol = "udp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0" },
          { description = "DNS tcp", ip_protocol = "tcp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0" },
        ]
      }
    }

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

        tags = {
          Function = "Zero-inbound SSM system on a managed security group"
        }

        network_interfaces = [
          {
            private_ip      = "10.0.0.12"
            security_groups = ["wsus-ssm"]
          }
        ]
      }
    ]
  }

  assert {
    condition     = contains(keys(aws_security_group.us_east_1), "wsus-ssm") && length(aws_security_group.us_west_2) == 0
    error_message = "Managed security groups must be created only in their declared region."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.us_east_1) == 0
    error_message = "A managed group declaring no ingress must create zero ingress rules (zero-inbound posture)."
  }

  assert {
    condition = alltrue([
      length(aws_vpc_security_group_egress_rule.us_east_1) == 3,
      aws_vpc_security_group_egress_rule.us_east_1["wsus-ssm/egress-0"].cidr_ipv4 == "0.0.0.0/0",
      aws_vpc_security_group_egress_rule.us_east_1["wsus-ssm/egress-0"].from_port == 443,
      aws_vpc_security_group_egress_rule.us_east_1["wsus-ssm/egress-1"].ip_protocol == "udp",
      aws_vpc_security_group_egress_rule.us_east_1["wsus-ssm/egress-1"].from_port == 53,
      aws_vpc_security_group_egress_rule.us_east_1["wsus-ssm/egress-2"].ip_protocol == "tcp",
    ])
    error_message = "Declared egress rules must materialize with stable <sg>/egress-<index> addresses and exact ports."
  }
}

run "managed_sg_rejects_rule_without_exactly_one_destination" {
  command = plan

  variables {
    managed_security_groups = {
      "bad-sg" = {
        region = "us_east_1"
        vpc_id = "vpc-preexisting"
        egress = [
          { description = "no destination", ip_protocol = "tcp", from_port = 443, to_port = 443 },
        ]
      }
    }
  }

  expect_failures = [var.managed_security_groups]
}

run "managed_sg_rejects_all_protocol_with_ports" {
  command = plan

  variables {
    managed_security_groups = {
      "bad-sg" = {
        region = "us_east_1"
        vpc_id = "vpc-preexisting"
        egress = [
          { ip_protocol = "-1", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" },
        ]
      }
    }
  }

  expect_failures = [var.managed_security_groups]
}
