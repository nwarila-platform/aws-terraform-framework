mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  environment = "TEST"

  all_systems = [
    {
      region               = "us-east-1"
      hostname             = "west-state"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-west-a"
      key_name             = "west-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "west"
      ami                  = "test-linux"
      set_state            = "stopped"

      refresh        = false
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1

      tags = {
        Function = "West instance with state control"
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
          security_groups = ["sg-west"]
          description     = null
          interface_type  = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    },
    {
      region               = "us_east_1"
      hostname             = "west-no-state"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-west-b"
      key_name             = "west-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "west"
      ami                  = "test-linux"

      refresh        = false
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1
      set_state      = null

      tags = {
        Function = "West instance without state control"
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
          security_groups = ["sg-west"]
          description     = null
          interface_type  = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    },
    {
      region               = "us-east-1"
      hostname             = "west-refresh"
      availability_zone    = "us-east-1b"
      subnet_id            = "subnet-west-c"
      key_name             = "west-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "west"
      ami                  = "test-linux"
      refresh              = true

      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1
      set_state      = null

      tags = {
        Function = "West refresh instance"
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
          security_groups = ["sg-west"]
          description     = null
          interface_type  = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    },
    {
      region               = "us-east-1"
      hostname             = "east-state"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-east-a"
      key_name             = "east-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "east"
      ami                  = "test-linux"
      set_state            = "running"

      refresh        = false
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1

      tags = {
        Function = "East instance with state control"
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
          private_ip      = "10.1.0.10"
          security_groups = ["sg-east"]
          description     = null
          interface_type  = null
          tags            = {}
        }
      ]

      associate_public_ip = false
    }
  ]
}

run "instance_state_created_only_when_set_state_is_not_null" {
  command = plan

  assert {
    condition     = length(aws_ec2_instance_state.us_east_1) == 2
    error_message = "The supported region should create state controls only for instances with set_state."
  }

  assert {
    condition     = contains(keys(aws_ec2_instance_state.us_east_1), "west-state")
    error_message = "west-state should have an aws_ec2_instance_state resource."
  }

  assert {
    condition     = !contains(keys(aws_ec2_instance_state.us_east_1), "west-no-state")
    error_message = "west-no-state must not create aws_ec2_instance_state with a null state."
  }

  assert {
    condition     = aws_ec2_instance_state.us_east_1["west-state"].state == "stopped"
    error_message = "west-state should preserve the requested stopped state."
  }

  assert {
    condition     = aws_ec2_instance_state.us_east_1["east-state"].state == "running"
    error_message = "east-state should preserve the requested running state."
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].iam_instance_profile != null
    error_message = "west-state should attach an IAM instance profile."
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].tags["ManagedBy"] == "Terraform" && aws_instance.us_east_1_refresh["west-refresh"].tags["ManagedBy"] == "Terraform" && aws_instance.us_east_1["east-state"].tags["ManagedBy"] == "Terraform"
    error_message = "EC2 instances should carry a non-overwritable ManagedBy=Terraform discovery tag."
  }

  assert {
    condition = alltrue(concat(
      [for _, instance in aws_instance.us_east_1 : instance.root_block_device[0].encrypted == true],
      [for _, instance in aws_instance.us_east_1_refresh : instance.root_block_device[0].encrypted == true],
    ))
    error_message = "Every planned EC2 root block device should set encrypted = true."
  }

}

run "backup_tags_normalize_for_ec2_and_rds_and_database_storage_defaults_to_gp3" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "backup-default"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-backup-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Backup default EC2"
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
            private_ip      = "10.0.12.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "backup-disabled"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-backup-disabled"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Backup   = false
          Function = "Backup disabled EC2"
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
            private_ip      = "10.0.12.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]

    all_databases = [
      {
        region                 = "us-east-1"
        availability_zone      = "us-east-1a"
        db_name                = "backupdefaultdb"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        aws_kms_alias          = "west"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Function = "Backup default database"
          Backup   = true
        }
        password                    = null
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      },
      {
        region                 = "us-east-1"
        availability_zone      = "us-east-1a"
        db_name                = "backupdisableddb"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        aws_kms_alias          = "west"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Backup   = false
          Function = "Backup disabled database"
        }
        password                    = null
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000012"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = local.elastic_compute_cloud.us_east_1["backup-default"].tags["Backup"] == "True" && aws_instance.us_east_1["backup-default"].tags["Backup"] == "True"
    error_message = "EC2 Backup should default to the normalized string True."
  }

  assert {
    condition     = local.elastic_compute_cloud.us_east_1["backup-disabled"].tags["Backup"] == "False" && aws_instance.us_east_1["backup-disabled"].tags["Backup"] == "False"
    error_message = "EC2 Backup=false should normalize to the string False."
  }

  assert {
    condition     = local.relational_database_service.us_east_1["backupdefaultdb"].tags["Backup"] == "True" && aws_db_instance.us_east_1["backupdefaultdb"].tags["Backup"] == "True"
    error_message = "RDS Backup should default to the normalized string True."
  }

  assert {
    condition     = local.relational_database_service.us_east_1["backupdisableddb"].tags["Backup"] == "False" && aws_db_instance.us_east_1["backupdisableddb"].tags["Backup"] == "False"
    error_message = "RDS Backup=false should normalize to the string False."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_east_1["backup-default"].tags["Backup"] == local.relational_database_service.us_east_1["backupdefaultdb"].tags["Backup"],
      local.elastic_compute_cloud.us_east_1["backup-disabled"].tags["Backup"] == local.relational_database_service.us_east_1["backupdisableddb"].tags["Backup"],
    ])
    error_message = "EC2 and RDS Backup tags should emit identical True/False casing."
  }

  assert {
    condition     = local.relational_database_service.us_east_1["backupdefaultdb"].storage_type == "gp3" && aws_db_instance.us_east_1["backupdefaultdb"].storage_type == "gp3"
    error_message = "RDS storage_type should default to gp3 when omitted."
  }

  assert {
    condition     = alltrue([for _, database in aws_db_instance.us_east_1 : database.storage_encrypted == true])
    error_message = "Every planned RDS database should set storage_encrypted = true."
  }
}

