mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_ami" {
    defaults = {
      block_device_mappings = []
      platform              = ""
      platform_details      = "Linux/UNIX"
      root_device_name      = "/dev/sda1"
      state                 = "available"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      availability_zone = "us-east-1a"
      cidr_block        = "10.0.0.0/8"
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
      region               = "us-east-1"
      hostname             = "c"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-c"
      key_name             = "cluster-key"
      iam_instance_profile = "cluster-instance-profile"
      aws_kms_alias        = "system-stable"
      ami                  = "test-linux"
      refresh              = false

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
        Function = "Stable cluster node"
        Backup   = true
      }

      root_block_device = {
        iops        = null
        tags        = {}
        throughput  = null
        volume_size = "100"
        volume_type = "gp3"
      }

      ebs_block_devices = [
        {
          resource_key = "standalone"
          device_index = 0
          iops         = null
          snapshot_id  = null
          tags         = {}
          throughput   = null
          volume_size  = "20"
          volume_type  = "gp3"
        }
      ]

      ami_block_device_overrides = [
        {
          device_name = "/dev/sdf"
          iops        = null
          throughput  = null
          volume_size = "20"
          volume_type = "gp3"
        }
      ]

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
      hostname             = "b-c"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-b-c"
      key_name             = "cluster-key"
      iam_instance_profile = "cluster-instance-profile"
      aws_kms_alias        = "system-refresh"
      ami                  = "test-windows"
      refresh              = true

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
        Function = "Refresh cluster node"
        Backup   = true
      }

      root_block_device = {
        iops        = null
        tags        = {}
        throughput  = null
        volume_size = "100"
        volume_type = "gp3"
      }

      ebs_block_devices = [
        {
          resource_key = "standalone"
          device_index = 0
          iops         = null
          snapshot_id  = null
          tags         = {}
          throughput   = null
          volume_size  = "20"
          volume_type  = "gp3"
        }
      ]

      ami_block_device_overrides = [
        {
          device_name = "xvdg"
          iops        = null
          throughput  = null
          volume_size = "20"
          volume_type = "gp3"
        }
      ]

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
    }
  ]

  all_databases = [
    {
      region                              = "us-east-1"
      availability_zone                   = "us-east-1a"
      db_name                             = "clusterdb"
      instance_class                      = "db.t3.micro"
      db_subnet_group_name                = "db-subnets"
      engine                              = "postgres"
      engine_version                      = "16.3"
      iam_database_authentication_enabled = false
      username                            = "dbadmin"
      aws_kms_alias                       = "database-only"
      vpc_security_group_ids              = ["sg-22222222"]
      manage_master_user_password         = true

      tags = {
        Function = "Cluster database"
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

run "shared_ebs_volumes_default_is_structurally_isolated" {
  command = plan

  assert {
    condition = (
      toset(keys(local.ebs_block_devices.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ]) &&
      toset(keys(aws_ebs_volume.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ])
    )
    error_message = "Omitting shared_ebs_volumes must preserve the exact standalone volume keys."
  }

  assert {
    condition = (
      toset(keys(local.ebs_volume_attachments.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ]) &&
      toset(keys(aws_volume_attachment.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ])
    )
    error_message = "Omitting shared_ebs_volumes must preserve the exact merged attachment keys."
  }

  assert {
    condition = toset(keys(data.aws_kms_alias.us_east_1)) == toset([
      "database-only",
      "system-refresh",
      "system-stable",
    ])
    error_message = "Omitting shared_ebs_volumes must preserve the exact existing KMS lookup keys."
  }

  assert {
    condition = alltrue([
      for volume in values(aws_ebs_volume.us_east_1) :
      volume.multi_attach_enabled == null
    ])
    error_message = "Omitting shared_ebs_volumes must omit Multi-Attach on standalone volumes."
  }
}

run "shared_ebs_volumes_explicit_null_uses_the_default" {
  command = plan

  variables {
    shared_ebs_volumes = null
  }

  assert {
    condition = (
      length(var.shared_ebs_volumes) == 0 &&
      toset(keys(local.ebs_block_devices.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ]) &&
      toset(keys(aws_ebs_volume.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ]) &&
      toset(keys(local.ebs_volume_attachments.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ]) &&
      toset(keys(aws_volume_attachment.us_east_1)) == toset([
        "b-c-ebs-standalone",
        "c-ebs-standalone",
      ]) &&
      toset(keys(data.aws_kms_alias.us_east_1)) == toset([
        "database-only",
        "system-refresh",
        "system-stable",
      ]) &&
      alltrue([
        for volume in values(aws_ebs_volume.us_east_1) :
        volume.multi_attach_enabled == null
      ])
    )
    error_message = "Explicit null must substitute the empty default and preserve default behavior."
  }
}

run "shared_ebs_volume_spans_stable_and_refresh_hosts" {
  command = plan

  variables {
    shared_ebs_volumes = {
      "cluster-data" = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          Backup     = "consumer-backup"
          DeviceName = "consumer-device"
          Function   = "Cluster data"
          Index      = "consumer-index"
          OS         = "consumer-os"
        }
        attachments = [
          {
            hostname     = "c"
            device_index = 1
          },
          {
            hostname     = "b-c"
            device_index = 1
          }
        ]
      }
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      id               = "ami-00000000000000001"
      platform         = ""
      platform_details = "Linux/UNIX"
      state            = "available"
    }
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["test-windows"]
    values = {
      id               = "ami-00000000000000002"
      platform         = "windows"
      platform_details = "Windows"
      state            = "available"
    }
  }

  override_data {
    target = data.aws_kms_alias.us_east_1["shared-only"]
    values = {
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/22222222-2222-2222-2222-${join("", ["222222", "222222"])}"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1["c"]
    override_during = plan
    values = {
      id = "i-stable-node"
    }
  }

  override_resource {
    target          = aws_instance.us_east_1_refresh["b-c"]
    override_during = plan
    values = {
      id = "i-refresh-node"
    }
  }

  override_resource {
    target          = aws_ebs_volume.us_east_1["cluster-data"]
    override_during = plan
    values = {
      id = "vol-shared-cluster-data"
    }
  }

  assert {
    condition = alltrue([
      length([for volume in values(aws_ebs_volume.us_east_1) : volume if volume.multi_attach_enabled == true]) == 1,
      aws_ebs_volume.us_east_1["cluster-data"].multi_attach_enabled == true,
      aws_ebs_volume.us_east_1["cluster-data"].type == "io2",
      aws_ebs_volume.us_east_1["cluster-data"].encrypted == true,
      aws_ebs_volume.us_east_1["cluster-data"].iops == 3000,
      aws_ebs_volume.us_east_1["cluster-data"].size == 100,
    ])
    error_message = "The shared resource must plan exactly one encrypted io2 Multi-Attach volume."
  }

  assert {
    condition = alltrue([
      contains(keys(data.aws_kms_alias.us_east_1), "shared-only"),
      aws_ebs_volume.us_east_1["cluster-data"].kms_key_id == data.aws_kms_alias.us_east_1["shared-only"].target_key_arn,
    ])
    error_message = "A shared-only KMS alias must be looked up and wired into the shared volume."
  }

  assert {
    condition = alltrue([
      aws_ebs_volume.us_east_1["cluster-data"].tags["Name"] == "cluster-data",
      aws_ebs_volume.us_east_1["cluster-data"].tags["Function"] == "Cluster data",
      aws_ebs_volume.us_east_1["cluster-data"].tags["ManagedBy"] == "Terraform",
      aws_ebs_volume.us_east_1["cluster-data"].tags["OS"] == "consumer-os",
      aws_ebs_volume.us_east_1["cluster-data"].tags["Index"] == "consumer-index",
      aws_ebs_volume.us_east_1["cluster-data"].tags["DeviceName"] == "consumer-device",
      aws_ebs_volume.us_east_1["cluster-data"].tags["Backup"] == "consumer-backup",
      !contains(keys(output.ebs_volumes), "cluster-data"),
    ])
    error_message = "Shared tags must pass through while the standalone output excludes the volume."
  }

  assert {
    condition = alltrue([
      contains(keys(aws_instance.us_east_1), "c"),
      contains(keys(aws_instance.us_east_1_refresh), "b-c"),
      local.all_ec2_instances["c"].id == "i-stable-node",
      local.all_ec2_instances["b-c"].id == "i-refresh-node",
      length([for key in keys(aws_volume_attachment.us_east_1) : key if startswith(key, "[")]) == 2,
    ])
    error_message = "One shared attachment resource must resolve both stable and refresh instances."
  }

  assert {
    condition = alltrue([
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "c"])].device_name == "/dev/sde",
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "c"])].instance_id == "i-stable-node",
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "c"])].volume_id == "vol-shared-cluster-data",
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "c"])].skip_destroy == false,
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "c"])].stop_instance_before_detaching == true,
    ])
    error_message = "The Linux stable attachment must preserve per-host device and lifecycle wiring."
  }

  assert {
    condition = alltrue([
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "b-c"])].device_name == "xvde",
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "b-c"])].instance_id == "i-refresh-node",
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "b-c"])].volume_id == "vol-shared-cluster-data",
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "b-c"])].skip_destroy == false,
      aws_volume_attachment.us_east_1[jsonencode(["cluster-data", "b-c"])].stop_instance_before_detaching == true,
    ])
    error_message = "The Windows refresh attachment must preserve per-host device and lifecycle wiring."
  }
}

