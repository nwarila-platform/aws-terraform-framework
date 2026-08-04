mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_kms_alias" {
    defaults = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["111122", "223333"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
    }
  }
}

variables {
  environment = "TEST"

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "ami-zero"
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
        Function = "AMI override zero path"
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
          private_ip      = "10.0.20.10"
          security_groups = ["sg-01234567"]
          description     = null
          interface_type  = null
          ingress         = null
          egress          = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    },
    {
      region               = "us_east_1"
      hostname             = "ami-override"
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
        Function = "AMI override normal path"
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
      ami_block_device_overrides = [
        {
          delete_on_termination = true
          device_name           = "/dev/sdf"
          iops                  = null
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "40"
        }
      ]

      network_interfaces = [
        {
          private_ip      = "10.0.20.11"
          security_groups = ["sg-01234567"]
          description     = null
          interface_type  = null
          ingress         = null
          egress          = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    },
    {
      region               = "us_east_1"
      hostname             = "ami-override-refresh"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

      refresh        = true
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1
      set_state      = null

      tags = {
        Function = "AMI override refresh path"
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
      ami_block_device_overrides = [
        {
          delete_on_termination = true
          device_name           = "/dev/sdf"
          iops                  = null
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "40"
        }
      ]

      network_interfaces = [
        {
          private_ip      = "10.0.20.12"
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

run "empty_overrides_render_zero_ebs_block_device_blocks" {
  command = plan

  assert {
    condition     = length(aws_instance.us_east_1["ami-zero"].ebs_block_device) == 0
    error_message = "ami_block_device_overrides = [] must render zero inline ebs_block_device blocks."
  }
}

run "single_override_renders_encrypted_ebs_block_device" {
  command = plan

  assert {
    condition = alltrue([
      length(aws_instance.us_east_1["ami-override"].ebs_block_device) == 1,
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).device_name == "/dev/sdf",
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).encrypted == true,
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).volume_type == "gp3",
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).volume_size == 40,
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).iops == null,
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).throughput == null,
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).delete_on_termination == true,
    ])
    error_message = "A single AMI override must render one encrypted inline block with all authored properties."
  }
}

run "refresh_override_matches_normal_override" {
  command = plan

  assert {
    condition = alltrue([
      for field in ["device_name", "encrypted", "kms_key_id", "volume_type", "volume_size", "iops", "throughput", "delete_on_termination"] :
      one(aws_instance.us_east_1["ami-override"].ebs_block_device)[field] == one(aws_instance.us_east_1_refresh["ami-override-refresh"].ebs_block_device)[field]
    ])
    error_message = "The refresh instance must render the same AMI override properties as the normal instance."
  }
}

run "override_rejects_standalone_volume_device_collision" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "ami-collision"
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
          Function = "AMI override collision validation"
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

        ebs_block_devices = [
          {
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
            volume_size  = "20"
          }
        ]
        ami_block_device_overrides = [
          {
            delete_on_termination = true
            device_name           = "/dev/sdd"
            iops                  = null
            throughput            = null
            volume_type           = "gp3"
            volume_size           = "40"
          }
        ]

        network_interfaces = [
          {
            private_ip      = "10.0.20.13"
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

  expect_failures = [var.all_systems]
}

run "override_rejects_duplicate_device_names" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "ami-duplicate"
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
          Function = "AMI override duplicate validation"
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
        ami_block_device_overrides = [
          {
            delete_on_termination = true
            device_name           = "/dev/sdf"
            iops                  = null
            throughput            = null
            volume_type           = "gp3"
            volume_size           = "40"
          },
          {
            delete_on_termination = true
            device_name           = "/dev/sdf"
            iops                  = null
            throughput            = null
            volume_type           = "gp3"
            volume_size           = "40"
          }
        ]

        network_interfaces = [
          {
            private_ip      = "10.0.20.14"
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

  expect_failures = [var.all_systems]
}