run "instance_state_includes_refresh_instances_after_readiness" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "west-refresh-state"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-refresh-state"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        refresh              = true
        set_state            = "stopped"

        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1

        tags = {
          Function = "West refresh instance with state control"
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
            security_groups = ["sg-west"]
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
    condition     = contains(keys(aws_instance.us_east_1_refresh), "west-refresh-state")
    error_message = "west-refresh-state should plan as a refresh instance."
  }

  assert {
    condition     = contains(keys(aws_ec2_instance_state.us_east_1), "west-refresh-state")
    error_message = "west-refresh-state should have an aws_ec2_instance_state resource even though it is refresh=true."
  }

  assert {
    condition     = aws_ec2_instance_state.us_east_1["west-refresh-state"].state == "stopped"
    error_message = "west-refresh-state should preserve the requested stopped state."
  }
}

run "aws_instances_output_exposes_non_secret_inventory" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "inv-linux-west"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-inventory-linux"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inventory Linux"
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
            private_ip      = "10.0.9.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "inv-win-east"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-inventory-windows"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "windows_server_2025_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inventory Windows"
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
            private_ip      = "10.1.9.10"
            security_groups = ["sg-east"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "inv-refresh"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-west-inventory-refresh"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        refresh              = true

        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Inventory Refresh"
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
            private_ip      = "10.0.9.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000001"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_windows_server_2025_base[0]
    values = {
      id               = "ami-00000000000000002"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  assert {
    condition     = contains(keys(output.aws_instances), "inv-linux-west")
    error_message = "aws_instances output should include the normal Linux hostname key."
  }

  assert {
    condition     = contains(keys(output.aws_instances), "inv-win-east")
    error_message = "aws_instances output should include the Windows hostname key."
  }

  assert {
    condition     = contains(keys(output.aws_instances), "inv-refresh")
    error_message = "aws_instances output should include the refresh hostname key."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-linux-west"].hostname == "inv-linux-west",
      output.aws_instances["inv-linux-west"].region == "us_east_1",
      output.aws_instances["inv-linux-west"].function == "Inventory Linux",
      output.aws_instances["inv-linux-west"].os_family == "linux",
      output.aws_instances["inv-linux-west"].environment == "TEST",
    ])
    error_message = "Linux inventory entries should expose plan-known target facts."
  }

  assert {
    condition = alltrue([
      for field in ["instance_id", "private_ip", "private_dns"] :
      contains(keys(output.aws_instances["inv-linux-west"]), field)
    ])
    error_message = "Linux inventory entries should include apply-known target fact keys."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-win-east"].hostname == "inv-win-east",
      output.aws_instances["inv-win-east"].region == "us_east_1",
      output.aws_instances["inv-win-east"].function == "Inventory Windows",
      output.aws_instances["inv-win-east"].os_family == "windows",
      output.aws_instances["inv-win-east"].environment == "TEST",
    ])
    error_message = "Windows inventory entries should expose plan-known target facts."
  }

  assert {
    condition = alltrue([
      for field in ["instance_id", "private_ip", "private_dns"] :
      contains(keys(output.aws_instances["inv-win-east"]), field)
    ])
    error_message = "Windows inventory entries should include apply-known target fact keys."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-refresh"].hostname == "inv-refresh",
      output.aws_instances["inv-refresh"].region == "us_east_1",
      output.aws_instances["inv-refresh"].function == "Inventory Refresh",
      output.aws_instances["inv-refresh"].os_family == "linux",
      output.aws_instances["inv-refresh"].environment == "TEST",
    ])
    error_message = "Refresh inventory entries should expose plan-known target facts."
  }

  assert {
    condition = alltrue([
      for name in ["inv-linux-west", "inv-win-east", "inv-refresh"] :
      length(setsubtract(toset(keys(output.aws_instances[name])), toset(["hostname", "instance_id", "region", "private_ip", "private_dns", "function", "os_family", "environment"]))) == 0 &&
      length(setsubtract(toset(["hostname", "instance_id", "region", "private_ip", "private_dns", "function", "os_family", "environment"]), toset(keys(output.aws_instances[name])))) == 0
    ])
    error_message = "Inventory entries should expose exactly the neutral EC2 hand-off fields."
  }

  assert {
    condition = alltrue([
      for field in ["instance_id", "private_ip", "private_dns"] :
      contains(keys(output.aws_instances["inv-refresh"]), field)
    ])
    error_message = "Refresh inventory entries should include apply-known target fact keys."
  }

  assert {
    condition     = !contains(keys(output.aws_instances["inv-linux-west"]), "platform") && !contains(keys(output.aws_instances["inv-linux-west"]), "name")
    error_message = "aws_instances should replace the old platform/name fields with os_family/hostname."
  }
}

