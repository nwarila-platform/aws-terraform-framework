mock_provider "aws" {
  alias = "us_east_1"

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
      target_key_arn = "arn:aws:kms:us-east-1:${join("", ["123456", "789012"])}:key/00000000-0000-0000-0000-${join("", ["000000", "000000"])}"
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
      hostname             = "tag-host"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

      refresh                    = false
      instance_type              = "m6i.large"
      readiness_user             = null
      readiness_command          = null
      readiness_script_dir       = null
      readiness_private_key_path = null
      readiness_gate             = true
      imds_hop_limit             = 1
      set_state                  = null

      tags = {
        Function = "tagging test host"
        Backup   = true
      }

      root_block_device = {
        tags = {
          Team = "platform"
        }
        delete_on_termination = true
        iops                  = null
        throughput            = null
        volume_type           = "gp3"
        volume_size           = "100"
      }

      ebs_block_devices = [
        {
          resource_key = "data"
          device_index = 0
          volume_size  = "10"
          iops         = null
          snapshot_id  = null
          skip_destroy = false
          tags         = {}
          throughput   = null
          volume_type  = "gp3"
        }
      ]

      ami_block_device_overrides = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.30"
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

run "rejects_environment_outside_lowercase_set" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

# Case variants are rejected too: the value reaches the Environment tag verbatim, so "dev" and
# "DEV" would otherwise be two different values in every tag-based inventory query.
run "rejects_uppercase_environment_case_variant" {
  command = plan

  variables {
    environment = "DEV"
  }

  expect_failures = [var.environment]
}

run "accepts_prod_environment" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = aws_instance.us_east_1["tag-host"].tags["Environment"] == "prod"
    error_message = "A supported environment value must reach the Environment tag verbatim."
  }
}

run "full_metadata_stamps_identity_and_provenance" {
  command = plan

  variables {
    repository    = "nwarila-platform/aws-terraform-framework"
    repository_id = "123456789"
    commit_sha    = "0123456789abcdef0123456789abcdef01234567"
    run_id        = "1234567890"
  }

  # Identity is written into each tag map rather than exported as a helper value, so the
  # instance's own tags are the record. All eight keys, on the resource itself.
  assert {
    condition = alltrue([
      aws_instance.us_east_1["tag-host"].tags["ManagedBy"] == "Terraform",
      aws_instance.us_east_1["tag-host"].tags["Name"] == "tag-host",
      aws_instance.us_east_1["tag-host"].tags["OS"] == data.aws_ami.us_east_1_selfbuilt["test-linux"].platform_details,
      aws_instance.us_east_1["tag-host"].tags["Repository"] == "nwarila-platform/aws-terraform-framework",
      aws_instance.us_east_1["tag-host"].tags["RepositoryId"] == "123456789",
      aws_instance.us_east_1["tag-host"].tags["Environment"] == "test",
      aws_instance.us_east_1["tag-host"].tags["CommitSha"] == "0123456789abcdef0123456789abcdef01234567",
      aws_instance.us_east_1["tag-host"].tags["RunId"] == "1234567890",
    ])
    error_message = "Instance tags must carry all eight deployment-identity keys verbatim."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_instance.us_east_1["tag-host"].root_block_device[0].tags[key] == {
        Name         = "tag-host"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "1234567890"
      }[key]
    ])
    error_message = "Root volume tags must carry all seven deployment-identity keys verbatim."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_network_interface.us_east_1["tag-host-eni-0"].tags[key] == {
        Name         = "tag-host"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "1234567890"
      }[key]
    ])
    error_message = "Network interface tags must carry all seven deployment-identity keys verbatim."
  }

  assert {
    condition = alltrue([
      for key in ["Name", "Environment", "ManagedBy", "Repository", "RepositoryId", "CommitSha", "RunId"] :
      aws_ebs_volume.us_east_1["tag-host-ebs-data"].tags[key] == {
        Name         = "tag-host"
        Environment  = "test"
        ManagedBy    = "Terraform"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        CommitSha    = "0123456789abcdef0123456789abcdef01234567"
        RunId        = "1234567890"
      }[key]
    ])
    error_message = "EBS volume tags must carry all seven deployment-identity keys verbatim."
  }

  assert {
    condition     = aws_instance.us_east_1["tag-host"].root_block_device[0].tags["Team"] == "platform"
    error_message = "User-supplied root volume tags must be preserved alongside identity tags."
  }
}

