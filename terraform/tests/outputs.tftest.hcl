mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_kms_alias" {
    defaults = {
      target_key_arn = "arn:aws:kms:us-east-1:111122223333:key/00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  environment = "TEST"

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "vols01"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

      tags = {
        Function = "volume identity host"
      }

      ebs_block_devices = [
        {
          volume_size = "20"
          tags        = { Function = "wsusdb" }
        },
        {
          volume_size = "30"
        }
      ]

      network_interfaces = [
        {
          private_ip      = "10.0.0.20"
          security_groups = ["sg-preexisting"]
        }
      ]
    }
  ]
}

run "ebs_volumes_output_shape" {
  command = plan

  assert {
    condition     = sort(keys(output.ebs_volumes)) == sort(["vols01-ebs-0", "vols01-ebs-1"])
    error_message = "ebs_volumes must be keyed exactly like the aws_ebs_volume resources (<hostname>-ebs-<index>)."
  }

  assert {
    condition     = output.ebs_volumes["vols01-ebs-0"].function == "wsusdb"
    error_message = "ebs_volumes must surface the authored Function tag for tagged volumes."
  }

  assert {
    condition     = output.ebs_volumes["vols01-ebs-0"].device_name == "/dev/sdd" && output.ebs_volumes["vols01-ebs-1"].device_name == "/dev/sde"
    error_message = "ebs_volumes must surface the authored DeviceName tag (d..z indexing)."
  }

  assert {
    condition     = output.ebs_volumes["vols01-ebs-0"].hostname == "vols01"
    error_message = "ebs_volumes must surface the owning hostname from the Name tag."
  }
}

run "ebs_volumes_output_tolerates_missing_function_tag" {
  command = plan

  assert {
    condition     = output.ebs_volumes["vols01-ebs-1"].function == null
    error_message = "Volumes without a Function tag (the secure-wazuh shape) must yield function = null, not an error."
  }
}
