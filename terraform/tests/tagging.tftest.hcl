mock_provider "aws" {
  alias = "us_east_1"
}

variables {
  environment = "test"

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

      refresh        = false
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = true
      imds_hop_limit = 1
      set_state      = null

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

      ebs_block_devices = []

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

run "null_metadata_emits_zero_tags" {
  command = plan

  assert {
    condition     = length(output.deployment_tags) == 0
    error_message = "deployment_tags must be empty when resource_metadata is unset (zero-diff for non-opted-in consumers)."
  }

  assert {
    condition     = !contains(keys(aws_instance.us_east_1["tag-host"].root_block_device[0].tags), "nwarila:management:managed-by")
    error_message = "Root volumes must carry no nwarila tags when resource_metadata is unset."
  }
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
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "wsus-poc-us-east-1"
      owner         = "platform-engineering"
      commit_sha    = "0123456789abcdef0123456789abcdef01234567"
      run_id        = "1234567890"
    }
  }

  assert {
    condition     = length(output.deployment_tags) == 8
    error_message = "Six stable keys plus commit-sha and run-id must be emitted when fully populated."
  }

  assert {
    condition = alltrue([
      output.deployment_tags["nwarila:management:managed-by"] == "terraform",
      output.deployment_tags["nwarila:management:environment"] == "test",
      output.deployment_tags["nwarila:provenance:commit-sha"] == "0123456789abcdef0123456789abcdef01234567",
      output.deployment_tags["nwarila:provenance:run-id"] == "1234567890",
    ])
    error_message = "deployment_tags must expose managed-by, the var.environment value, and both provenance pointers verbatim."
  }

  assert {
    condition     = aws_instance.us_east_1["tag-host"].root_block_device[0].tags["nwarila:provenance:commit-sha"] == "0123456789abcdef0123456789abcdef01234567"
    error_message = "Root volume tags must include the deployment identity (provider default_tags cannot reach root_block_device)."
  }

  assert {
    condition     = aws_instance.us_east_1["tag-host"].root_block_device[0].tags["Team"] == "platform"
    error_message = "User-supplied root volume tags must be preserved alongside identity tags."
  }
}

run "stable_only_metadata_omits_provenance_keys" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "wazuh-standing-us-east-1"
      owner         = "platform-engineering"
      commit_sha    = null
      run_id        = null
    }
  }

  assert {
    condition     = length(output.deployment_tags) == 6 && !contains(keys(output.deployment_tags), "nwarila:provenance:commit-sha")
    error_message = "Unset commit_sha/run_id must omit the provenance keys entirely, not emit empty values."
  }
}

run "rejects_github_sha_style_uppercase" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "s"
      owner         = "o"
      commit_sha    = "ABC123"
      run_id        = null
    }
  }

  expect_failures = [var.resource_metadata]
}

run "rejects_non_numeric_repository_id" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "not-a-number"
      stack         = "s"
      owner         = "o"
      commit_sha    = null
      run_id        = null
    }
  }

  expect_failures = [var.resource_metadata]
}

run "rejects_metadata_tag_value_over_256_characters" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = join("", [for index in range(257) : "s"])
      owner         = "o"
      commit_sha    = null
      run_id        = null
    }
  }

  expect_failures = [var.resource_metadata]
}

run "rejects_reserved_prefix_in_consumer_tags" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "s"
      owner         = "o"
      commit_sha    = null
      run_id        = null
    }

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

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = true
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "reserved prefix test"
          Backup   = true
        }

        root_block_device = {
          tags = {
            "nwarila:management:owner-override" = "me"
          }
          delete_on_termination = true
          iops                  = null
          throughput            = null
          volume_type           = "gp3"
          volume_size           = "100"
        }

        ebs_block_devices = []

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

  expect_failures = [var.resource_metadata]
}

run "rejects_reserved_prefix_in_load_balancer_tags" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "s"
      owner         = "o"
      commit_sha    = null
      run_id        = null
    }

    all_load_balancers = [
      {
        region          = "us-east-1"
        resource_key    = "reserved_lb_tags"
        name            = "reserved-lb-tags"
        security_groups = ["sg-reserved"]
        subnets         = ["subnet-reserved-a", "subnet-reserved-b"]

        tags = {
          "nwarila:management:owner-override" = "me"
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

  expect_failures = [var.resource_metadata]
}

run "rejects_reserved_prefix_in_target_group_tags" {
  command = plan

  variables {
    resource_metadata = {
      repository    = "nwarila-platform/aws-terraform-framework"
      repository_id = "123456789"
      stack         = "s"
      owner         = "o"
      commit_sha    = null
      run_id        = null
    }

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
              "nwarila:operations:owner-override" = "me"
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

  expect_failures = [var.resource_metadata]
}