run "shared_attachment_keys_encode_the_full_tuple" {
  command = plan

  variables {
    shared_ebs_volumes = {
      "a-b" = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [
          {
            hostname     = "c"
            device_index = 1
          }
        ]
      }
      "a" = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [
          {
            hostname     = "b-c"
            device_index = 1
          }
        ]
      }
    }
  }

  assert {
    condition = toset(keys(local.ebs_volume_attachments.us_east_1)) == toset([
      "b-c-ebs-standalone",
      "c-ebs-standalone",
      jsonencode(["a-b", "c"]),
      jsonencode(["a", "b-c"]),
    ])
    error_message = "Encoded tuple keys must distinguish [\"a-b\",\"c\"] from [\"a\",\"b-c\"]."
  }

  assert {
    condition = toset(keys(aws_volume_attachment.us_east_1)) == toset([
      "b-c-ebs-standalone",
      "c-ebs-standalone",
      jsonencode(["a-b", "c"]),
      jsonencode(["a", "b-c"]),
    ])
    error_message = "Shared attachment resource keys must use the unambiguous encoded tuples."
  }
}

run "standalone_ebs_volumes_reject_ambiguous_generated_keys" {
  command = plan

  variables {
    all_systems = [
      for index, system in var.all_systems : merge(system, {
        hostname = index == 0 ? "a" : "a-ebs-b"
        ebs_block_devices = [
          merge(system.ebs_block_devices[0], {
            resource_key = index == 0 ? "b-ebs-c" : "c"
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_systems]
}

run "shared_ebs_volumes_reject_standalone_shared_device_claim_collision" {
  command = plan

  variables {
    shared_ebs_volumes = {
      collision = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "c"
          device_index = 0
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_shared_shared_device_claim_collision" {
  command = plan

  variables {
    shared_ebs_volumes = {
      first = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
      second = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_sd_ami_override_collision" {
  command = plan

  variables {
    shared_ebs_volumes = {
      collision = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "c"
          device_index = 2
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_xvd_ami_override_collision" {
  command = plan

  variables {
    shared_ebs_volumes = {
      xvd-spelling = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "b-c"
          device_index = 3
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_missing_host" {
  command = plan

  variables {
    shared_ebs_volumes = {
      missing = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "missing-host"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_cross_zone_host" {
  command = plan

  variables {
    shared_ebs_volumes = {
      cross-zone = {
        region            = "us-east-1"
        availability_zone = "us-east-1b"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_duplicate_hostname" {
  command = plan

  variables {
    shared_ebs_volumes = {
      duplicate = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [
          {
            hostname     = "c"
            device_index = 1
          },
          {
            hostname     = "c"
            device_index = 3
          }
        ]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_more_than_16_attachments" {
  command = plan

  variables {
    all_systems = [
      for index in range(17) : merge(var.all_systems[0], {
        hostname                   = "node-${index}"
        subnet_id                  = "subnet-node-${index}"
        ebs_block_devices          = []
        ami_block_device_overrides = []
        network_interfaces = [
          merge(var.all_systems[0].network_interfaces[0], {
            private_ip = "10.1.0.${index + 10}"
          })
        ]
      })
    ]

    shared_ebs_volumes = {
      too-many = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [
          for index in range(17) : {
            hostname     = "node-${index}"
            device_index = 0
          }
        ]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_kms_alias_prefix" {
  command = plan

  variables {
    shared_ebs_volumes = {
      malformed-kms = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "alias/shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_name_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-name = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          name = "consumer-owned-name"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_commit_sha_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-commit-sha = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          CommitSha = "consumer-owned-commit"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_environment_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-environment = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          Environment = "consumer-owned-environment"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_managed_by_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-managed-by = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          ManagedBy = "consumer-owned-manager"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_repository_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-repository = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          Repository = "consumer-owned-repository"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_repository_id_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-repository-id = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          RepositoryId = "consumer-owned-repository-id"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_reserved_run_id_tag" {
  command = plan

  variables {
    shared_ebs_volumes = {
      reserved-run-id = {
        region            = "us-east-1"
        availability_zone = "us-east-1a"
        aws_kms_alias     = "shared-only"
        iops              = "3000"
        volume_size       = "100"
        tags = {
          RunId = "consumer-owned-run-id"
        }
        attachments = [{
          hostname     = "c"
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_iops" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-iops = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = null
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_region" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-region = {
        region            = null
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_availability_zone" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-availability-zone = {
        region            = var.all_systems[0].region
        availability_zone = null
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_aws_kms_alias" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-aws-kms-alias = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = null
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_volume_size" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-volume-size = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = null
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_volume_object" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-volume = null
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_tags" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-tags = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = null
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_attachments" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-attachments = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments       = null
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_hostname" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-hostname = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = null
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_null_device_index" {
  command = plan

  variables {
    shared_ebs_volumes = {
      null-device-index = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = null
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_volume_key_collision" {
  command = plan

  variables {
    shared_ebs_volumes = {
      c-ebs-standalone = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_empty_attachments" {
  command = plan

  variables {
    shared_ebs_volumes = {
      empty-attachments = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments       = []
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_unknown_region" {
  command = plan

  variables {
    shared_ebs_volumes = {
      unknown-region = {
        region            = "us_west_2"
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_fractional_device_index" {
  command = plan

  variables {
    shared_ebs_volumes = {
      fractional-device-index = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 1.5
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_device_index_above_range" {
  command = plan

  variables {
    shared_ebs_volumes = {
      high-device-index = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = 23
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}

run "shared_ebs_volumes_reject_negative_device_index" {
  command = plan

  variables {
    shared_ebs_volumes = {
      negative-device-index = {
        region            = var.all_systems[0].region
        availability_zone = var.all_systems[0].availability_zone
        aws_kms_alias     = var.all_systems[0].aws_kms_alias
        iops              = "3000"
        volume_size       = "100"
        tags              = {}
        attachments = [{
          hostname     = var.all_systems[0].hostname
          device_index = -1
        }]
      }
    }
  }

  expect_failures = [var.shared_ebs_volumes]
}