run "ebs_volume_attachments_use_structured_wiring" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "west-ebs"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-ebs"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "West EBS"
          Backup   = true
        }

        ebs_block_devices = [
          {
            volume_size  = "125"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          },
          {
            volume_size  = "250"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          },
          {
            skip_destroy = true
            volume_size  = "500"
            iops         = null
            snapshot_id  = null
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          }
        ]

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        network_interfaces = [
          {
            private_ip      = "10.0.5.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "west-ebs-refresh"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-west-ebs-refresh"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        refresh              = true

        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "West EBS refresh"
          Backup   = true
        }

        ebs_block_devices = [
          {
            volume_size  = "64"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          }
        ]

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        network_interfaces = [
          {
            private_ip      = "10.0.5.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "east-ebs"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-ebs"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "East EBS"
          Backup   = true
        }

        ebs_block_devices = [
          {
            volume_size  = "32"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          }
        ]

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        network_interfaces = [
          {
            private_ip      = "10.1.5.10"
            security_groups = ["sg-east"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "west-ebs-max"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-ebs-max"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "West EBS max"
          Backup   = true
        }

        ebs_block_devices = [
          for index in range(23) : {
            volume_size  = "10"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          }
        ]

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        network_interfaces = [
          {
            private_ip      = "10.0.5.12"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000003"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["west-ebs"]
    override_during = plan
    values = {
      id = "i-west-ebs"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["east"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1_refresh["west-ebs-refresh"]
    override_during = plan
    values = {
      id = "i-west-ebs-refresh"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["east-ebs"]
    override_during = plan
    values = {
      id = "i-east-ebs"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["west-ebs-ebs-0"]
    override_during = plan
    values = {
      id = "vol-west-ebs-0"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["west-ebs-ebs-1"]
    override_during = plan
    values = {
      id = "vol-west-ebs-1"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["west-ebs-ebs-2"]
    override_during = plan
    values = {
      id = "vol-west-ebs-2"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1_refresh["west-ebs-refresh-ebs-0"]
    override_during = plan
    values = {
      id = "vol-west-ebs-refresh-0"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["east-ebs-ebs-0"]
    override_during = plan
    values = {
      id = "vol-east-ebs-0"
    }
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-0"].hostname == "west-ebs"
    error_message = "The west normal EBS local should carry its owning hostname explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-1"].index == 1
    error_message = "The second west normal EBS local should carry its source index explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-1"].device_name == "/dev/sde"
    error_message = "The second west normal EBS local should carry its planned device name explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-2"].skip_destroy == true
    error_message = "The third west normal EBS local should preserve explicit skip_destroy."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-refresh-ebs-0"].hostname == "west-ebs-refresh"
    error_message = "The west refresh EBS local should carry its owning hostname explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["east-ebs-ebs-0"].device_name == "/dev/sdd"
    error_message = "The east EBS local should carry its planned device name explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-max-ebs-22"].device_name == "/dev/sdz"
    error_message = "The twenty-third west EBS local should stay inside the d..z device-name range."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-0"].volume_id == "vol-west-ebs-0" && aws_volume_attachment.us_east_1["west-ebs-ebs-0"].instance_id == "i-west-ebs" && aws_volume_attachment.us_east_1["west-ebs-ebs-0"].device_name == "/dev/sdd"
    error_message = "The first west normal EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-0"].skip_destroy == false && aws_volume_attachment.us_east_1["west-ebs-ebs-0"].stop_instance_before_detaching == true
    error_message = "The first west normal EBS attachment should default skip_destroy to false and stop the instance before detaching."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-1"].volume_id == "vol-west-ebs-1" && aws_volume_attachment.us_east_1["west-ebs-ebs-1"].instance_id == "i-west-ebs" && aws_volume_attachment.us_east_1["west-ebs-ebs-1"].device_name == "/dev/sde" && aws_volume_attachment.us_east_1["west-ebs-ebs-1"].skip_destroy == false
    error_message = "The second west normal EBS attachment should preserve address -> volume -> instance -> device wiring and skip_destroy."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-2"].volume_id == "vol-west-ebs-2" && aws_volume_attachment.us_east_1["west-ebs-ebs-2"].instance_id == "i-west-ebs" && aws_volume_attachment.us_east_1["west-ebs-ebs-2"].device_name == "/dev/sdf" && aws_volume_attachment.us_east_1["west-ebs-ebs-2"].skip_destroy == true && aws_volume_attachment.us_east_1["west-ebs-ebs-2"].stop_instance_before_detaching == true
    error_message = "The third west normal EBS attachment should preserve address -> volume -> instance -> device wiring, explicit skip_destroy, and safe detach."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1_refresh["west-ebs-refresh-ebs-0"].volume_id == "vol-west-ebs-refresh-0" && aws_volume_attachment.us_east_1_refresh["west-ebs-refresh-ebs-0"].instance_id == "i-west-ebs-refresh" && aws_volume_attachment.us_east_1_refresh["west-ebs-refresh-ebs-0"].device_name == "/dev/sdd"
    error_message = "The west refresh EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["east-ebs-ebs-0"].volume_id == "vol-east-ebs-0" && aws_volume_attachment.us_east_1["east-ebs-ebs-0"].instance_id == "i-east-ebs" && aws_volume_attachment.us_east_1["east-ebs-ebs-0"].device_name == "/dev/sdd"
    error_message = "The east EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition = alltrue(concat(
      [for _, volume in aws_ebs_volume.us_east_1 : volume.encrypted == true],
      [for _, volume in aws_ebs_volume.us_east_1_refresh : volume.encrypted == true],
    ))
    error_message = "Every planned normal and refresh EBS data volume should set encrypted = true."
  }
}

run "systems_reject_more_than_23_ebs_block_devices" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "too-many-ebs"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-ebs-too-many"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Too many EBS devices"
          Backup   = true
        }

        ebs_block_devices = [
          for index in range(24) : {
            volume_size  = "10"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          }
        ]

        root_block_device = {
          delete_on_termination = true
          iops                  = null
          tags                  = {}
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        network_interfaces = [
          {
            private_ip      = "10.0.5.13"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_duplicate_hostnames" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "duplicate-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Duplicate host A"
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
            private_ip      = "10.0.2.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "duplicate-host"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-west-b"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Duplicate host B"
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
            private_ip      = "10.0.2.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_regions_outside_aws_config" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "eu-west-1"
        hostname             = "bad-region"
        availability_zone    = "eu-west-1a"
        subnet_id            = "subnet-eu-a"
        key_name             = "eu-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "eu"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Unsupported region"
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
            private_ip      = "10.2.0.10"
            security_groups = ["sg-eu"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "aws_config_rejects_unsupported_region_sets" {
  command = plan

  variables {
    aws_config = {
      regions = ["us_east_1", "eu_west_1"]
    }
    all_systems = []
  }

  expect_failures = [
    var.aws_config,
  ]
}

run "aws_config_rejects_duplicate_region_entries" {
  command = plan

  variables {
    aws_config = {
      regions = ["us_east_1", "us_east_1"]
    }
    all_systems = []
  }

  expect_failures = [
    var.aws_config,
  ]
}

run "systems_reject_invalid_ami_identifiers" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "invalid-ami"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "amazon_linux_2023:latest"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Invalid AMI"
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
            private_ip      = "10.0.3.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_invalid_set_state" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "bad-state"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        set_state            = "terminated"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1

        tags = {
          Function = "Invalid instance state"
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
            private_ip      = "10.0.3.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "environment_rejects_blank_value" {
  command = plan

  variables {
    environment = "   "
    all_systems = []
  }

  expect_failures = [
    var.environment,
  ]
}

run "systems_accept_windows_server_2025_base_ami" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "win2025-01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2025_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows Server 2025"
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
            private_ip      = "10.0.3.11"
            security_groups = ["sg-west"]
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
    condition     = contains(keys(aws_instance.us_east_1), "win2025-01")
    error_message = "Windows Server 2025 AMI should plan a west-region instance."
  }
}

run "systems_accept_selfbuilt_ami_names_and_versions" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "default-rhel"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-selfbuilt-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Family self-built Linux AMI"
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
            private_ip      = "10.0.11.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "prod-rhel"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-selfbuilt-name"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "prod-rhel8"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Named self-built Linux AMI"
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
            private_ip      = "10.1.11.10"
            security_groups = ["sg-east"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "selfwin01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-selfbuilt-version"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ttc-win22-sql19:1.2"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Versioned self-built Windows AMI"
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
            private_ip      = "10.0.11.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000009"
      platform         = ""
      platform_details = "Windows"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["prod-rhel8"]
    values = {
      id               = "ami-00000000000000010"
      platform         = ""
      platform_details = "Windows"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["ttc-win22-sql19:1.2"]
    values = {
      id               = "ami-00000000000000011"
      platform         = "windows"
      platform_details = "Linux/UNIX"
    }
  }

  assert {
    condition     = contains(keys(data.aws_ami.us_east_1_selfbuilt), "test-linux") && contains(keys(data.aws_ami.us_east_1_selfbuilt), "ttc-win22-sql19:1.2") && contains(keys(data.aws_ami.us_east_1_selfbuilt), "prod-rhel8")
    error_message = "Self-built name and name:version inputs should instantiate regional self-owned AMI data lookups."
  }

  assert {
    condition = alltrue([
      local.ami_specs["test-linux"].family == "test-linux",
      local.ami_specs["test-linux"].version == null,
      local.ami_specs["test-linux"].glob == "test-linux_v*",
      local.ami_specs["test-linux"].name_regex == "^test-linux_v[0-9]",
      local.ami_specs["prod-rhel8"].family == "prod-rhel8",
      local.ami_specs["prod-rhel8"].glob == "prod-rhel8_v*",
      local.ami_specs["ttc-win22-sql19:1.2"].family == "ttc-win22-sql19",
      local.ami_specs["ttc-win22-sql19:1.2"].version == "1.2",
      local.ami_specs["ttc-win22-sql19:1.2"].glob == "ttc-win22-sql19_v1.2_*",
      local.ami_specs["ttc-win22-sql19:1.2"].name_regex == "^ttc-win22-sql19_v1\\.2_",
    ])
    error_message = "AMI specs should preserve caller-provided families and build anchored glob/regex selectors in one local."
  }

  assert {
    condition = alltrue([
      contains(keys(local.amazon_machine_images), "windows_server_2025_base"),
      contains(keys(local.amazon_machine_images), "test-linux"),
      contains(keys(local.amazon_machine_images), "prod-rhel8"),
      contains(keys(local.amazon_machine_images), "ttc-win22-sql19:1.2"),
    ])
    error_message = "The unified AMI map should be keyed by public aliases and full self-built input strings."
  }

  assert {
    condition     = aws_instance.us_east_1["default-rhel"].ami == "ami-00000000000000009" && aws_instance.us_east_1["prod-rhel"].ami == "ami-00000000000000010" && aws_instance.us_east_1["selfwin01"].ami == "ami-00000000000000011"
    error_message = "Instances should launch from the resolved self-built AMI IDs."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_east_1["default-rhel"].is_windows == false,
      local.elastic_compute_cloud.us_east_1["prod-rhel"].is_windows == false,
      output.aws_instances["default-rhel"].os_family == "linux",
      output.aws_instances["prod-rhel"].os_family == "linux",
      strcontains(local.elastic_compute_cloud.us_east_1["default-rhel"].user_data, "systemctl enable --now sshd"),
      strcontains(local.elastic_compute_cloud.us_east_1["prod-rhel"].user_data, "systemctl enable --now sshd"),
    ])
    error_message = "Self-built AMIs with empty platform should classify as Linux even if platform_details is misleading."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_east_1["selfwin01"].is_windows == true,
      aws_instance.us_east_1["selfwin01"].get_password_data == false,
      local.readiness_targets["selfwin01"].is_windows == true,
      output.aws_instances["selfwin01"].os_family == "windows",
      strcontains(local.elastic_compute_cloud.us_east_1["selfwin01"].user_data, "Add-WindowsCapability -Online -Name OpenSSH.Server"),
    ])
    error_message = "Self-built AMIs with platform=windows should classify as Windows even if platform_details is misleading."
  }
}

run "systems_accept_raw_ami_ids_and_classify_from_platform" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "direct-win01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-direct-windows"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ami-0123456789abcdef0"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Direct Windows AMI"
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
            private_ip      = "10.0.10.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "direct-linux"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-direct-linux"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "ami-0fedcba9876543210"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Direct Linux AMI"
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
            private_ip      = "10.1.10.10"
            security_groups = ["sg-east"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_direct["ami-0123456789abcdef0"]
    values = {
      id               = "ami-0123456789abcdef0"
      platform         = "windows"
      platform_details = "Linux/UNIX"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_direct["ami-0fedcba9876543210"]
    values = {
      id               = "ami-0fedcba9876543210"
      platform         = ""
      platform_details = "Windows"
    }
  }

  assert {
    condition     = contains(keys(data.aws_ami.us_east_1_direct), "ami-0123456789abcdef0") && contains(keys(data.aws_ami.us_east_1_direct), "ami-0fedcba9876543210")
    error_message = "Raw AMI IDs should instantiate exact image-id data lookups in their target regions."
  }

  assert {
    condition     = aws_instance.us_east_1["direct-win01"].ami == "ami-0123456789abcdef0" && aws_instance.us_east_1["direct-linux"].ami == "ami-0fedcba9876543210"
    error_message = "Instances launched from raw AMI IDs should use the resolved direct AMI IDs."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_east_1["direct-win01"].is_windows == true,
      aws_instance.us_east_1["direct-win01"].get_password_data == false,
      local.readiness_targets["direct-win01"].is_windows == true,
      output.aws_instances["direct-win01"].os_family == "windows",
      strcontains(local.elastic_compute_cloud.us_east_1["direct-win01"].user_data, "Add-WindowsCapability -Online -Name OpenSSH.Server"),
      strcontains(local.elastic_compute_cloud.us_east_1["direct-win01"].user_data, "administrators_authorized_keys"),
      !strcontains(local.elastic_compute_cloud.us_east_1["direct-win01"].user_data, "5986"),
    ])
    error_message = "A raw Windows AMI should classify as Windows exclusively from platform metadata."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_east_1["direct-linux"].is_windows == false,
      aws_instance.us_east_1["direct-linux"].get_password_data == false,
      local.readiness_targets["direct-linux"].is_windows == false,
      output.aws_instances["direct-linux"].os_family == "linux",
      strcontains(local.elastic_compute_cloud.us_east_1["direct-linux"].user_data, "systemctl enable --now sshd"),
    ])
    error_message = "A raw non-Windows AMI should classify as Linux from platform metadata."
  }
}

