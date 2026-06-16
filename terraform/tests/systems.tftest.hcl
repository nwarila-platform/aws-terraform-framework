mock_provider "aws" {
  alias = "us_west_2"
}

mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  environment = "TEST"

  all_systems = [
    {
      region               = "us-west-2"
      hostname             = "west-state"
      availability_zone    = "us-west-2a"
      subnet_id            = "subnet-west-a"
      key_name             = "west-key"
      iam_instance_profile = "example-ssm-profile"
      aws_kms_alias        = "west"
      set_state            = "stopped"

      tags = {
        Function = "West instance with state control"
      }

      network_interfaces = [
        {
          private_ip = "10.0.0.10"
        }
      ]
    },
    {
      region               = "us_west_2"
      hostname             = "west-no-state"
      availability_zone    = "us-west-2a"
      subnet_id            = "subnet-west-b"
      key_name             = "west-key"
      iam_instance_profile = "example-ssm-profile"
      aws_kms_alias        = "west"

      tags = {
        Function = "West instance without state control"
      }

      network_interfaces = [
        {
          private_ip = "10.0.0.11"
        }
      ]
    },
    {
      region               = "us-west-2"
      hostname             = "west-refresh"
      availability_zone    = "us-west-2b"
      subnet_id            = "subnet-west-c"
      key_name             = "west-key"
      iam_instance_profile = "example-ssm-profile"
      aws_kms_alias        = "west"
      refresh              = true

      tags = {
        Function = "West refresh instance"
      }

      network_interfaces = [
        {
          private_ip = "10.0.0.12"
        }
      ]
    },
    {
      region               = "us-east-1"
      hostname             = "east-state"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-east-a"
      key_name             = "east-key"
      iam_instance_profile = "example-ssm-profile"
      aws_kms_alias        = "east"
      set_state            = "running"

      tags = {
        Function = "East instance with state control"
      }

      network_interfaces = [
        {
          private_ip = "10.1.0.10"
        }
      ]
    }
  ]
}

run "instance_state_created_only_when_set_state_is_not_null" {
  command = plan

  assert {
    condition     = length(aws_ec2_instance_state.us_west_2) == 1
    error_message = "west region should create state control for only the instance with set_state."
  }

  assert {
    condition     = contains(keys(aws_ec2_instance_state.us_west_2), "west-state")
    error_message = "west-state should have an aws_ec2_instance_state resource."
  }

  assert {
    condition     = !contains(keys(aws_ec2_instance_state.us_west_2), "west-no-state")
    error_message = "west-no-state must not create aws_ec2_instance_state with a null state."
  }

  assert {
    condition     = aws_ec2_instance_state.us_west_2["west-state"].state == "stopped"
    error_message = "west-state should preserve the requested stopped state."
  }

  assert {
    condition     = length(aws_ec2_instance_state.us_east_1) == 1
    error_message = "east region should create state control for only the instance with set_state."
  }

  assert {
    condition     = aws_ec2_instance_state.us_east_1["east-state"].state == "running"
    error_message = "east-state should preserve the requested running state."
  }

  assert {
    condition     = aws_instance.us_west_2["west-state"].iam_instance_profile != null
    error_message = "west-state should attach an IAM instance profile."
  }
}

