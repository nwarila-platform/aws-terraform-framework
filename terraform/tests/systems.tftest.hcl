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
      iam_instance_profile = "example-instance-profile"
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
      iam_instance_profile = "example-instance-profile"
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
      iam_instance_profile = "example-instance-profile"
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
      iam_instance_profile = "example-instance-profile"
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

  assert {
    condition     = aws_instance.us_west_2["west-state"].tags["ManagedBy"] == "Terraform" && aws_instance.us_west_2_refresh["west-refresh"].tags["ManagedBy"] == "Terraform" && aws_instance.us_east_1["east-state"].tags["ManagedBy"] == "Terraform"
    error_message = "EC2 instances should carry a non-overwritable ManagedBy=Terraform discovery tag."
  }

}

run "aws_instances_output_exposes_non_secret_inventory" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "inv-linux-west"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-inventory-linux"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ttc-rhel8"

        tags = {
          Function = "Inventory Linux"
        }

        network_interfaces = [
          {
            private_ip = "10.0.9.10"
          }
        ]
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

        tags = {
          Function = "Inventory Windows"
        }

        network_interfaces = [
          {
            private_ip = "10.1.9.10"
          }
        ]
      },
      {
        region               = "us-west-2"
        hostname             = "inv-refresh"
        availability_zone    = "us-west-2b"
        subnet_id            = "subnet-west-inventory-refresh"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ttc-rhel8"
        refresh              = true

        tags = {
          Function = "Inventory Refresh"
        }

        network_interfaces = [
          {
            private_ip = "10.0.9.11"
          }
        ]
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_west_2_selfbuilt["ttc-rhel8"]
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
      output.aws_instances["inv-linux-west"].region == "us_west_2",
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
      output.aws_instances["inv-refresh"].region == "us_west_2",
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
        region               = "us-west-2"
        hostname             = "west-ebs"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-ebs"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
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
        iam_instance_profile = "example-instance-profile"
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
        iam_instance_profile = "example-instance-profile"
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

  override_data {
    target = data.aws_ami.us_west_2_selfbuilt["ttc-rhel8"]
    values = {
      id               = "ami-00000000000000003"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["ttc-rhel8"]
    values = {
      id               = "ami-00000000000000004"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
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
        iam_instance_profile = "example-instance-profile"
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
        iam_instance_profile = "example-instance-profile"
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
        iam_instance_profile = "example-instance-profile"
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

run "systems_reject_invalid_ami_identifiers" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "invalid-ami"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "amazon_linux_2023:latest"

        tags = {
          Function = "Invalid AMI"
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

run "systems_accept_windows_server_2025_base_ami" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "win2025-01"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2025_base"

        tags = {
          Function = "Windows Server 2025"
        }

        network_interfaces = [
          {
            private_ip = "10.0.3.11"
          }
        ]
      }
    ]
  }

  assert {
    condition     = contains(keys(aws_instance.us_west_2), "win2025-01")
    error_message = "Windows Server 2025 AMI should plan a west-region instance."
  }
}

run "systems_accept_selfbuilt_ami_names_and_versions" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "default-rhel"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-selfbuilt-default"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"

        tags = {
          Function = "Default self-built Linux AMI"
        }

        network_interfaces = [
          {
            private_ip = "10.0.11.10"
          }
        ]
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

        tags = {
          Function = "Named self-built Linux AMI"
        }

        network_interfaces = [
          {
            private_ip = "10.1.11.10"
          }
        ]
      },
      {
        region               = "us-west-2"
        hostname             = "selfwin01"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-selfbuilt-version"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ttc-win22-sql19:1.2"

        tags = {
          Function = "Versioned self-built Windows AMI"
        }

        network_interfaces = [
          {
            private_ip = "10.0.11.11"
          }
        ]
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_west_2_selfbuilt["ttc-rhel8"]
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
    target = data.aws_ami.us_west_2_selfbuilt["ttc-win22-sql19:1.2"]
    values = {
      id               = "ami-00000000000000011"
      platform         = "windows"
      platform_details = "Linux/UNIX"
    }
  }

  assert {
    condition     = contains(keys(data.aws_ami.us_west_2_selfbuilt), "ttc-rhel8") && contains(keys(data.aws_ami.us_west_2_selfbuilt), "ttc-win22-sql19:1.2") && contains(keys(data.aws_ami.us_east_1_selfbuilt), "prod-rhel8")
    error_message = "Self-built name and name:version inputs should instantiate regional self-owned AMI data lookups."
  }

  assert {
    condition = alltrue([
      local.ami_specs["ttc-rhel8"].family == "ttc-rhel8",
      local.ami_specs["ttc-rhel8"].version == null,
      local.ami_specs["ttc-rhel8"].glob == "ttc-rhel8_v*",
      local.ami_specs["prod-rhel8"].family == "prod-rhel8",
      local.ami_specs["prod-rhel8"].glob == "prod-rhel8_v*",
      local.ami_specs["ttc-win22-sql19:1.2"].family == "ttc-win22-sql19",
      local.ami_specs["ttc-win22-sql19:1.2"].version == "1.2",
      local.ami_specs["ttc-win22-sql19:1.2"].glob == "ttc-win22-sql19_v1.2_*",
    ])
    error_message = "AMI specs should preserve caller-provided families and build the name glob in one local."
  }

  assert {
    condition = alltrue([
      contains(keys(local.amazon_machine_images), "windows_server_2025_base"),
      contains(keys(local.amazon_machine_images), "ttc-rhel8"),
      contains(keys(local.amazon_machine_images), "prod-rhel8"),
      contains(keys(local.amazon_machine_images), "ttc-win22-sql19:1.2"),
    ])
    error_message = "The unified AMI map should be keyed by public aliases and full self-built input strings."
  }

  assert {
    condition     = aws_instance.us_west_2["default-rhel"].ami == "ami-00000000000000009" && aws_instance.us_east_1["prod-rhel"].ami == "ami-00000000000000010" && aws_instance.us_west_2["selfwin01"].ami == "ami-00000000000000011"
    error_message = "Instances should launch from the resolved self-built AMI IDs."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_west_2["default-rhel"].is_windows == false,
      local.elastic_compute_cloud.us_east_1["prod-rhel"].is_windows == false,
      output.aws_instances["default-rhel"].os_family == "linux",
      output.aws_instances["prod-rhel"].os_family == "linux",
      strcontains(local.elastic_compute_cloud.us_west_2["default-rhel"].user_data, "systemctl enable --now sshd"),
      strcontains(local.elastic_compute_cloud.us_east_1["prod-rhel"].user_data, "systemctl enable --now sshd"),
    ])
    error_message = "Self-built AMIs with empty platform should classify as Linux even if platform_details is misleading."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_west_2["selfwin01"].is_windows == true,
      aws_instance.us_west_2["selfwin01"].get_password_data == true,
      local.readiness_targets["selfwin01"].is_windows == true,
      output.aws_instances["selfwin01"].os_family == "windows",
      strcontains(local.elastic_compute_cloud.us_west_2["selfwin01"].user_data, "Enable-PSRemoting -Force -SkipNetworkProfileCheck"),
    ])
    error_message = "Self-built AMIs with platform=windows should classify as Windows even if platform_details is misleading."
  }
}

