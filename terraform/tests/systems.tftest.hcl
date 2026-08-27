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
}

variables {
  repository    = "nwarila-platform/aws-terraform-framework"
  repository_id = "123456789"
  commit_sha    = "0123456789abcdef0123456789abcdef01234567"
  run_id        = "42"
  environment   = "test"

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

      refresh                    = false
      instance_type              = "m6i.large"
      connection_type            = null
      readiness_user             = null
      readiness_command          = null
      readiness_script_dir       = null
      readiness_private_key_path = null
      readiness_gate             = true
      imds_hop_limit             = 1

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

      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.10"
          security_groups = ["sg-11111111"]
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
      hostname             = "west-no-state"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-west-b"
      key_name             = "west-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "west"
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

      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.11"
          security_groups = ["sg-11111111"]
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
      region               = "us-east-1"
      hostname             = "west-refresh"
      availability_zone    = "us-east-1b"
      subnet_id            = "subnet-west-c"
      key_name             = "west-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "west"
      ami                  = "test-linux"
      refresh              = true

      instance_type = "m6i.large"

      connection_type            = null
      readiness_user             = null
      readiness_command          = null
      readiness_script_dir       = null
      readiness_private_key_path = null
      readiness_gate             = true
      imds_hop_limit             = 1
      set_state                  = null

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

      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.12"
          security_groups = ["sg-11111111"]
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
      region               = "us-east-1"
      hostname             = "east-state"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-east-a"
      key_name             = "east-key"
      iam_instance_profile = "example-instance-profile"
      aws_kms_alias        = "east"
      ami                  = "test-linux"
      set_state            = "running"

      refresh                    = false
      instance_type              = "m6i.large"
      connection_type            = null
      readiness_user             = null
      readiness_command          = null
      readiness_script_dir       = null
      readiness_private_key_path = null
      readiness_gate             = true
      imds_hop_limit             = 1

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

      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.1.0.10"
          security_groups = ["sg-22222222"]
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

# subnet-west-c lives in the second zone; the provider mock answers us-east-1a for every other
# subnet.
override_data {
  target = data.aws_subnet.us_east_1["subnet-west-c"]
  values = {
    cidr_block        = "10.0.0.0/8"
    availability_zone = "us-east-1b"
    vpc_id            = "vpc-00000000000000001"
  }
}

# subnet-west-inventory-refresh lives in the second zone; the provider mock answers us-east-1a for
# every other subnet.
override_data {
  target = data.aws_subnet.us_east_1["subnet-west-inventory-refresh"]
  values = {
    cidr_block        = "10.0.0.0/8"
    availability_zone = "us-east-1b"
    vpc_id            = "vpc-00000000000000001"
  }
}

# subnet-west-ebs-refresh lives in the second zone; the provider mock answers us-east-1a for every
# other subnet.
override_data {
  target = data.aws_subnet.us_east_1["subnet-west-ebs-refresh"]
  values = {
    cidr_block        = "10.0.0.0/8"
    availability_zone = "us-east-1b"
    vpc_id            = "vpc-00000000000000001"
  }
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.12.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "backup-disabled"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-backup-disabled"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.12.11"
            security_groups = ["sg-11111111"]
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

    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "backupdefaultdb"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = ["sg-database"]

        tags = {
          Function = "Backup default database"
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
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "backupdisableddb"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = ["sg-database"]

        tags = {
          Backup   = false
          Function = "Backup disabled database"
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
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000012"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
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

  # AWS keeps the final snapshot after the instance is gone and rejects a destroy whose snapshot
  # name already exists, so a name fixed to db_name alone makes the SECOND destroy fail.
  assert {
    condition = (
      local.relational_database_service.us_east_1["backupdefaultdb"].final_snapshot_identifier == "backupdefaultdb-final-42" &&
      aws_db_instance.us_east_1["backupdefaultdb"].final_snapshot_identifier == "backupdefaultdb-final-42"
    )
    error_message = "Final snapshot identifiers must carry var.run_id so a repeat destroy cannot collide."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_db_instance.us_east_1["backupdefaultdb"].tags[key] == {
        Name         = "backupdefaultdb"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "42"
      }[key]
    ])
    error_message = "RDS instance tags must carry all seven deployment-identity keys verbatim."
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

  assert {
    condition     = alltrue([for _, database in aws_db_instance.us_east_1 : database.publicly_accessible == false])
    error_message = "Every planned RDS database should set publicly_accessible = false."
  }
}

# Ordering is enforced by make readiness-order-check because plan assertions cannot inspect the
# depends_on edge.
run "instance_state_includes_refresh_instances" {
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

        instance_type = "m6i.large"

        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.12"
            security_groups = ["sg-11111111"]
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.9.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "inv-win-east"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-inventory-windows"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "windows@2025"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.1.9.10"
            security_groups = ["sg-22222222"]
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
        region               = "us-east-1"
        hostname             = "inv-refresh"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-west-inventory-refresh"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        refresh              = true

        instance_type = "m6i.large"

        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.9.11"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000001"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2025"]
    values = {
      state            = "available"
      id               = "ami-00000000000000002"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["inv-linux-west"]
    override_during = plan
    values = {
      state       = "available"
      id          = "i-inventory-linux"
      private_dns = "inv-linux-west.internal"
    }
  }

  override_resource {
    target          = aws_network_interface.us_east_1["inv-linux-west-eni-0"]
    override_during = plan
    values = {
      state      = "available"
      private_ip = "10.0.91.10"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["inv-win-east"]
    override_during = plan
    values = {
      state       = "available"
      id          = "i-inventory-windows"
      private_dns = "inv-win-east.internal"
    }
  }

  override_resource {
    target          = aws_network_interface.us_east_1["inv-win-east-eni-0"]
    override_during = plan
    values = {
      state      = "available"
      private_ip = "10.1.91.10"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1_refresh["inv-refresh"]
    override_during = plan
    values = {
      state       = "available"
      id          = "i-inventory-refresh"
      private_dns = "inv-refresh.internal"
    }
  }

  override_resource {
    target          = aws_network_interface.us_east_1["inv-refresh-eni-0"]
    override_during = plan
    values = {
      state      = "available"
      private_ip = "10.0.91.11"
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
      output.aws_instances["inv-linux-west"].environment == "test",
    ])
    error_message = "Linux inventory entries should expose plan-known target facts."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-linux-west"].instance_id == "i-inventory-linux",
      output.aws_instances["inv-linux-west"].private_ip == "10.0.91.10",
      output.aws_instances["inv-linux-west"].private_dns == "inv-linux-west.internal",
    ])
    error_message = "Linux inventory entries should expose the mocked runtime target facts."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-win-east"].hostname == "inv-win-east",
      output.aws_instances["inv-win-east"].region == "us_east_1",
      output.aws_instances["inv-win-east"].function == "Inventory Windows",
      output.aws_instances["inv-win-east"].os_family == "windows",
      output.aws_instances["inv-win-east"].environment == "test",
    ])
    error_message = "Windows inventory entries should expose plan-known target facts."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-win-east"].instance_id == "i-inventory-windows",
      output.aws_instances["inv-win-east"].private_ip == "10.1.91.10",
      output.aws_instances["inv-win-east"].private_dns == "inv-win-east.internal",
    ])
    error_message = "Windows inventory entries should expose the mocked runtime target facts."
  }

  assert {
    condition = alltrue([
      output.aws_instances["inv-refresh"].hostname == "inv-refresh",
      output.aws_instances["inv-refresh"].region == "us_east_1",
      output.aws_instances["inv-refresh"].function == "Inventory Refresh",
      output.aws_instances["inv-refresh"].os_family == "linux",
      output.aws_instances["inv-refresh"].environment == "test",
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
      output.aws_instances["inv-refresh"].instance_id == "i-inventory-refresh",
      output.aws_instances["inv-refresh"].private_ip == "10.0.91.11",
      output.aws_instances["inv-refresh"].private_dns == "inv-refresh.internal",
    ])
    error_message = "Refresh inventory entries should expose the mocked runtime target facts."
  }

  assert {
    condition     = !contains(keys(output.aws_instances["inv-linux-west"]), "platform") && !contains(keys(output.aws_instances["inv-linux-west"]), "name")
    error_message = "aws_instances should replace the old platform/name fields with os_family/hostname."
  }
}