run "systems_reject_windows_hostnames_over_15_characters" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "win-server-01234"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows hostname too long"
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
            private_ip      = "10.0.7.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_windows_hostnames_with_invalid_characters" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "win_app_01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows hostname invalid characters"
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
            private_ip      = "10.0.7.12"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_all_numeric_windows_hostnames" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "123456789012345"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows hostname all numeric"
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
            private_ip      = "10.0.7.13"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_accept_valid_windows_hostnames" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "win-app-01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Valid Windows hostname"
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
            private_ip      = "10.0.7.11"
            security_groups = ["sg-west"]
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
    condition     = contains(keys(aws_instance.us_east_1), "win-app-01")
    error_message = "Valid Windows hostname should plan a west-region instance."
  }
}

run "systems_use_default_linux_readiness_script_path" {
  command = plan

  assert {
    condition     = "${var.readiness_linux_script_dir}/terraform_%RAND%.sh" == "/home/ec2-user/terraform_%RAND%.sh"
    error_message = "Linux readiness should upload the remote-exec script under the default /home/ec2-user directory."
  }

  assert {
    condition     = strcontains("${var.readiness_linux_script_dir}/terraform_%RAND%.sh", "%RAND%")
    error_message = "Linux readiness script_path must preserve the literal Terraform communicator %RAND% token."
  }
}