run "ebs_volume_attachments_use_structured_wiring" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "west-ebs"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-ebs"
        key_name             = "west-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "west"

        tags = {
          Function = "West EBS"
        }

        ebs_block_devices = [
          {
            volume_size = "125"
          },
          {
            delete_on_termination = false
            volume_size           = "250"
          }
        ]

        network_interfaces = [
          {
            private_ip = "10.0.5.10"
          }
        ]
      },
      {
        region               = "us-west-2"
        hostname             = "west-ebs-refresh"
        availability_zone    = "us-west-2b"
        subnet_id            = "subnet-west-ebs-refresh"
        key_name             = "west-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "west"
        refresh              = true

        tags = {
          Function = "West EBS refresh"
        }

        ebs_block_devices = [
          {
            volume_size = "64"
          }
        ]

        network_interfaces = [
          {
            private_ip = "10.0.5.11"
          }
        ]
      },
      {
        region               = "us-east-1"
        hostname             = "east-ebs"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-east-ebs"
        key_name             = "east-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "east"

        tags = {
          Function = "East EBS"
        }

        ebs_block_devices = [
          {
            volume_size = "32"
          }
        ]

        network_interfaces = [
          {
            private_ip = "10.1.5.10"
          }
        ]
      }
    ]
  }

  override_resource {
    target          = aws_instance.us_west_2["west-ebs"]
    override_during = plan
    values = {
      id = "i-west-ebs"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_west_2["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["east"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    }
  }

  override_resource {
    target          = aws_instance.us_west_2_refresh["west-ebs-refresh"]
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
    target          = aws_ebs_volume.us_west_2["west-ebs-ebs-0"]
    override_during = plan
    values = {
      id = "vol-west-ebs-0"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_west_2["west-ebs-ebs-1"]
    override_during = plan
    values = {
      id = "vol-west-ebs-1"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_west_2_refresh["west-ebs-refresh-ebs-0"]
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
    condition     = local.ebs_block_devices.us_west_2["west-ebs-ebs-0"].hostname == "west-ebs"
    error_message = "The west normal EBS local should carry its owning hostname explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_west_2["west-ebs-ebs-1"].index == 1
    error_message = "The second west normal EBS local should carry its source index explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_west_2["west-ebs-ebs-1"].device_name == "/dev/sde"
    error_message = "The second west normal EBS local should carry its planned device name explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_west_2["west-ebs-refresh-ebs-0"].hostname == "west-ebs-refresh"
    error_message = "The west refresh EBS local should carry its owning hostname explicitly."
  }

  assert {
    condition     = local.ebs_block_devices.us_east_1["east-ebs-ebs-0"].device_name == "/dev/sdd"
    error_message = "The east EBS local should carry its planned device name explicitly."
  }

  assert {
    condition     = aws_volume_attachment.us_west_2["west-ebs-ebs-0"].volume_id == "vol-west-ebs-0" && aws_volume_attachment.us_west_2["west-ebs-ebs-0"].instance_id == "i-west-ebs" && aws_volume_attachment.us_west_2["west-ebs-ebs-0"].device_name == "/dev/sdd"
    error_message = "The first west normal EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = aws_volume_attachment.us_west_2["west-ebs-ebs-1"].volume_id == "vol-west-ebs-1" && aws_volume_attachment.us_west_2["west-ebs-ebs-1"].instance_id == "i-west-ebs" && aws_volume_attachment.us_west_2["west-ebs-ebs-1"].device_name == "/dev/sde" && aws_volume_attachment.us_west_2["west-ebs-ebs-1"].skip_destroy == false
    error_message = "The second west normal EBS attachment should preserve address -> volume -> instance -> device wiring and skip_destroy."
  }

  assert {
    condition     = aws_volume_attachment.us_west_2_refresh["west-ebs-refresh-ebs-0"].volume_id == "vol-west-ebs-refresh-0" && aws_volume_attachment.us_west_2_refresh["west-ebs-refresh-ebs-0"].instance_id == "i-west-ebs-refresh" && aws_volume_attachment.us_west_2_refresh["west-ebs-refresh-ebs-0"].device_name == "/dev/sdd"
    error_message = "The west refresh EBS attachment should preserve address -> volume -> instance -> device wiring."
  }

  assert {
    condition     = aws_volume_attachment.us_east_1["east-ebs-ebs-0"].volume_id == "vol-east-ebs-0" && aws_volume_attachment.us_east_1["east-ebs-ebs-0"].instance_id == "i-east-ebs" && aws_volume_attachment.us_east_1["east-ebs-ebs-0"].device_name == "/dev/sdd"
    error_message = "The east EBS attachment should preserve address -> volume -> instance -> device wiring."
  }
}

run "systems_reject_duplicate_hostnames" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "duplicate-host"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "west"

        tags = {
          Function = "Duplicate host A"
        }

        network_interfaces = [
          {
            private_ip = "10.0.2.10"
          }
        ]
      },
      {
        region               = "us-west-2"
        hostname             = "duplicate-host"
        availability_zone    = "us-west-2b"
        subnet_id            = "subnet-west-b"
        key_name             = "west-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "west"

        tags = {
          Function = "Duplicate host B"
        }

        network_interfaces = [
          {
            private_ip = "10.0.2.11"
          }
        ]
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
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "eu"

        tags = {
          Function = "Unsupported region"
        }

        network_interfaces = [
          {
            private_ip = "10.2.0.10"
          }
        ]
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_unknown_ami_keys" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "unknown-ami"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "west"
        ami                  = "amazon_linux_2023"

        tags = {
          Function = "Unsupported AMI"
        }

        network_interfaces = [
          {
            private_ip = "10.0.3.10"
          }
        ]
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "systems_reject_kms_alias_prefix" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "prefixed-kms"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-ssm-profile"
        aws_kms_alias        = "alias/west"

        tags = {
          Function = "Prefixed KMS alias"
        }

        network_interfaces = [
          {
            private_ip = "10.0.4.10"
          }
        ]
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
        region               = "us-west-2"
        hostname             = "empty-profile"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = ""
        aws_kms_alias        = "west"

        tags = {
          Function = "Empty IAM instance profile"
        }

        network_interfaces = [
          {
            private_ip = "10.0.6.10"
          }
        ]
      }
    ]
  }

  expect_failures = [
    var.all_systems,
  ]
}