run "refresh_serial_baseline" {
  command = apply

  variables {
    refresh_serial = 1

    all_systems = [
      {
        region                     = "us_east_1"
        hostname                   = "stable-host"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-refresh-lifecycle"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Stable lifecycle control"
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
            private_ip      = "10.0.10.10"
            security_groups = ["sg-11111111"]
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
        region                     = "us_east_1"
        hostname                   = "refresh-host"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-refresh-lifecycle"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Refresh lifecycle subject"
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
            private_ip      = "10.0.10.11"
            security_groups = ["sg-11111111"]
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
}

run "refresh_serial_replaces_only_refresh_instances" {
  command = apply

  variables {
    refresh_serial = 2

    all_systems = [
      {
        region                     = "us_east_1"
        hostname                   = "stable-host"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-refresh-lifecycle"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Stable lifecycle control"
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
            private_ip      = "10.0.10.10"
            security_groups = ["sg-11111111"]
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
        region                     = "us_east_1"
        hostname                   = "refresh-host"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-refresh-lifecycle"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Refresh lifecycle subject"
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
            private_ip      = "10.0.10.11"
            security_groups = ["sg-11111111"]
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
    condition = (
      run.refresh_serial_baseline.aws_instances["refresh-host"].instance_id !=
      output.aws_instances["refresh-host"].instance_id
    )
    error_message = "Incrementing refresh_serial must replace refresh instances."
  }

  assert {
    condition = (
      run.refresh_serial_baseline.aws_instances["stable-host"].instance_id ==
      output.aws_instances["stable-host"].instance_id
    )
    error_message = "Incrementing refresh_serial must not replace stable instances."
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
          Function = "West EBS"
          Backup   = true
        }

        ebs_block_devices = [
          {
            resource_key = "logs"
            device_index = 0
            volume_size  = "125"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          },
          {
            resource_key = "data"
            device_index = 1
            volume_size  = "250"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          },
          {
            resource_key = "archive"
            device_index = 2
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.5.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "west-ebs-refresh"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-west-ebs-refresh"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"
        refresh              = true

        instance_type = "m6i.large"

        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "West EBS refresh"
          Backup   = true
        }

        ebs_block_devices = [
          {
            resource_key = "cache"
            device_index = 0
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.5.11"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "east-ebs"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-ebs"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
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
          Function = "East EBS"
          Backup   = true
        }

        ebs_block_devices = [
          {
            resource_key = "database"
            device_index = 0
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.1.5.10"
            security_groups = ["sg-22222222"]
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
        region               = "us-east-1"
        hostname             = "west-ebs-max"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-ebs-max"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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
          Function = "West EBS max"
          Backup   = true
        }

        ebs_block_devices = [
          for index in range(23) : {
            resource_key = "volume-${index}"
            device_index = index
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.5.12"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "win-ebs"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-win-ebs"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows@2022"

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
          Function = "Windows EBS"
          Backup   = true
        }

        ebs_block_devices = [
          {
            resource_key = "logs"
            device_index = 1
            volume_size  = "125"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          },
          {
            resource_key = "data"
            device_index = 0
            volume_size  = "250"
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.5.13"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000003"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state            = "available"
      id               = "ami-00000000000000017"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["west-ebs"]
    override_during = plan
    values = {
      state = "available"
      id    = "i-west-ebs"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["east"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/11111111-1111-1111-1111-${join("", ["111111", "111111"])}"
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
    target          = aws_ebs_volume.us_east_1["west-ebs-ebs-logs"]
    override_during = plan
    values = {
      id = "vol-west-ebs-0"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["west-ebs-ebs-data"]
    override_during = plan
    values = {
      id = "vol-west-ebs-1"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["west-ebs-ebs-archive"]
    override_during = plan
    values = {
      id = "vol-west-ebs-2"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["west-ebs-refresh-ebs-cache"]
    override_during = plan
    values = {
      id = "vol-west-ebs-refresh-0"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["east-ebs-ebs-database"]
    override_during = plan
    values = {
      id = "vol-east-ebs-0"
    }
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-logs"].hostname == "west-ebs"
    error_message = "The west normal EBS local should carry its owning hostname explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-data"].index == 1
    error_message = "The west data EBS local should carry its stable device index explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-data"].device_name == "/dev/sde"
    error_message = "The second west normal EBS local should carry its planned device name explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["win-ebs-ebs-logs"].device_name == "xvde"
    error_message = "The first Windows EBS local should use its authored index, not list order."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["win-ebs-ebs-data"].device_name == "xvdd"
    error_message = "The second Windows EBS local should use its authored index, not list order."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["win-ebs-ebs-logs"].tags["DeviceName"] == "xvde"
    error_message = "The first Windows EBS local should tag the stable authored device name."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-ebs-archive"].skip_destroy == true
    error_message = "The third west normal EBS local should preserve explicit skip_destroy."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-refresh-ebs-cache"].hostname == "west-ebs-refresh"
    error_message = "The west refresh EBS local should carry its owning hostname explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["east-ebs-ebs-database"].device_name == "/dev/sdd"
    error_message = "The east EBS local should carry its planned device name explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["west-ebs-max-ebs-volume-22"].device_name == "/dev/sdz"
    error_message = "The twenty-third west EBS local should stay inside the d..z device-name range."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-logs"].volume_id == "vol-west-ebs-0" && aws_volume_attachment.us_east_1["west-ebs-ebs-logs"].instance_id == "i-west-ebs" && aws_volume_attachment.us_east_1["west-ebs-ebs-logs"].device_name == "/dev/sdd"
    error_message = "The first west normal EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-logs"].skip_destroy == false && aws_volume_attachment.us_east_1["west-ebs-ebs-logs"].stop_instance_before_detaching == true
    error_message = "The first west normal EBS attachment should default skip_destroy to false and stop the instance before detaching."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-data"].volume_id == "vol-west-ebs-1" && aws_volume_attachment.us_east_1["west-ebs-ebs-data"].instance_id == "i-west-ebs" && aws_volume_attachment.us_east_1["west-ebs-ebs-data"].device_name == "/dev/sde" && aws_volume_attachment.us_east_1["west-ebs-ebs-data"].skip_destroy == false
    error_message = "The second west normal EBS attachment should preserve address -> volume -> instance -> device wiring and skip_destroy."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-ebs-archive"].volume_id == "vol-west-ebs-2" && aws_volume_attachment.us_east_1["west-ebs-ebs-archive"].instance_id == "i-west-ebs" && aws_volume_attachment.us_east_1["west-ebs-ebs-archive"].device_name == "/dev/sdf" && aws_volume_attachment.us_east_1["west-ebs-ebs-archive"].skip_destroy == true && aws_volume_attachment.us_east_1["west-ebs-ebs-archive"].stop_instance_before_detaching == true
    error_message = "The third west normal EBS attachment should preserve address -> volume -> instance -> device wiring, explicit skip_destroy, and safe detach."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["west-ebs-refresh-ebs-cache"].volume_id == "vol-west-ebs-refresh-0" && aws_volume_attachment.us_east_1["west-ebs-refresh-ebs-cache"].instance_id == "i-west-ebs-refresh" && aws_volume_attachment.us_east_1["west-ebs-refresh-ebs-cache"].device_name == "/dev/sdd"
    error_message = "The west refresh EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["east-ebs-ebs-database"].volume_id == "vol-east-ebs-0" && aws_volume_attachment.us_east_1["east-ebs-ebs-database"].instance_id == "i-east-ebs" && aws_volume_attachment.us_east_1["east-ebs-ebs-database"].device_name == "/dev/sdd"
    error_message = "The east EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = alltrue([for _, volume in aws_ebs_volume.us_east_1 : volume.encrypted == true])
    error_message = "Every planned EBS data volume should set encrypted = true."
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
          Function = "Too many EBS devices"
          Backup   = true
        }

        ebs_block_devices = [
          for index in range(24) : {
            resource_key = "volume-${index}"
            device_index = index
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.5.13"
            security_groups = ["sg-11111111"]
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
    var.all_systems,
  ]
}

run "systems_reject_duplicate_ebs_device_indexes" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "duplicate-ebs-index"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-duplicate-ebs-index"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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
          Function = "Duplicate EBS device index"
          Backup   = true
        }

        ebs_block_devices = [
          {
            resource_key = "logs"
            device_index = 0
            volume_size  = "10"
            iops         = null
            snapshot_id  = null
            skip_destroy = false
            tags         = {}
            throughput   = null
            volume_type  = "gp3"
          },
          {
            resource_key = "data"
            device_index = 0
            volume_size  = "20"
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.5.14"
            security_groups = ["sg-11111111"]
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.2.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "duplicate-host"
        availability_zone    = "us-east-1b"
        subnet_id            = "subnet-west-b"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.2.11"
            security_groups = ["sg-11111111"]
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.2.0.10"
            security_groups = ["sg-33333333"]
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.3.10"
            security_groups = ["sg-11111111"]
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

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.3.11"
            security_groups = ["sg-11111111"]
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

run "systems_accept_a_windows_catalog_selector" {
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
        ami                  = "windows@2025"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.3.11"
            security_groups = ["sg-11111111"]
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.11.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "prod-rhel"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-selfbuilt-name"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "prod-rhel8"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.1.11.10"
            security_groups = ["sg-22222222"]
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
        region               = "us-east-1"
        hostname             = "selfwin01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-selfbuilt-version"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ttc-win22-sql19@1.2"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.11.11"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000009"
      platform         = ""
      platform_details = "Windows"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["prod-rhel8"]
    values = {
      state            = "available"
      id               = "ami-00000000000000010"
      platform         = ""
      platform_details = "Windows"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["ttc-win22-sql19@1.2"]
    values = {
      state            = "available"
      id               = "ami-00000000000000011"
      platform         = "windows"
      platform_details = "Linux/UNIX"
    }
  }

  assert {
    condition     = contains(keys(data.aws_ami.us_east_1_verified), "test-linux") && contains(keys(data.aws_ami.us_east_1_verified), "ttc-win22-sql19@1.2") && contains(keys(data.aws_ami.us_east_1_verified), "prod-rhel8")
    error_message = "Self-built name and name:version inputs should instantiate regional self-owned AMI data lookups."
  }

  # The selector-to-key transform is the entire resolution rule: a bare family addresses its
  # floating "latest" pointer, and "@" becomes a path separator so a pinned version addresses
  # the matching key. There is nothing else to get wrong, which is the point of the design.
  assert {
    condition = alltrue([
      local.ami_parameter_name["test-linux"] == "/nwarila/ami/test-linux/latest",
      local.ami_parameter_name["prod-rhel8"] == "/nwarila/ami/prod-rhel8/latest",
      local.ami_parameter_name["ttc-win22-sql19@1.2"] == "/nwarila/ami/ttc-win22-sql19/1.2",
    ])
    error_message = "A bare family must address its floating latest pointer; an @-suffixed selector must address the matching versioned key."
  }

  # Resolution is scoped to the selectors this configuration actually uses. The previous design
  # instantiated a lookup for every known public alias whether or not anything referenced it;
  # the catalog resolves exactly what is asked for and nothing else.
  assert {
    condition = alltrue([
      contains(keys(local.amazon_machine_images), "test-linux"),
      contains(keys(local.amazon_machine_images), "prod-rhel8"),
      contains(keys(local.amazon_machine_images), "ttc-win22-sql19@1.2"),
      length(local.amazon_machine_images) == 3,
    ])
    error_message = "The resolved image map must hold exactly the selectors in use, so an unreferenced family is never looked up."
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
      local.readiness_targets.us_east_1["selfwin01"].target_platform == "windows",
      output.aws_instances["selfwin01"].os_family == "windows",
      strcontains(local.elastic_compute_cloud.us_east_1["selfwin01"].user_data, "Set-Service -Name sshd"),
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.10.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "direct-linux"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-direct-linux"
        key_name             = "east-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "east"
        ami                  = "ami-0fedcba9876543210"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.1.10.10"
            security_groups = ["sg-22222222"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["ami-0123456789abcdef0"]
    values = {
      state            = "available"
      id               = "ami-0123456789abcdef0"
      platform         = "windows"
      platform_details = "Linux/UNIX"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["ami-0fedcba9876543210"]
    values = {
      state            = "available"
      id               = "ami-0fedcba9876543210"
      platform         = ""
      platform_details = "Windows"
    }
  }

  assert {
    condition     = contains(keys(data.aws_ami.us_east_1_verified), "ami-0123456789abcdef0") && contains(keys(data.aws_ami.us_east_1_verified), "ami-0fedcba9876543210")
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
      local.readiness_targets.us_east_1["direct-win01"].target_platform == "windows",
      output.aws_instances["direct-win01"].os_family == "windows",
      strcontains(local.elastic_compute_cloud.us_east_1["direct-win01"].user_data, "Set-Service -Name sshd"),
      strcontains(local.elastic_compute_cloud.us_east_1["direct-win01"].user_data, "administrators_authorized_keys"),
      !strcontains(local.elastic_compute_cloud.us_east_1["direct-win01"].user_data, "5986"),
    ])
    error_message = "A raw Windows AMI should classify as Windows exclusively from platform metadata."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_east_1["direct-linux"].is_windows == false,
      aws_instance.us_east_1["direct-linux"].get_password_data == false,
      local.readiness_targets.us_east_1["direct-linux"].target_platform == "unix",
      output.aws_instances["direct-linux"].os_family == "linux",
      strcontains(local.elastic_compute_cloud.us_east_1["direct-linux"].user_data, "systemctl enable --now sshd"),
    ])
    error_message = "A raw non-Windows AMI should classify as Linux from platform metadata."
  }
}

run "systems_reject_long_hostname_for_data_resolved_windows_ami" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname       = "host-name-123456"
        ami            = "ttc-win22-sql19@1.2"
        readiness_gate = false
        set_state      = null
      })
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["ttc-win22-sql19@1.2"]
    values = {
      state            = "available"
      id               = "ami-00000000000000011"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  expect_failures = [
    aws_instance.us_east_1["host-name-123456"],
  ]
}

run "refresh_systems_reject_long_hostname_for_data_resolved_windows_ami" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname       = "host-name-654321"
        ami            = "ttc-win22-sql19@1.2"
        refresh        = true
        readiness_gate = false
        set_state      = null
      })
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["ttc-win22-sql19@1.2"]
    values = {
      state            = "available"
      id               = "ami-00000000000000011"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  expect_failures = [
    aws_instance.us_east_1_refresh["host-name-654321"],
  ]
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
        ami                  = "windows@2022"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.7.10"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      platform = "windows"
    }
  }

  expect_failures = [
    aws_instance.us_east_1["win-server-01234"],
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
        ami                  = "windows@2022"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.7.12"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      platform = "windows"
    }
  }

  expect_failures = [
    aws_instance.us_east_1["win_app_01"],
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
        ami                  = "windows@2022"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.7.13"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      platform = "windows"
    }
  }

  expect_failures = [
    aws_instance.us_east_1["123456789012345"],
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
        ami                  = "windows@2022"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.7.11"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      platform = "windows"
    }
  }

  assert {
    condition     = contains(keys(aws_instance.us_east_1), "win-app-01")
    error_message = "Valid Windows hostname should plan a west-region instance."
  }
}

run "systems_default_linux_readiness_script_dir" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-script-default"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-script-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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
          Function = "Readiness fixture"
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
            private_ip      = "10.0.13.10"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  assert {
    condition = alltrue([
      local.readiness_targets.us_east_1["readiness-script-default"].script_path == "/home/ec2-user/terraform_%RAND%.sh",
      strcontains(local.readiness_targets.us_east_1["readiness-script-default"].script_path, "%RAND%"),
    ])
    error_message = "A null readiness_script_dir must resolve to /home/ec2-user and preserve the literal Terraform communicator %RAND% token."
  }
}

run "systems_override_linux_readiness_script_dir" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-script-override"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-script-override"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = "/opt/terraform"
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "Readiness fixture"
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
            private_ip      = "10.0.13.11"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  assert {
    condition = alltrue([
      local.readiness_targets.us_east_1["readiness-script-override"].script_path == "/opt/terraform/terraform_%RAND%.sh",
      !strcontains(local.readiness_targets.us_east_1["readiness-script-override"].script_path, "/tmp/"),
    ])
    error_message = "A per-system readiness_script_dir must reach script_path, avoiding the noexec /tmp default."
  }
}

run "systems_reject_relative_readiness_script_dir" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-script-relative"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-script-relative"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = "opt/terraform"
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "Readiness fixture"
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
            private_ip      = "10.0.13.12"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  expect_failures = [var.all_systems]
}

run "systems_reject_trailing_slash_readiness_script_dir" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-script-slash"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-script-slash"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = "/opt/terraform/"
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "Readiness fixture"
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
            private_ip      = "10.0.13.13"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  expect_failures = [var.all_systems]
}