run "systems_allow_overridden_linux_readiness_script_path" {
  command = plan

  variables {
    readiness_linux_script_dir = "/opt/terraform"
  }

  assert {
    condition     = "${var.readiness_linux_script_dir}/terraform_%RAND%.sh" == "/opt/terraform/terraform_%RAND%.sh"
    error_message = "Linux readiness should upload the remote-exec script under the overridden directory."
  }

  assert {
    condition     = !strcontains("${var.readiness_linux_script_dir}/terraform_%RAND%.sh", "/tmp/") && strcontains("${var.readiness_linux_script_dir}/terraform_%RAND%.sh", "%RAND%")
    error_message = "Linux readiness script_path must avoid /tmp and preserve the literal %RAND% token when overridden."
  }
}

run "systems_reject_relative_linux_readiness_script_dir" {
  command = plan

  variables {
    readiness_linux_script_dir = "opt/terraform"
  }

  expect_failures = [
    var.readiness_linux_script_dir,
  ]
}

run "systems_reject_trailing_slash_linux_readiness_script_dir" {
  command = plan

  variables {
    readiness_linux_script_dir = "/opt/terraform/"
  }

  expect_failures = [
    var.readiness_linux_script_dir,
  ]
}

run "readiness_gate_allows_empty_private_key_paths" {
  command = plan

  variables {
    readiness_private_key_paths = {}

    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-empty-map"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-empty-map"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Readiness empty key map"
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
            private_ip      = "10.0.13.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  assert {
    condition     = contains(keys(terraform_data.readiness_gate), "readiness-empty-map")
    error_message = "An empty readiness_private_key_paths map should keep the plan/CI readiness gate path valid."
  }
}