run "systems_accept_raw_ami_ids_and_classify_from_platform" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "direct-win01"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-direct-windows"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ami-0123456789abcdef0"

        tags = {
          Function = "Direct Windows AMI"
        }

        network_interfaces = [
          {
            private_ip = "10.0.10.10"
          }
        ]
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

        tags = {
          Function = "Direct Linux AMI"
        }

        network_interfaces = [
          {
            private_ip = "10.1.10.10"
          }
        ]
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_west_2_direct["ami-0123456789abcdef0"]
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
    condition     = contains(keys(data.aws_ami.us_west_2_direct), "ami-0123456789abcdef0") && contains(keys(data.aws_ami.us_east_1_direct), "ami-0fedcba9876543210")
    error_message = "Raw AMI IDs should instantiate exact image-id data lookups in their target regions."
  }

  assert {
    condition     = aws_instance.us_west_2["direct-win01"].ami == "ami-0123456789abcdef0" && aws_instance.us_east_1["direct-linux"].ami == "ami-0fedcba9876543210"
    error_message = "Instances launched from raw AMI IDs should use the resolved direct AMI IDs."
  }

  assert {
    condition = alltrue([
      local.elastic_compute_cloud.us_west_2["direct-win01"].is_windows == true,
      aws_instance.us_west_2["direct-win01"].get_password_data == true,
      local.readiness_targets["direct-win01"].is_windows == true,
      output.aws_instances["direct-win01"].os_family == "windows",
      strcontains(local.elastic_compute_cloud.us_west_2["direct-win01"].user_data, "Enable-PSRemoting -Force -SkipNetworkProfileCheck"),
      strcontains(local.elastic_compute_cloud.us_west_2["direct-win01"].user_data, "Transport HTTPS"),
      strcontains(local.elastic_compute_cloud.us_west_2["direct-win01"].user_data, "LocalPort 5986"),
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
        region               = "us-west-2"
        hostname             = "win-server-01234"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        tags = {
          Function = "Windows hostname too long"
        }

        network_interfaces = [
          {
            private_ip = "10.0.7.10"
          }
        ]
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
        region               = "us-west-2"
        hostname             = "win-app-01"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-a"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        tags = {
          Function = "Valid Windows hostname"
        }

        network_interfaces = [
          {
            private_ip = "10.0.7.11"
          }
        ]
      }
    ]
  }

  assert {
    condition     = contains(keys(aws_instance.us_west_2), "win-app-01")
    error_message = "Valid Windows hostname should plan a west-region instance."
  }
}

