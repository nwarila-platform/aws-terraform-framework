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
      hostname             = "vols01"
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
        Function = "volume identity host"
        Backup   = true
      }

      ebs_block_devices = [
        {
          resource_key = "logs"
          device_index = 0
          volume_size  = "20"
          tags         = { Function = "wsusdb" }
          iops         = null
          snapshot_id  = null
          throughput   = null
          volume_type  = "gp3"
        },
        {
          resource_key = "data"
          device_index = 1
          volume_size  = "30"
          iops         = null
          snapshot_id  = null
          tags         = {}
          throughput   = null
          volume_type  = "gp3"
        }
      ]

      root_block_device = {
        iops        = null
        tags        = {}
        throughput  = null
        volume_type = "gp3"
        volume_size = "100"
      }

      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.20"
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

run "ebs_volumes_output_shape" {
  command = plan

  assert {
    condition     = sort(keys(output.ebs_volumes)) == sort(["vols01-ebs-logs", "vols01-ebs-data"])
    error_message = "ebs_volumes must be keyed exactly like the aws_ebs_volume resources (<hostname>-ebs-<resource_key>)."
  }

  assert {
    condition     = output.ebs_volumes["vols01-ebs-logs"].function == "wsusdb"
    error_message = "ebs_volumes must surface the authored Function tag for tagged volumes."
  }

  assert {
    condition     = output.ebs_volumes["vols01-ebs-logs"].device_name == "/dev/sdd" && output.ebs_volumes["vols01-ebs-data"].device_name == "/dev/sde"
    error_message = "ebs_volumes must surface the DeviceName tag from each stable device index."
  }

  assert {
    condition     = output.ebs_volumes["vols01-ebs-logs"].hostname == "vols01"
    error_message = "ebs_volumes must surface the owning hostname from the Name tag."
  }
}

run "ebs_volumes_output_tolerates_missing_function_tag" {
  command = plan

  assert {
    condition     = output.ebs_volumes["vols01-ebs-data"].function == null
    error_message = "Volumes without a Function tag (the secure-wazuh shape) must yield function = null, not an error."
  }
}

# The output must hand back a POINTER to the AWS-owned secret and never the credential itself,
# matching get_password_data = false on Windows instances.
run "databases_output_exposes_secret_pointer_not_password" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "outputsdb"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        instance_class                      = "db.t3.micro"
        username                            = "dbadmin"
        aws_kms_alias                       = "test"
        manage_master_user_password         = true

        vpc_security_group_ids   = ["sg-01234567"]
        allocated_storage        = "100"
        backup_retention_period  = null
        backup_window            = null
        blue_green_update        = false
        ca_cert_identifier       = null
        dedicated_log_volume     = true
        delete_automated_backups = true
        deletion_protection      = true
        max_allocated_storage    = "1000"
        skip_final_snapshot      = false
        storage_type             = "gp3"

        tags = {
          Backup   = true
          Function = "Outputs fixture"
        }
      }
    ]
  }

  assert {
    condition     = contains(keys(output.aws_databases), "outputsdb")
    error_message = "aws_databases must be keyed by db_name like the aws_db_instance resources."
  }

  assert {
    condition = alltrue([
      for field in ["address", "identifier", "master_user_secret_arn", "port"] :
      contains(keys(output.aws_databases["outputsdb"]), field)
    ])
    error_message = "aws_databases must expose address, identifier, master_user_secret_arn and port."
  }

  assert {
    condition = !anytrue([
      for field in keys(output.aws_databases["outputsdb"]) : strcontains(lower(field), "password")
    ])
    error_message = "aws_databases must never expose a password field; only the secret ARN pointer."
  }
}
