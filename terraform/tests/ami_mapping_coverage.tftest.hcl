# The instance precondition that closes the gap ami_block_device_overrides leaves open: the
# consumer declares overrides by hand, and an AMI mapping they forget is created by RunInstances
# with the source snapshot's own encryption state. These runs drive data.aws_ami through
# override_data so the AMI's block_device_mappings are known at plan time, which is exactly why
# the guard is a resource precondition and not a variable validation.

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
}

# A CIS/STIG-shaped AMI: an encrypted root plus a second mapping the image ships unencrypted.
override_data {
  target = data.aws_ami.us_east_1_verified["test-linux"]
  values = {
    state            = "available"
    id               = "ami-00000000000000042"
    platform         = ""
    platform_details = "Red Hat Enterprise Linux"
    root_device_name = "/dev/sda1"
    block_device_mappings = [
      {
        device_name  = "/dev/sda1"
        no_device    = ""
        virtual_name = ""
        ebs = {
          snapshot_id = "snap-00000000000000001"
          volume_size = "100"
          encrypted   = "true"
        }
      },
      {
        device_name  = "/dev/sdf"
        no_device    = ""
        virtual_name = ""
        ebs = {
          snapshot_id = "snap-00000000000000002"
          volume_size = "40"
          encrypted   = "false"
        }
      },
      # Instance store: no EBS volume exists to encrypt, so the guard must ignore it.
      {
        device_name  = "/dev/sdb"
        no_device    = ""
        virtual_name = "ephemeral0"
        ebs          = {}
      },
    ]
  }
}

run "uncovered_ami_mapping_fails_the_instance_precondition" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "ami-uncovered"
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
          Function = "Uncovered AMI mapping"
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

        # /dev/sdf is left uncovered on purpose - this is the encryption hole.
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
      }
    ]
  }

  expect_failures = [
    aws_instance.us_east_1["ami-uncovered"],
  ]
}

run "covering_every_mapping_satisfies_the_precondition" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "ami-covered"
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
          Function = "Covered AMI mapping"
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

        # The root device and the ephemeral mapping need no entry; only /dev/sdf does.
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
      }
    ]
  }

  assert {
    condition     = length(local.elastic_compute_cloud.us_east_1["ami-covered"].uncovered_ami_block_devices) == 0
    error_message = "A system covering every non-root AMI mapping must leave nothing uncovered."
  }
}

run "refresh_instances_are_guarded_on_the_same_terms" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "ami-uncovered-refresh"
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
          Function = "Uncovered AMI mapping on the refresh path"
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

  expect_failures = [
    aws_instance.us_east_1_refresh["ami-uncovered-refresh"],
  ]
}