run "databases_reject_duplicate_db_names" {
  command = plan

  variables {
    all_databases = [
      {
        region               = "us-west-2"
        availability_zone    = "us-west-2a"
        db_name              = "duplicate_db"
        instance_class       = "db.t3.micro"
        db_subnet_group_name = "db-subnets"
        engine               = "postgres"
        engine_version       = "16.3"
        username             = "dbadmin"
        password             = "test-password"
        aws_kms_alias        = "west"

        tags = {
          Function = "Duplicate database A"
        }
      },
      {
        region               = "us-east-1"
        availability_zone    = "us-east-1a"
        db_name              = "duplicate_db"
        instance_class       = "db.t3.micro"
        db_subnet_group_name = "db-subnets"
        engine               = "postgres"
        engine_version       = "16.3"
        username             = "dbadmin"
        password             = "test-password"
        aws_kms_alias        = "east"

        tags = {
          Function = "Duplicate database B"
        }
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
        region               = "eu-west-1"
        availability_zone    = "eu-west-1a"
        db_name              = "bad_region_db"
        instance_class       = "db.t3.micro"
        db_subnet_group_name = "db-subnets"
        engine               = "postgres"
        engine_version       = "16.3"
        username             = "dbadmin"
        password             = "test-password"
        aws_kms_alias        = "eu"

        tags = {
          Function = "Unsupported database region"
        }
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
        region               = "us-west-2"
        availability_zone    = "us-west-2a"
        db_name              = "prefixed_kms_db"
        instance_class       = "db.t3.micro"
        db_subnet_group_name = "db-subnets"
        engine               = "postgres"
        engine_version       = "16.3"
        username             = "dbadmin"
        password             = "test-password"
        aws_kms_alias        = "alias/west"

        tags = {
          Function = "Prefixed database KMS alias"
        }
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
        region               = "us-west-2"
        availability_zone    = "us-west-2a"
        db_name              = "empty_password_db"
        instance_class       = "db.t3.micro"
        db_subnet_group_name = "db-subnets"
        engine               = "postgres"
        engine_version       = "16.3"
        username             = "dbadmin"
        password             = ""
        aws_kms_alias        = "west"

        tags = {
          Function = "Empty password database"
        }
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
        region               = "us-west-2"
        availability_zone    = "us-west-2a"
        db_name              = "sensitivedb"
        instance_class       = "db.t3.micro"
        db_subnet_group_name = "db-subnets"
        engine               = "postgres"
        engine_version       = "16.3"
        username             = "dbadmin"
        password             = "test-password"
        aws_kms_alias        = "west"

        tags = {
          Function = "Sensitive database"
        }
      }
    ]
  }

  override_data {
    target = data.aws_kms_alias.us_west_2["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = !issensitive(local.relational_database_service.us_west_2["sensitivedb"].db_name)
    error_message = "Database db_name must be non-sensitive so it can be used as a stable resource key."
  }

  assert {
    condition     = !issensitive(local.relational_database_service.us_west_2["sensitivedb"].kms_key_id)
    error_message = "Database KMS alias metadata must be non-sensitive so it can key the KMS data source."
  }

  assert {
    condition     = contains(keys(data.aws_kms_alias.us_west_2), "west")
    error_message = "Database KMS alias metadata must be usable as a KMS data source key."
  }

  assert {
    condition     = issensitive(local.relational_database_service_credentials.us_west_2["sensitivedb"].username)
    error_message = "Database username must stay sensitive in the RDS credentials local."
  }

  assert {
    condition     = issensitive(local.relational_database_service_credentials.us_west_2["sensitivedb"].password)
    error_message = "Database password must stay sensitive in the RDS credentials local."
  }

  assert {
    condition     = issensitive(aws_db_instance.us_west_2["sensitivedb"].username)
    error_message = "Database username must stay sensitive on the planned RDS resource."
  }

  assert {
    condition     = issensitive(aws_db_instance.us_west_2["sensitivedb"].password)
    error_message = "Database password must stay sensitive on the planned RDS resource."
  }
}

run "databases_allow_managed_master_user_password_without_plaintext_password" {
  command = plan

  variables {
    all_databases = [
      {
        region                      = "us-west-2"
        availability_zone           = "us-west-2a"
        db_name                     = "manageddb"
        instance_class              = "db.t3.micro"
        db_subnet_group_name        = "db-subnets"
        engine                      = "postgres"
        engine_version              = "16.3"
        username                    = "dbadmin"
        manage_master_user_password = true
        aws_kms_alias               = "west"

        tags = {
          Function = "Managed password database"
        }
      }
    ]
  }

  override_data {
    target = data.aws_kms_alias.us_west_2["west"]
    values = {
      target_key_arn = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = local.relational_database_service.us_west_2["manageddb"].manage_master_user_password == true
    error_message = "Managed-password database local should carry manage_master_user_password = true."
  }

  assert {
    condition     = aws_db_instance.us_west_2["manageddb"].manage_master_user_password == true
    error_message = "Managed-password database resource should set manage_master_user_password = true."
  }

  assert {
    condition     = aws_db_instance.us_west_2["manageddb"].password == null
    error_message = "Managed-password database resource must not set a plaintext password."
  }

  assert {
    condition     = issensitive(aws_db_instance.us_west_2["manageddb"].username)
    error_message = "Managed-password database username must stay sensitive on the planned RDS resource."
  }
}

run "instances_enforce_imdsv2_and_password_data_default" {
  command = plan

  assert {
    condition     = aws_instance.us_west_2["west-state"].metadata_options[0].http_tokens == "required"
    error_message = "west-state should require IMDSv2 tokens."
  }

  assert {
    condition     = aws_instance.us_west_2["west-state"].metadata_options[0].http_endpoint == "enabled"
    error_message = "west-state should keep the instance metadata endpoint enabled."
  }

  assert {
    condition     = aws_instance.us_west_2_refresh["west-refresh"].metadata_options[0].http_tokens == "required"
    error_message = "west-refresh should require IMDSv2 tokens."
  }

  assert {
    condition     = aws_instance.us_west_2_refresh["west-refresh"].metadata_options[0].http_endpoint == "enabled"
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
    condition     = aws_instance.us_west_2["west-no-state"].get_password_data == false
    error_message = "get_password_data should default to false when omitted."
  }
}