run "systems_use_default_linux_readiness_script_path" {
  command = plan

  assert {
    condition     = "${var.ssh_readiness_linux_script_dir}/terraform_%RAND%.sh" == "/home/ec2-user/terraform_%RAND%.sh"
    error_message = "Linux readiness should upload the remote-exec script under the default /home/ec2-user directory."
  }

  assert {
    condition     = strcontains("${var.ssh_readiness_linux_script_dir}/terraform_%RAND%.sh", "%RAND%")
    error_message = "Linux readiness script_path must preserve the literal Terraform communicator %RAND% token."
  }
}

run "systems_allow_overridden_linux_readiness_script_path" {
  command = plan

  variables {
    ssh_readiness_linux_script_dir = "/opt/terraform"
  }

  assert {
    condition     = "${var.ssh_readiness_linux_script_dir}/terraform_%RAND%.sh" == "/opt/terraform/terraform_%RAND%.sh"
    error_message = "Linux readiness should upload the remote-exec script under the overridden directory."
  }

  assert {
    condition     = !strcontains("${var.ssh_readiness_linux_script_dir}/terraform_%RAND%.sh", "/tmp/") && strcontains("${var.ssh_readiness_linux_script_dir}/terraform_%RAND%.sh", "%RAND%")
    error_message = "Linux readiness script_path must avoid /tmp and preserve the literal %RAND% token when overridden."
  }
}
run "systems_render_readiness_user_data_per_os" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us-west-2"
        hostname             = "linux-ssh"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-linux"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "ttc-rhel8"

        tags = {
          Function = "Linux SSH user data"
        }

        network_interfaces = [
          {
            private_ip = "10.0.8.10"
          }
        ]
      },
      {
        region               = "us-west-2"
        hostname             = "win-ssh-01"
        availability_zone    = "us-west-2a"
        subnet_id            = "subnet-west-windows"
        key_name             = "west-key"
        iam_instance_profile = "example-instance-profile"
        aws_kms_alias        = "west"
        ami                  = "windows_server_2022_base"

        tags = {
          Function = "Windows WinRM user data"
        }

        network_interfaces = [
          {
            private_ip = "10.0.8.11"
          }
        ]
      }
    ]
  }

  override_data {
    target = data.aws_ami.us_west_2_selfbuilt["ttc-rhel8"]
    values = {
      id               = "ami-00000000000000005"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_west_2_windows_server_2022_base[0]
    values = {
      id               = "ami-00000000000000006"
      platform         = "windows"
      platform_details = "Windows"
    }
  }

  assert {
    condition     = aws_instance.us_west_2["linux-ssh"].user_data != null
    error_message = "Linux instances should receive rendered SSH user_data."
  }

  assert {
    condition     = strcontains(local.elastic_compute_cloud.us_west_2["linux-ssh"].user_data, "systemctl enable --now sshd")
    error_message = "Linux user_data should enable and start sshd."
  }

  assert {
    condition     = aws_instance.us_west_2["win-ssh-01"].user_data != null
    error_message = "Windows instances should receive rendered WinRM user_data."
  }

  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "Enable-PSRemoting -Force -SkipNetworkProfileCheck"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "WSMan:\\localhost\\Service\\Auth\\Negotiate"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "WSMan:\\localhost\\Service\\Auth\\Basic"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "WSMan:\\localhost\\Service\\AllowUnencrypted"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "New-SelfSignedCertificate"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "Transport HTTPS"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "CertificateThumbprint"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "LocalPort 5986"),
      !strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "LocalPort 5985"),
      strcontains(local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data, "Set-Service -Name WinRM -StartupType Automatic"),
    ])
    error_message = "Windows user_data should enable WinRM over HTTPS 5986, require encrypted Negotiate auth, and avoid exposing TCP 5985."
  }

  assert {
    condition = alltrue([
      strcontains(local.windows_ssh_user_data, "Add-WindowsCapability -Online -Name OpenSSH.Server"),
      strcontains(local.windows_ssh_user_data, "administrators_authorized_keys"),
    ])
    error_message = "Dormant Windows OpenSSH user_data should remain available for owner-managed AMIs."
  }

  assert {
    condition     = aws_instance.us_west_2["win-ssh-01"].get_password_data == true
    error_message = "Windows instances should compute get_password_data = true for WinRM readiness."
  }

  assert {
    condition     = local.elastic_compute_cloud.us_west_2["linux-ssh"].user_data != local.elastic_compute_cloud.us_west_2["win-ssh-01"].user_data
    error_message = "Linux and Windows user_data should differ so platform-based OS selection is covered."
  }
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
        iam_instance_profile = "example-instance-profile"
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

  override_data {
    target = data.aws_ami.us_west_2_selfbuilt["ttc-rhel8"]
    values = {
      id               = "ami-00000000000000007"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_selfbuilt["ttc-rhel8"]
    values = {
      id               = "ami-00000000000000008"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

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
    error_message = "Linux instances should compute get_password_data = false."
  }
}