run "readiness_gate_allows_a_null_private_key_path" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-east-1"
        hostname             = "readiness-null-key"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-readiness-null-key"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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
          Function = "Readiness fixture"
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
            private_ip      = "10.0.13.14"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  # Null is the plan/CI posture: the gate still plans, it just has no key to connect with.
  assert {
    condition     = contains(keys(terraform_data.readiness_gate), "readiness-null-key")
    error_message = "A null readiness_private_key_path must keep the readiness gate plannable."
  }
}

run "readiness_gate_rejects_a_missing_private_key_file" {
  command = plan

  variables {
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

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = "/nonexistent/definitely-not-a-key.pem"
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "Readiness fixture"
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
            private_ip      = "10.0.13.15"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000013"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  # A typo'd path would otherwise surface only as a ten-minute connection timeout at apply.
  expect_failures = [terraform_data.readiness_gate["readiness-missing-key"]]
}

run "readiness_targets_thread_per_system_readiness_user" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "linux-override"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-west-linux-override"
        key_name                   = "west-key"
        iam_instance_profile       = "example-instance-profile"
        aws_kms_alias              = "west"
        ami                        = "test-linux"
        readiness_user             = "ubuntu"
        readiness_command          = "systemctl is-system-running --wait"
        readiness_script_dir       = null
        readiness_private_key_path = null

        refresh         = false
        instance_type   = "m6i.large"
        connection_type = null
        readiness_gate  = true
        imds_hop_limit  = 1
        set_state       = null

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.14.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "linux-default"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-linux-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.14.11"
            security_groups = ["sg-11111111"]
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
        region                     = "us-east-1"
        hostname                   = "win-override"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-west-win-override"
        key_name                   = "west-key"
        iam_instance_profile       = "example-instance-profile"
        aws_kms_alias              = "west"
        ami                        = "windows@2022"
        readiness_user             = "ReadinessAdmin"
        readiness_command          = "powershell -Command \"Wait-Provisioning\""
        readiness_script_dir       = null
        readiness_private_key_path = null

        refresh         = false
        instance_type   = "m6i.large"
        connection_type = null
        readiness_gate  = true
        imds_hop_limit  = 1
        set_state       = null

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.14.12"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "win-default"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-win-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows@2022"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.14.13"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000015"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state            = "available"
      id               = "ami-00000000000000016"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  assert {
    condition = alltrue([
      local.readiness_targets.us_east_1["linux-override"].readiness_user == "ubuntu",
      local.readiness_targets.us_east_1["win-override"].readiness_user == "ReadinessAdmin",
    ])
    error_message = "Readiness targets should preserve per-system readiness_user overrides for Linux and Windows."
  }

  # Only the selectors this config references are looked up, one entry each. Nothing enumerates
  # a list of known families, so an unreferenced image can never be fetched.
  assert {
    condition = alltrue([
      length(data.aws_ami.us_east_1_verified) == 2,
      contains(keys(data.aws_ami.us_east_1_verified), "windows@2022"),
      contains(keys(data.aws_ami.us_east_1_verified), "test-linux"),
    ])
    error_message = "Each referenced selector must be verified exactly once, and no unreferenced family may be looked up."
  }

  # The OS fallback resolves here rather than in the resource, so an unset readiness_user
  # arrives already substituted instead of being threaded through as null.
  assert {
    condition = alltrue([
      local.readiness_targets.us_east_1["linux-default"].readiness_user == "ec2-user",
      local.readiness_targets.us_east_1["win-default"].readiness_user == "Administrator",
    ])
    error_message = "An unset readiness_user must resolve to the OS default: ec2-user on Linux, Administrator on Windows."
  }

  # Same contract for readiness_command.
  assert {
    condition = alltrue([
      local.readiness_targets.us_east_1["linux-default"].readiness_command == "cloud-init status --wait",
      strcontains(local.readiness_targets.us_east_1["win-default"].readiness_command, "EC2Launch.exe"),
    ])
    error_message = "An unset readiness_command must resolve to the OS default wait command."
  }

  # A per-system readiness_command wins over the OS default, on either platform.
  assert {
    condition = alltrue([
      local.readiness_targets.us_east_1["linux-override"].readiness_command == "systemctl is-system-running --wait",
      local.readiness_targets.us_east_1["win-override"].readiness_command == "powershell -Command \"Wait-Provisioning\"",
    ])
    error_message = "A per-system readiness_command must override the OS default."
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.8.10"
            security_groups = ["sg-11111111"]
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
        region               = "us-east-1"
        hostname             = "win-ssh-01"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-west-windows"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows@2022"

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.8.11"
            security_groups = ["sg-11111111"]
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

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000005"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state            = "available"
      id               = "ami-00000000000000006"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  # Linux enables sshd and the SSM agent. OpenSSH and cloud-init stay AMI responsibility; the
  # agent does not, because every image launched today is a vendor one and CIS RHEL ships the
  # agent disabled, so without this the host is created healthy and never becomes manageable.
  #
  # Both steps are idempotent by construction: each is an `enable --now`, which is a no-op on a
  # unit that is already enabled and running, and the install only runs when enabling failed.
  assert {
    condition = alltrue([
      aws_instance.us_east_1["linux-ssh"].user_data != null,
      strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "systemctl enable --now sshd || systemctl enable --now ssh"),
      strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "systemctl enable --now amazon-ssm-agent"),
      strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "rpm -Uvh --replacepkgs /root/amazon-ssm-agent.rpm"),
    ])
    error_message = "Linux user_data must enable sshd with the ssh.service fallback, and enable the SSM agent, installing it only if enabling fails."
  }

  # The region sentinel has to be substituted, or the agent is fetched from a bucket that does
  # not exist and the failure only shows up in a boot log.
  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm"),
      !strcontains(local.elastic_compute_cloud.us_east_1["linux-ssh"].user_data, "__AWS_REGION__"),
    ])
    error_message = "The __AWS_REGION__ sentinel must be substituted with the hyphenated region, so the agent is fetched from the region the instance boots into."
  }

  # Amazon's Windows images register with SSM on their own. Adding a step there would be
  # symmetry for its own sake, and one more thing to fail at boot.
  assert {
    condition = alltrue([
      !strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "amazon-ssm-agent"),
      !strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "AmazonSSMAgent"),
    ])
    error_message = "Windows user_data must not gain an SSM bootstrap; those images register on their own."
  }

  assert {
    condition     = aws_instance.us_east_1["win-ssh-01"].user_data != null
    error_message = "Windows instances should receive rendered SSH user_data."
  }

  # Windows enables and starts sshd, then installs the launch key, because EC2Launch populates
  # the Administrator password path rather than administrators_authorized_keys. It must not
  # INSTALL OpenSSH - the capability is AMI responsibility.
  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "Set-Service -Name sshd -StartupType Automatic"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "Start-Service -Name sshd"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "administrators_authorized_keys"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "X-aws-ec2-metadata-token"),
      !strcontains(local.elastic_compute_cloud.us_east_1["win-ssh-01"].user_data, "Add-WindowsCapability"),
    ])
    error_message = "Windows user_data must enable and start sshd and install the launch key, without installing the OpenSSH capability."
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
    error_message = "Windows systems must render exactly the promoted key-install user_data."
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.4.10"
            security_groups = ["sg-11111111"]
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.6.11"
            security_groups = []
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

        ami_block_device_overrides = []

        network_interfaces = []

        associate_public_ip = false
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_null_network_interfaces" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname           = "null-eni"
        network_interfaces = null
      })
    ]
  }

  expect_failures = [var.all_systems]
}