run "rejects_github_sha_style_uppercase" {
  command = plan

  variables {
    repository    = "nwarila-platform/aws-terraform-framework"
    repository_id = "123456789"
    commit_sha    = "ABC123"
  }

  expect_failures = [var.commit_sha]
}

run "rejects_non_numeric_repository_id" {
  command = plan

  variables {
    repository    = "nwarila-platform/aws-terraform-framework"
    repository_id = "not-a-number"
  }

  expect_failures = [var.repository_id]
}

run "rejects_reserved_prefix_in_consumer_tags" {
  command = plan

  variables {
    repository    = "nwarila-platform/aws-terraform-framework"
    repository_id = "123456789"

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "sneaky-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh                    = false
        instance_type              = "m6i.large"
        readiness_user             = null
        readiness_command          = null
        readiness_script_dir       = null
        readiness_private_key_path = null
        readiness_gate             = true
        imds_hop_limit             = 1
        set_state                  = null

        tags = {
          Function = "reserved prefix test"
          Backup   = true
        }

        root_block_device = {
          tags = {
            "Repository" = "me"
          }
          delete_on_termination = true
          iops                  = null
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        ebs_block_devices = []

        ami_block_device_overrides = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.31"
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

run "rejects_reserved_prefix_in_load_balancer_tags" {
  command = plan

  variables {
    repository    = "nwarila-platform/aws-terraform-framework"
    repository_id = "123456789"

    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "reserved_lb_tags"
        name            = "reserved-lb-tags"
        security_groups = ["sg-reserved"]
        subnets         = ["subnet-reserved-a", "subnet-reserved-b"]

        tags = {
          "Repository" = "me"
        }
        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        target_groups                                                = []
        listeners                                                    = []
        timeouts                                                     = null
        xff_header_processing_mode                                   = null
      }
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "rejects_reserved_prefix_in_target_group_tags" {
  command = plan

  variables {
    repository    = "nwarila-platform/aws-terraform-framework"
    repository_id = "123456789"

    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "reserved_tg_tags"
        name            = "reserved-tg-tags"
        security_groups = ["sg-reserved"]
        subnets         = ["subnet-reserved-a", "subnet-reserved-b"]

        target_groups = [
          {
            resource_key = "reserved"
            function     = "Reserved tag test"
            vpc_id       = "vpc-reserved"
            port         = 8080
            protocol     = "HTTP"

            tags = {
              "Repository" = "me"
            }
            protocol_version                  = null
            target_type                       = "instance"
            deregistration_delay              = null
            slow_start                        = null
            load_balancing_algorithm_type     = null
            load_balancing_anomaly_mitigation = null
            load_balancing_cross_zone_enabled = null
            preserve_client_ip                = null
            proxy_protocol_v2                 = null
            connection_termination            = null
            ip_address_type                   = null
            health_check                      = null
            stickiness                        = null
          }
        ]
        access_logs                                                  = null
        client_keep_alive                                            = null
        connection_logs                                              = null
        customer_owned_ipv4_pool                                     = null
        desync_mitigation_mode                                       = null
        dns_record_client_routing_policy                             = null
        drop_invalid_header_fields                                   = null
        enable_cross_zone_load_balancing                             = null
        enable_deletion_protection                                   = true
        enable_http2                                                 = null
        enable_tls_version_and_cipher_suite_headers                  = null
        enable_waf_fail_open                                         = null
        enable_xff_client_port                                       = null
        enable_zonal_shift                                           = null
        enforce_security_group_inbound_rules_on_private_link_traffic = null
        health_check_logs                                            = null
        idle_timeout                                                 = null
        internal                                                     = true
        ip_address_type                                              = "ipv4"
        ipam_pools                                                   = null
        load_balancer_type                                           = "application"
        minimum_load_balancer_capacity                               = null
        name_prefix                                                  = null
        preserve_host_header                                         = null
        secondary_ips_auto_assigned_per_subnet                       = null
        subnet_mapping                                               = []
        listeners                                                    = []
        tags                                                         = {}
        timeouts                                                     = null
        xff_header_processing_mode                                   = null
      }
    ]
  }

  expect_failures = [var.all_load_balancers]
}
