mock_provider "aws" {
  alias = "us_east_1"

  # The verified-image lookup asserts state; unmocked attributes come back as random
  # strings, so the default has to say what a healthy image looks like.
  mock_data "aws_ami" {
    defaults = {
      state = "available"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      vpc_id            = "vpc-preexisting"
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
    }
  }
}

# secure-wazuh-shaped baseline: a plain Linux system that references only pre-existing
# infrastructure and sets both interface rule collections to null. It is the mechanical guarantee
# that this explicit pre-created-group path creates no additional resources and preserves existing
# resource keys.
variables {
  repository    = "nwarila-platform/aws-terraform-framework"
  repository_id = "123456789"
  commit_sha    = "0123456789abcdef0123456789abcdef01234567"
  run_id        = "42"
  environment   = "test"

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

      refresh                    = false
      instance_type              = "m6i.large"
      connection_type            = null
      readiness_user             = null
      readiness_command          = null
      readiness_script_dir       = null
      readiness_private_key_path = null
      readiness_gate             = true
      imds_hop_limit             = 1
      set_state                  = null

      tags = {
        Function = "wazuh-shaped baseline system"
        Backup   = true
      }

      root_block_device = {
        iops        = null
        tags        = {}
        throughput  = null
        volume_type = "gp3"
        volume_size = "100"
      }

      ebs_block_devices = []

      ami_block_device_overrides = []

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

  # Lookups are scoped to what this region actually deploys, and deduplicated by selector: one
  # system on one image is one catalog read and one image verification, never more.
  assert {
    condition     = length(data.aws_ssm_parameter.us_east_1_ami) == 1 && length(data.aws_ami.us_east_1_verified) == 1
    error_message = "A single-system config on one catalog selector must produce exactly one parameter read and one verified-image lookup."
  }

  assert {
    condition     = length(data.aws_subnet.us_east_1) == 1
    error_message = "Every system's subnet is read exactly once, deduplicated by id, whether or not it declares an interface-owned group."
  }

  assert {
    condition     = length(aws_eip.us_east_1) == 0 && length(aws_eip_association.us_east_1) == 0
    error_message = "This framework creates no networking; without associate_public_ip it must not even allocate an Elastic IP."
  }
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

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        set_state                  = null

        tags = {
          Function = "Zero-inbound SSM system on a managed security group"
          Backup   = true
        }

        root_block_device = {
          iops        = null
          tags        = {}
          throughput  = null
          volume_type = "gp3"
          volume_size = "100"
        }

        ebs_block_devices = []

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.12"
            security_groups = []
            description     = "Managed by aws-terraform-framework"
            interface_type  = null
            ingress         = []
            egress = [
              { description = "SSM/HTTPS", ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0", prefix_list_id = null, referenced_security_group_id = null },
              { description = "DNS udp", ip_protocol = "udp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0", prefix_list_id = null, referenced_security_group_id = null },
              { description = "DNS tcp", ip_protocol = "tcp", from_port = 53, to_port = 53, cidr_ipv4 = "0.0.0.0/0", prefix_list_id = null, referenced_security_group_id = null },
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

run "literal_byo_subnet_plans_eip_and_association" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "literal-byo-eip-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"
        associate_public_ip  = true

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "Public IP on a literal BYO subnet"
          Backup   = true
        }

        root_block_device = {
          iops        = null
          tags        = {}
          throughput  = null
          volume_type = "gp3"
          volume_size = "100"
        }

        ebs_block_devices = []

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.13"
            security_groups = ["sg-01234567"]
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            tags            = {}
          }
        ]
      }
    ]
  }

  override_resource {
    target          = aws_eip.us_east_1
    override_during = plan

    values = {
      id = "eipalloc-literal-byo-eip-host"
    }
  }

  override_resource {
    target          = aws_network_interface.us_east_1
    override_during = plan

    values = {
      id = "eni-literal-byo-eip-host-primary"
    }
  }

  assert {
    condition = alltrue([
      aws_eip.us_east_1["literal-byo-eip-host"].domain == "vpc",
      aws_eip.us_east_1["literal-byo-eip-host"].tags["Name"] == "literal-byo-eip-host",
      aws_eip.us_east_1["literal-byo-eip-host"].tags["Environment"] == "test",
      aws_eip.us_east_1["literal-byo-eip-host"].tags["ManagedBy"] == "Terraform",
    ])
    error_message = "A literal BYO subnet with associate_public_ip = true must plan the hostname-keyed VPC EIP with its concrete tags."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_eip.us_east_1["literal-byo-eip-host"].tags[key] == {
        Name         = "literal-byo-eip-host"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "42"
      }[key]
    ])
    error_message = "The EIP tags must carry all seven deployment-identity keys verbatim."
  }

  assert {
    condition = alltrue([
      aws_eip_association.us_east_1["literal-byo-eip-host"].allocation_id == "eipalloc-literal-byo-eip-host",
      aws_eip_association.us_east_1["literal-byo-eip-host"].network_interface_id == "eni-literal-byo-eip-host-primary",
    ])
    error_message = "A literal BYO subnet EIP association must plan against that EIP and the system's primary ENI."
  }
}