run "databases_reject_null_vpc_security_group_ids" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "null_security_groups_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = null
        manage_master_user_password         = true

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
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "empty_security_groups_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = []
        manage_master_user_password         = true

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
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "duplicate_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = ["sg-database"]

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
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "duplicate_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "east"
        vpc_security_group_ids              = ["sg-database"]

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
        region                              = "eu-west-1"
        availability_zone                   = "eu-west-1a"
        db_name                             = "bad_region_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "eu"
        vpc_security_group_ids              = ["sg-database"]

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
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "prefixed_kms_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "alias/west"
        vpc_security_group_ids              = ["sg-database"]

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

run "databases_require_managed_master_user_password" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "unmanaged_password_db"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        manage_master_user_password         = false
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = ["sg-database"]

        tags = {
          Function = "Unmanaged password database"
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

run "databases_keep_username_sensitive" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "sensitivedb"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        username                            = "dbadmin"
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = ["sg-database"]

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
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
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
    condition     = issensitive(aws_db_instance.us_east_1["sensitivedb"].username)
    error_message = "Database username must stay sensitive on the planned RDS resource."
  }
}

run "databases_configure_managed_master_user_password_without_plaintext_input" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "manageddb"
        instance_class                      = "db.t3.micro"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = true
        username                            = "dbadmin"
        manage_master_user_password         = true
        aws_kms_alias                       = "west"
        vpc_security_group_ids              = ["sg-database"]

        tags = {
          Function = "Managed password database"
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

  override_data {
    target = data.aws_kms_alias.us_east_1["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
    }
  }

  assert {
    condition     = local.relational_database_service.us_east_1["manageddb"].manage_master_user_password == true
    error_message = "Managed-password database local should carry manage_master_user_password = true."
  }

  assert {
    condition = (
      aws_db_instance.us_east_1["manageddb"].manage_master_user_password == true &&
      aws_db_instance.us_east_1["manageddb"].master_user_secret_kms_key_id == data.aws_kms_alias.us_east_1["west"].target_key_arn
    )
    error_message = "Managed-password database resource should enable management and use the consumer KMS key."
  }

  # IAM auth is the credential-free path: clients mint a short-lived token instead of holding a
  # password, so nothing static exists to leak even though a master secret still backs the admin.
  assert {
    condition     = aws_db_instance.us_east_1["manageddb"].iam_database_authentication_enabled == true
    error_message = "iam_database_authentication_enabled must reach the resource so token auth is reachable."
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
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.9.10"
            security_groups = ["sg-11111111"]
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

        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        set_state                  = null

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

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.9.11"
            security_groups = ["sg-11111111"]
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
        region                     = "us-east-1"
        hostname                   = "null-root-device"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Null root block device validation"
        }
        root_block_device          = null
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
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
        region                     = "us-east-1"
        hostname                   = "null-instance-type"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
        refresh                    = false
        instance_type              = null
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null
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
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
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
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "nullbluegreen"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        instance_class                      = "db.t3.micro"
        username                            = "dbadmin"
        aws_kms_alias                       = "test"
        allocated_storage                   = "100"
        backup_retention_period             = null
        backup_window                       = null
        blue_green_update                   = null
        ca_cert_identifier                  = null
        dedicated_log_volume                = true
        delete_automated_backups            = true
        deletion_protection                 = true
        manage_master_user_password         = true
        max_allocated_storage               = "1000"
        skip_final_snapshot                 = false
        storage_type                        = "gp3"
        vpc_security_group_ids              = ["sg-database"]
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
        region                     = "us-east-1"
        hostname                   = "hop-two"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = false
        imds_hop_limit             = 2
        set_state                  = null
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
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      },
      {
        region                     = "us-east-1"
        hostname                   = "hop-two-refresh"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
        refresh                    = true
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = false
        imds_hop_limit             = 2
        set_state                  = null
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
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
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
        region                     = "us-east-1"
        hostname                   = "hop-zero"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = false
        imds_hop_limit             = 0
        set_state                  = null
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
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
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
        region                     = "us-east-1"
        hostname                   = "hop-three"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = false
        imds_hop_limit             = 3
        set_state                  = null
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
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
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
        region                     = "us-east-1"
        hostname                   = "hop-null"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
        refresh                    = false
        instance_type              = "m6i.large"
        connection_type            = null
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = false
        imds_hop_limit             = null
        set_state                  = null
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
        ebs_block_devices          = []
        ami_block_device_overrides = []

        network_interfaces = [
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

# --- private_ip guards --------------------------------------------------------------------------
# #
# Omitting private_ip (null) is the ordinary path and is exercised throughout this file and by
# managed.tftest.hcl. These runs pin the pinned path down: a deliberately chosen address is
# checked
# at plan time so a typo cannot surface as a mid-apply AWS error, and identical addresses cannot
# collide inside one subnet. Cross-checks against a managed subnet's CIDR live in
# managed.tftest.hcl,
# where subnet_cidr is known.

run "network_interface_rejects_availability_zone_mismatching_its_subnet" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "eni-az-mismatch"
        availability_zone          = "us-east-1b"
        subnet_id                  = "subnet-x"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Availability-zone mismatch precondition"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_subnet.us_east_1["subnet-x"]
    values = {
      availability_zone = "us-east-1a"
      cidr_block        = "10.0.0.0/24"
    }
  }

  expect_failures = [aws_network_interface.us_east_1["eni-az-mismatch-eni-0"]]
}