run "readiness_gate_rejects_populated_map_missing_key_name" {
  command = plan

  variables {
    readiness_private_key_paths = {
      unrelated = "/tmp/unrelated.pem"
    }

    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-missing-key"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-missing-key"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Readiness missing key"
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
            private_ip      = "10.0.13.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000014"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  expect_failures = [
    terraform_data.readiness_gate,
  ]
}

run "readiness_targets_thread_per_system_readiness_user" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "linux-override"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-linux-override"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        readiness_user       = "ubuntu"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Linux readiness override"
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
            private_ip      = "10.0.14.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "linux-default"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-linux-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Linux readiness default"
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
            private_ip      = "10.0.14.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "win-override"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-win-override"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"
        readiness_user       = "ReadinessAdmin"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows readiness override"
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
            private_ip      = "10.0.14.12"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "win-default"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-win-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows readiness default"
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
            private_ip      = "10.0.14.13"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000015"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_windows_server_2022_base[0]
    values = {
      id               = "ami-00000000000000016"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  assert {
    condition = alltrue([
      local.readiness_targets["linux-override"].readiness_user == "ubuntu",
      local.readiness_targets["win-override"].readiness_user == "ReadinessAdmin",
    ])
    error_message = "Readiness targets should preserve per-system readiness_user overrides for Linux and Windows."
  }

  assert {
    condition = alltrue([
      local.readiness_targets["linux-default"].readiness_user == null,
      local.readiness_targets["win-default"].readiness_user == null,
    ])
    error_message = "Readiness targets should keep readiness_user null when unset so OS defaults are used."
  }
}

run "systems_render_readiness_user_data_per_os" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "linux-ssh"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-linux"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Linux SSH user data"
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
            private_ip      = "10.0.8.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "win-ssh-01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-windows"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Windows SSH user data"
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
            private_ip      = "10.0.8.11"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000005"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_windows_server_2022_base[0]
    values = {
      id               = "ami-00000000000000006"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  assert {
    condition     = aws_instance.us_east_1["linux-ssh"].user_data != null
    error_message = "Linux instances should receive rendered SSH user_data."
  }

  assert {
    condition     = strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "systemctl enable --now sshd")
    error_message = "Linux user_data should enable and start sshd."
  }

  assert {
    condition     = strcontains(local.linux_ssh_user_data, "systemctl enable --now sshd || systemctl enable --now ssh")
    error_message = "Linux user_data should fall back from sshd.service to ssh.service for Debian-family images."
  }

  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "systemctl enable --now amazon-ssm-agent"),
      strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm"),
      !strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "__AWS_REGION__"),
    ])
    error_message = "Linux user_data should best-effort install/enable the SSM agent with the __AWS_REGION__ sentinel substituted to the hyphenated region, so non-Amazon AMIs (e.g. CIS/STIG RHEL) are SSM-reachable without a public IP."
  }

  assert {
    condition     = aws_instance.us_east_1["win-ssh-01"].user_data != null
    error_message = "Windows instances should receive rendered SSH user_data."
  }

  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "Add-WindowsCapability -Online -Name OpenSSH.Server"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "Set-Service -Name sshd -StartupType Automatic"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "administrators_authorized_keys"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "X-aws-ec2-metadata-token"),
    ])
    error_message = "Windows user_data should bootstrap OpenSSH Server and install the launch public key for administrator SSH."
  }

  assert {
    condition = alltrue([
      !strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "WinRM"),
      !strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "WSMan"),
      !strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "5986"),
    ])
    error_message = "WinRM is decommissioned; Windows user_data must not configure WSMan/WinRM listeners."
  }

  assert {
    condition     = local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data == trimspace(local.windows_ssh_user_data)
    error_message = "Windows systems must render exactly the promoted OpenSSH bootstrap user_data."
  }

  assert {
    condition     = aws_instance.us_east_1["win-ssh-01"].get_password_data == false
    error_message = "WinRM is decommissioned; Windows instances must not fetch launch password data."
  }

  assert {
    condition     = local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data != local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data
    error_message = "Linux and Windows user_data should differ so platform-based OS selection is covered."
  }
}

