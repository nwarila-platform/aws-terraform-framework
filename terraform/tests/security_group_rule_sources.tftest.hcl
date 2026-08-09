mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_subnet" {
    defaults = {
      vpc_id            = "vpc-fromsubnetlookup"
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
    }
  }
}

variables {
  repository    = "nwarila-platform/aws-terraform-framework"
  repository_id = "123456789"
  commit_sha    = "0123456789abcdef0123456789abcdef01234567"
  run_id        = "42"
  environment   = "test"

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "rule-source-host"
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
      readiness_gate             = false
      imds_hop_limit             = 1
      set_state                  = null

      tags = {
        Function = "Security-group rule source validation"
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

      ebs_block_devices          = []
      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.91"
          security_groups = []
          description     = "Source validation group."
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

run "inline_ingress_rule_rejects_a_missing_source" {
  command = plan

  variables {
    all_systems = [
      for system in var.all_systems : merge(system, {
        network_interfaces = [
          for nic in system.network_interfaces : merge(nic, {
            ingress = [
              {
                description                  = "Missing source"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_systems]
}

run "inline_egress_rule_rejects_multiple_sources" {
  command = plan

  variables {
    all_systems = [
      for system in var.all_systems : merge(system, {
        network_interfaces = [
          for nic in system.network_interfaces : merge(nic, {
            egress = [
              {
                description                  = "Multiple sources"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = "10.0.0.0/8"
                prefix_list_id               = "pl-0123456789abcdef0"
                referenced_security_group_id = null
              }
            ]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_systems]
}