run "network_interface_rejects_aws_reserved_private_ip" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "eni-reserved-ip"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-x"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Reserved private-IP precondition"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.0.1"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_subnet.us_east_1["subnet-x"]
    values = {
      availability_zone = "us-east-1a"
      cidr_block        = "10.0.0.0/24"
    }
  }

  expect_failures = [aws_network_interface.us_east_1["eni-reserved-ip-eni-0"]]
}

run "network_interface_rejects_private_ip_outside_its_subnet" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "eni-outside-cidr"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-x"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Out-of-subnet private-IP precondition"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.9.9.9"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  override_data {
    target = data.aws_subnet.us_east_1["subnet-x"]
    values = {
      availability_zone = "us-east-1a"
      cidr_block        = "10.0.0.0/24"
    }
  }

  expect_failures = [aws_network_interface.us_east_1["eni-outside-cidr-eni-0"]]
}

run "all_systems_rejects_duplicate_private_ip_on_one_system" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "dup-self"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-test"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Two interfaces claiming one address"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.1.10"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          },
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.1.10"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_systems_rejects_duplicate_private_ip_across_systems_in_one_subnet" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "dup-peer-a"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-shared"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "First claimant of a shared-subnet address"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.1.10"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      },
      {
        region                     = "us-east-1"
        hostname                   = "dup-peer-b"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-shared"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Second claimant of the same address"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.1.10"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_systems_allows_one_address_reused_across_distinct_subnets" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "reuse-a"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-alpha"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Pinned address in the first subnet"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.1.10"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      },
      {
        region                     = "us-east-1"
        hostname                   = "reuse-b"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-beta"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "Same address, different subnet"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = "10.0.1.10"
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(local.elastic_network_interfaces.us_east_1["reuse-a-eni-0"].private_ips) == 1,
      local.elastic_network_interfaces.us_east_1["reuse-a-eni-0"].private_ips[0] == "10.0.1.10",
      length(local.elastic_network_interfaces.us_east_1["reuse-b-eni-0"].private_ips) == 1,
      local.elastic_network_interfaces.us_east_1["reuse-b-eni-0"].private_ips[0] == "10.0.1.10",
    ])
    error_message = "One address pinned in two distinct subnets must plan cleanly and reach both interfaces; the uniqueness guard is scoped per subnet."
  }
}

run "all_systems_allows_auto_assigned_private_ip_in_a_preexisting_subnet" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "auto-assigned"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-preexisting"
        key_name                   = "test-key"
        iam_instance_profile       = "test-profile"
        aws_kms_alias              = "test"
        ami                        = "test-linux"
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
          Backup   = true
          Function = "AWS-assigned address in a pre-existing subnet"
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
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          },
          {
            description     = null
            interface_type  = null
            ingress         = null
            egress          = null
            private_ip      = null
            security_groups = ["sg-eeeeeeee"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      local.elastic_network_interfaces.us_east_1["auto-assigned-eni-0"].private_ips == null,
      local.elastic_network_interfaces.us_east_1["auto-assigned-eni-1"].private_ips == null,
    ])
    error_message = "Interfaces omitting private_ip in a pre-existing subnet must leave private_ips null on every interface so AWS assigns each address."
  }
}