run "systems_reject_kms_alias_prefix" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "prefixed-kms"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "alias/west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Prefixed KMS alias"
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
            private_ip      = "10.0.4.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_empty_iam_instance_profile" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "empty-profile"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = ""
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Empty IAM instance profile"
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
            private_ip      = "10.0.6.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_empty_network_interface_security_groups" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "empty-sg"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Empty ENI security groups"
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
            private_ip      = "10.0.6.11"
            security_groups = []
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_empty_network_interfaces" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "empty-eni"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Empty network interfaces"
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

        network_interfaces = []

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "databases_reject_null_vpc_security_group_ids" {
  command = plan

  variables {
    all_databases = [
      {
        region                      = "us-east-1"
        availability_zone           = "us-east-1a"
        db_name                     = "null_security_groups_db"
        instance_class              = "db.t3.micro"
        db_subnet_group_name        = "db-subnets"
        engine                      = "postgres"
        engine_version              = "16.3"
        username                    = "dbadmin"
        password                    = "test-password"
        aws_kms_alias               = "west"
        vpc_security_group_ids      = null
        manage_master_user_password = false

        tags = {
          Function = "Database with null security groups"
          Backup   = true
        }
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
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "databases_reject_empty_vpc_security_group_ids" {
  command = plan

  variables {
    all_databases = [
      {
        region                      = "us-east-1"
        availability_zone           = "us-east-1a"
        db_name                     = "empty_security_groups_db"
        instance_class              = "db.t3.micro"
        db_subnet_group_name        = "db-subnets"
        engine                      = "postgres"
        engine_version              = "16.3"
        username                    = "dbadmin"
        password                    = "test-password"
        aws_kms_alias               = "west"
        vpc_security_group_ids      = []
        manage_master_user_password = false

        tags = {
          Function = "Database with empty security groups"
          Backup   = true
        }
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
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "databases_reject_duplicate_db_names" {
  command = plan

  variables {
    all_databases = [
      {
        region                 = "us-east-1"
        availability_zone      = "us-east-1a"
        db_name                = "duplicate_db"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        password               = "test-password"
        aws_kms_alias          = "west"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Function = "Duplicate database A"
          Backup   = true
        }
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      },
      {
        region                 = "us-east-1"
        availability_zone      = "us-east-1a"
        db_name                = "duplicate_db"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        password               = "test-password"
        aws_kms_alias          = "east"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Function = "Duplicate database B"
          Backup   = true
        }
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      }
    ]
  }

  expect_failures = [
    var.all_databases,
  ]
}

run "databases_reject_regions_outside_aws_config" {
  command = plan

  variables {
    all_databases = [
      {
        region                 = "eu-west-1"
        availability_zone      = "eu-west-1a"
        db_name                = "bad_region_db"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        password               = "test-password"
        aws_kms_alias          = "eu"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Function = "Unsupported database region"
          Backup   = true
        }
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      }
    ]
  }

  expect_failures = [
    var.all_databases,
  ]
}

run "databases_reject_kms_alias_prefix" {
  command = plan

  variables {
    all_databases = [
      {
        region                 = "us-east-1"
        availability_zone      = "us-east-1a"
        db_name                = "prefixed_kms_db"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        password               = "test-password"
        aws_kms_alias          = "alias/west"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Function = "Prefixed database KMS alias"
          Backup   = true
        }
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      }
    ]
  }

  expect_failures = [
    var.all_databases,
  ]
}

run "databases_reject_empty_password_when_not_managed" {
  command = plan

  variables {
    all_databases = [
      {
        region                      = "us-east-1"
        availability_zone           = "us-east-1a"
        db_name                     = "empty_password_db"
        instance_class              = "db.t3.micro"
        db_subnet_group_name        = "db-subnets"
        engine                      = "postgres"
        engine_version              = "16.3"
        username                    = "dbadmin"
        password                    = ""
        manage_master_user_password = false
        aws_kms_alias               = "west"
        vpc_security_group_ids      = ["sg-database"]

        tags = {
          Function = "Empty password database"
          Backup   = true
        }
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
      }
    ]
  }

  expect_failures = [
    var.all_databases,
  ]
}

run "databases_keep_credentials_sensitive" {
  command = plan

  variables {
    all_databases = [
      {
        region                 = "us-east-1"
        availability_zone      = "us-east-1a"
        db_name                = "sensitivedb"
        instance_class         = "db.t3.micro"
        db_subnet_group_name   = "db-subnets"
        engine                 = "postgres"
        engine_version         = "16.3"
        username               = "dbadmin"
        password               = "test-password"
        aws_kms_alias          = "west"
        vpc_security_group_ids = ["sg-database"]

        tags = {
          Function = "Sensitive database"
          Backup   = true
        }
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = false
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
      }
    ]
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = !issensitive(local.relational_database_service.us_east_1["sensitivedb"].db_name)
    error_message = "Database db_name must be non-sensitive so it can be used as a stable resource key."
  }

  assert {
    condition     = !issensitive(local.relational_database_service.us_east_1["sensitivedb"].kms_key_id)
    error_message = "Database KMS alias metadata must be non-sensitive so it can key the KMS data source."
  }

  assert {
    condition     = contains(keys(data.aws_kms_alias.us_east_1), "west")
    error_message = "Database KMS alias metadata must be usable as a KMS data source key."
  }

  assert {
    condition     = issensitive(local.relational_database_service_credentials.us_east_1["sensitivedb"].username)
    error_message = "Database username must stay sensitive in the RDS credentials local."
  }

  assert {
    condition     = issensitive(local.relational_database_service_credentials.us_east_1["sensitivedb"].password)
    error_message = "Database password must stay sensitive in the RDS credentials local."
  }

  assert {
    condition     = issensitive(aws_db_instance.us_east_1["sensitivedb"].username)
    error_message = "Database username must stay sensitive on the planned RDS resource."
  }

  assert {
    condition     = issensitive(aws_db_instance.us_east_1["sensitivedb"].password)
    error_message = "Database password must stay sensitive on the planned RDS resource."
  }
}

run "databases_allow_managed_master_user_password_without_plaintext_password" {
  command = plan

  variables {
    all_databases = [
      {
        region                      = "us-east-1"
        availability_zone           = "us-east-1a"
        db_name                     = "manageddb"
        instance_class              = "db.t3.micro"
        db_subnet_group_name        = "db-subnets"
        engine                      = "postgres"
        engine_version              = "16.3"
        username                    = "dbadmin"
        manage_master_user_password = true
        aws_kms_alias               = "west"
        vpc_security_group_ids      = ["sg-database"]

        tags = {
          Function = "Managed password database"
          Backup   = true
        }
        password                 = null
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
      }
    ]
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = local.relational_database_service.us_east_1["manageddb"].manage_master_user_password == true
    error_message = "Managed-password database local should carry manage_master_user_password = true."
  }

  assert {
    condition     = aws_db_instance.us_east_1["manageddb"].manage_master_user_password == true
    error_message = "Managed-password database resource should set manage_master_user_password = true."
  }

  assert {
    condition     = aws_db_instance.us_east_1["manageddb"].password == null
    error_message = "Managed-password database resource must not set a plaintext password."
  }

  assert {
    condition     = issensitive(aws_db_instance.us_east_1["manageddb"].username)
    error_message = "Managed-password database username must stay sensitive on the planned RDS resource."
  }
}

run "instances_enforce_imdsv2_and_password_data_default" {
  command = plan

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["test-linux"]
    values = {
      id               = "ami-00000000000000007"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].metadata_options[0].http_tokens == "required"
    error_message = "west-state should require IMDSv2 tokens."
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].metadata_options[0].http_endpoint == "enabled"
    error_message = "west-state should keep the instance metadata endpoint enabled."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["west-refresh"].metadata_options[0].http_tokens == "required"
    error_message = "west-refresh should require IMDSv2 tokens."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["west-refresh"].metadata_options[0].http_endpoint == "enabled"
    error_message = "west-refresh should keep the instance metadata endpoint enabled."
  }

  assert {
    condition     = aws_instance.us_east_1["east-state"].metadata_options[0].http_tokens == "required"
    error_message = "east-state should require IMDSv2 tokens."
  }

  assert {
    condition     = aws_instance.us_east_1["east-state"].metadata_options[0].http_endpoint == "enabled"
    error_message = "east-state should keep the instance metadata endpoint enabled."
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].metadata_options[0].http_put_response_hop_limit == 1
    error_message = "west-state should thread imds_hop_limit = 1 to the metadata options."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["west-refresh"].metadata_options[0].http_put_response_hop_limit == 1
    error_message = "west-refresh should thread imds_hop_limit = 1 to the metadata options."
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].metadata_options[0].http_protocol_ipv6 == "disabled"
    error_message = "west-state should keep the IMDS IPv6 endpoint disabled."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["west-refresh"].metadata_options[0].http_protocol_ipv6 == "disabled"
    error_message = "west-refresh should keep the IMDS IPv6 endpoint disabled."
  }

  assert {
    condition     = aws_instance.us_east_1["west-state"].metadata_options[0].instance_metadata_tags == "disabled"
    error_message = "west-state should never expose instance tags through the metadata service."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["west-refresh"].metadata_options[0].instance_metadata_tags == "disabled"
    error_message = "west-refresh should never expose instance tags through the metadata service."
  }

  assert {
    condition     = aws_instance.us_east_1["west-no-state"].get_password_data == false
    error_message = "Linux instances should compute get_password_data = false."
  }
}

