mock_provider "aws" {
  alias = "us_east_1"

  # The verified-image lookup asserts state; unmocked attributes come back as random
  # strings, so the default has to say what a healthy image looks like.
  mock_data "aws_ami" {
    defaults = {
      state = "available"
    }
  }

  # The ENI preconditions read the real subnet, so the mock has to return something coherent:
  # a CIDR wide enough to contain every fixture address (10.0-10.2) and the zone the fixtures
  # declare. Individual runs override this where they need a different subnet.
  mock_data "aws_subnet" {
    defaults = {
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
      vpc_id            = "vpc-00000000000000001"
    }
  }

  mock_data "aws_kms_alias" {
    defaults = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["111122", "223333"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
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
      hostname             = "ami-zero"
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
        Function = "AMI override zero path"
        Backup   = true
      }

      root_block_device = {
        iops        = null
        tags        = {}
        throughput  = null
        volume_type = "gp3"
        volume_size = "100"
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
        Function = "AMI override normal path"
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
      ami_block_device_overrides = [
        {
          device_name = "/dev/sdf"
          iops        = null
          throughput  = null
          volume_type = "gp3"
          volume_size = "40"
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

      refresh                    = true
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
        Function = "AMI override refresh path"
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
      ami_block_device_overrides = [
        {
          device_name = "/dev/sdf"
          iops        = null
          throughput  = null
          volume_type = "gp3"
          volume_size = "40"
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

# aws_instance.ebs_block_device is a SET whose members carry provider-computed attributes
# (iops, throughput, volume_id). Any member left unset in configuration is unknown until
# apply, and a set with an unknown member cannot be indexed - one() and [*] both fail with
# "Unknown condition value" under command = plan. Only the set's length is knowable there.
# So each run asserts length against the resource (proving the dynamic block rendered the
# right number of inline blocks) and asserts the property values against the normalized
# local that feeds it, which is a list and fully known at plan time.
run "single_override_renders_encrypted_ebs_block_device" {
  command = plan

  assert {
    condition     = length(aws_instance.us_east_1["ami-override"].ebs_block_device) == 1
    error_message = "A single AMI override must render exactly one inline ebs_block_device block."
  }

  assert {
    condition = alltrue([
      length(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides) == 1,
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides).device_name == "/dev/sdf",
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides).kms_key_id == "preexisting",
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides).volume_type == "gp3",
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides).volume_size == "40",
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides).iops == null,
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides).throughput == null,
    ])
    error_message = "A single AMI override must normalize to one block carrying every consumer-authored property and the system's KMS alias."
  }

  # These volumes carried no tags at all until the identity map was added, so every
  # ec2:ResourceTag-scoped grant for DeleteVolume, DetachVolume and ModifyVolume missed them and
  # an identity-based reaper could not find them after a failed run.
  assert {
    condition = alltrue([
      for key, expected in {
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        DeviceName   = "/dev/sdf"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Name         = "ami-override"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        RunId        = "42"
      } :
      one(aws_instance.us_east_1["ami-override"].ebs_block_device).tags[key] == expected
    ])
    error_message = "A volume created from an AMI override must carry the deployment identity plus its own device name."
  }
}

run "refresh_override_matches_normal_override" {
  command = plan

  assert {
    condition = alltrue([
      for field in ["device_name", "kms_key_id", "volume_type", "volume_size", "iops", "throughput"] :
      one(local.elastic_compute_cloud.us_east_1["ami-override"].ami_block_device_overrides)[field] ==
      one(local.elastic_compute_cloud.us_east_1["ami-override-refresh"].ami_block_device_overrides)[field]
    ])
    error_message = "The refresh instance must normalize the same AMI override properties as the normal instance."
  }

  assert {
    condition = (
      length(aws_instance.us_east_1_refresh["ami-override-refresh"].ebs_block_device) ==
      length(aws_instance.us_east_1["ami-override"].ebs_block_device)
    )
    error_message = "The refresh instance must render the same number of inline ebs_block_device blocks as the normal instance."
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
          Function = "AMI override collision validation"
          Backup   = true
        }

        root_block_device = {
          iops        = null
          tags        = {}
          throughput  = null
          volume_type = "gp3"
          volume_size = "100"
        }

        ebs_block_devices = [
          {
            resource_key = "data"
            device_index = 0
            iops         = null
            snapshot_id  = null
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
            volume_size  = "20"
          }
        ]
        ami_block_device_overrides = [
          {
            device_name = "/dev/sdd"
            iops        = null
            throughput  = null
            volume_type = "gp3"
            volume_size = "40"
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
          Function = "AMI override duplicate validation"
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
        ami_block_device_overrides = [
          {
            device_name = "/dev/sdf"
            iops        = null
            throughput  = null
            volume_type = "gp3"
            volume_size = "40"
          },
          {
            device_name = "/dev/sdf"
            iops        = null
            throughput  = null
            volume_type = "gp3"
            volume_size = "40"
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

run "inline_ami_override_blocks_are_encrypted_and_deleted_on_termination" {
  command = apply

  # The length check keeps alltrue() from passing vacuously if the override ever stops rendering
  # an inline block. Both lifecycle values are module-owned and must reach the resource itself.
  assert {
    condition = (
      length(aws_instance.us_east_1["ami-override"].ebs_block_device) == 1 &&
      alltrue([
        for device in aws_instance.us_east_1["ami-override"].ebs_block_device :
        device.encrypted && device.delete_on_termination
      ])
    )
    error_message = "Every normal instance AMI override block must enable encryption and deletion on termination."
  }

  assert {
    condition = (
      length(aws_instance.us_east_1_refresh["ami-override-refresh"].ebs_block_device) == 1 &&
      alltrue([
        for device in aws_instance.us_east_1_refresh["ami-override-refresh"].ebs_block_device :
        device.encrypted && device.delete_on_termination
      ])
    )
    error_message = "Every refresh instance AMI override block must enable encryption and deletion on termination."
  }
}