run "readiness_gate_optout_creates_no_gate" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "west-gated"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Gated system keeps its readiness gate"
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
            private_ip      = "10.0.9.10"
            security_groups = ["sg-west"]
            description     = null
            interface_type  = null
            tags            = {}
          }
        ]

        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "west-ssm"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-b"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        readiness_gate       = false
        imds_hop_limit       = 1

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        set_state      = null

        tags = {
          Function = "Zero-inbound SSM system skips the readiness gate"
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
            private_ip      = "10.0.9.11"
            security_groups = ["sg-west"]
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
    condition     = length(terraform_data.readiness_gate) == 1 && contains(keys(terraform_data.readiness_gate), "west-gated")
    error_message = "Systems with the default readiness_gate = true must create exactly their own gate."
  }

  assert {
    condition     = !contains(keys(terraform_data.readiness_gate), "west-ssm")
    error_message = "readiness_gate = false must exclude the system from terraform_data.readiness_gate entirely."
  }
}

run "all_systems_rejects_null_root_block_device" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "null-root-device"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = true
        imds_hop_limit       = 1
        set_state            = null
        tags = {
          Backup   = true
          Function = "Null root block device validation"
        }
        root_block_device = null
        ebs_block_devices = []
        network_interfaces = [
          {
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_systems_rejects_null_instance_type" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "null-instance-type"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = null
        readiness_user       = null
        readiness_gate       = true
        imds_hop_limit       = 1
        set_state            = null
        tags = {
          Backup   = true
          Function = "Null instance type validation"
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
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_databases_rejects_null_blue_green_update" {
  command = plan

  variables {
    all_databases = [
      {
        region                      = "us-east-1"
        availability_zone           = "us-east-1a"
        db_name                     = "nullbluegreen"
        db_subnet_group_name        = "db-subnets"
        engine                      = "postgres"
        engine_version              = "16.3"
        instance_class              = "db.t3.micro"
        password                    = null
        username                    = "dbadmin"
        aws_kms_alias               = "test"
        allocated_storage           = "100"
        backup_retention_period     = null
        backup_window               = null
        blue_green_update           = null
        ca_cert_identifier          = null
        dedicated_log_volume        = true
        delete_automated_backups    = true
        deletion_protection         = true
        manage_master_user_password = true
        max_allocated_storage       = "1000"
        skip_final_snapshot         = false
        storage_type                = "gp3"
        vpc_security_group_ids      = ["sg-database"]
        tags = {
          Backup   = true
          Function = "Null blue-green update validation"
        }
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "all_systems_threads_imds_hop_limit_two" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "hop-two"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 2
        set_state            = null
        tags = {
          Backup   = true
          Function = "Container host needs one extra IMDS hop"
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
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      },
      {
        region               = "us-east-1"
        hostname             = "hop-two-refresh"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = true
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 2
        set_state            = null
        tags = {
          Backup   = true
          Function = "Refresh container host needs one extra IMDS hop"
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
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition     = aws_instance.us_east_1["hop-two"].metadata_options[0].http_put_response_hop_limit == 2
    error_message = "hop-two should thread imds_hop_limit = 2 to the metadata options."
  }

  assert {
    condition     = aws_instance.us_east_1["hop-two"].metadata_options[0].http_tokens == "required"
    error_message = "Raising the hop limit must not weaken IMDSv2 token enforcement."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["hop-two-refresh"].metadata_options[0].http_put_response_hop_limit == 2
    error_message = "hop-two-refresh should thread imds_hop_limit = 2 to the metadata options."
  }

  assert {
    condition     = aws_instance.us_east_1_refresh["hop-two-refresh"].metadata_options[0].http_tokens == "required"
    error_message = "Raising the hop limit must not weaken IMDSv2 token enforcement."
  }
}

run "all_systems_rejects_imds_hop_limit_zero" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "hop-zero"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 0
        set_state            = null
        tags = {
          Backup   = true
          Function = "Zero hop limit validation"
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
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_systems_rejects_imds_hop_limit_three" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "hop-three"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = 3
        set_state            = null
        tags = {
          Backup   = true
          Function = "Above-maximum hop limit validation"
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
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_systems_rejects_null_imds_hop_limit" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "hop-null"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-test"
        key_name             = "test-key"
        iam_instance_profile = "test-profile"
        aws_kms_alias        = "test"
        ami                  = "test-linux"
        refresh              = false
        instance_type        = "m6i.large"
        readiness_user       = null
        readiness_gate       = false
        imds_hop_limit       = null
        set_state            = null
        tags = {
          Backup   = true
          Function = "Null hop limit validation"
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
            description     = null
            interface_type  = null
            private_ip      = null
            security_groups = ["sg-test"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}
