mock_provider "aws" {
  alias = "us_east_1"

  # The verified-image lookup asserts state; unmocked attributes come back as random
  # strings, so the default has to say what a healthy image looks like.
  mock_data "aws_ami" {
    defaults = {
      state = "available"
    }
  }

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

  all_load_balancers = [
    {
      region          = "us-east-1"
      resource_key    = "validation_alb"
      name            = "validation-alb"
      security_groups = ["sg-validation"]
      subnets         = ["subnet-validation-a", "subnet-validation-b"]

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
      tags                                                         = {}
      timeouts                                                     = null
      xff_header_processing_mode                                   = null

      target_groups = [
        {
          resource_key                      = "web"
          function                          = "Validation target"
          vpc_id                            = "vpc-validation"
          port                              = 8080
          protocol                          = "HTTP"
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
          tags                              = {}
        }
      ]

      listeners = [
        {
          resource_key                = "http"
          port                        = 80
          protocol                    = "HTTP"
          ssl_policy                  = null
          alpn_policy                 = null
          certificate_arn             = null
          additional_certificate_arns = []
          default_action = {
            type             = "forward"
            target_group_key = "web"
            redirect         = null
            fixed_response   = null
          }
          rules = [
            {
              resource_key = "health"
              priority     = 10
              action = {
                type             = "forward"
                target_group_key = "web"
                redirect         = null
                fixed_response   = null
              }
              conditions = [
                {
                  host_header         = null
                  path_pattern        = ["/health"]
                  http_request_method = null
                  source_ip           = null
                  http_header         = null
                  query_string        = null
                }
              ]
            }
          ]
        }
      ]
    },
    {
      region                           = "us-east-1"
      resource_key                     = "validation_nlb"
      name                             = "validation-nlb"
      dns_record_client_routing_policy = "any_availability_zone"
      load_balancer_type               = "network"
      security_groups                  = ["sg-validation"]

      access_logs                                                  = null
      client_keep_alive                                            = null
      connection_logs                                              = null
      customer_owned_ipv4_pool                                     = null
      desync_mitigation_mode                                       = null
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
      minimum_load_balancer_capacity                               = null
      name_prefix                                                  = null
      preserve_host_header                                         = null
      secondary_ips_auto_assigned_per_subnet                       = null
      subnets                                                      = []
      target_groups                                                = []
      listeners                                                    = []
      tags                                                         = {}
      timeouts                                                     = null
      xff_header_processing_mode                                   = null

      subnet_mapping = [
        {
          allocation_id        = null
          ipv6_address         = null
          private_ipv4_address = null
          subnet_id            = "subnet-validation-nlb"
        }
      ]
    }
  ]
}

run "rejects_invalid_repository_slug" {
  command = plan

  variables {
    repository = "missing-owner-separator"
  }

  expect_failures = [var.repository]
}

run "rejects_non_numeric_run_id" {
  command = plan

  variables {
    run_id = "not-a-number"
  }

  expect_failures = [var.run_id]
}

run "windows_fod_source_rejects_invalid_bucket_name" {
  command = plan

  variables {
    windows_fod_source = {
      bucket     = "Not_A_Bucket"
      region     = "us-east-1"
      key_prefix = "fod"
    }
  }

  expect_failures = [var.windows_fod_source]
}

run "windows_fod_source_rejects_malformed_region" {
  command = plan

  variables {
    windows_fod_source = {
      bucket     = "123456789012-apprepo"
      region     = "us_east_1"
      key_prefix = "fod"
    }
  }

  expect_failures = [var.windows_fod_source]
}

run "windows_fod_source_rejects_slashed_or_empty_key_prefix" {
  command = plan

  variables {
    windows_fod_source = {
      bucket     = "123456789012-apprepo"
      region     = "us-east-1"
      key_prefix = "/fod/"
    }
  }

  expect_failures = [var.windows_fod_source]
}

run "all_systems_rejects_null_region" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = null
        hostname                   = "null-region"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-validation"
        key_name                   = "validation-key"
        iam_instance_profile       = "validation-profile"
        aws_kms_alias              = "validation"
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
          Function = "Null region validation"
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
            description    = null
            interface_type = null
            # Non-null on both, so the null region also reaches the security-group name
            # uniqueness rule - the second place that normalizes a region.
            ingress         = []
            egress          = []
            private_ip      = null
            security_groups = ["sg-validation"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_databases_rejects_null_region" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = null
        availability_zone                   = "us-east-1a"
        db_name                             = "nullregion"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        instance_class                      = "db.t3.micro"
        manage_master_user_password         = true
        username                            = "dbadmin"
        aws_kms_alias                       = "validation"
        allocated_storage                   = "100"
        backup_retention_period             = null
        backup_window                       = null
        blue_green_update                   = false
        ca_cert_identifier                  = null
        dedicated_log_volume                = true
        delete_automated_backups            = true
        deletion_protection                 = true
        max_allocated_storage               = "1000"
        skip_final_snapshot                 = false
        storage_type                        = "gp3"
        vpc_security_group_ids              = ["sg-validation"]
        tags = {
          Backup   = true
          Function = "Null region validation"
        }
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "all_systems_rejects_null_aws_kms_alias" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "null-kms-alias"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-validation"
        key_name                   = "validation-key"
        iam_instance_profile       = "validation-profile"
        aws_kms_alias              = null
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
          Function = "Null KMS alias validation"
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
            security_groups = ["sg-validation"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_systems_rejects_null_tags" {
  command = plan

  variables {
    all_systems = [
      {
        region                     = "us-east-1"
        hostname                   = "null-tags"
        availability_zone          = "us-east-1a"
        subnet_id                  = "subnet-validation"
        key_name                   = "validation-key"
        iam_instance_profile       = "validation-profile"
        aws_kms_alias              = "validation"
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
        tags                       = null
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
            security_groups = ["sg-validation"]
            tags            = {}
          }
        ]
        associate_public_ip = false
      }
    ]
  }

  expect_failures = [var.all_systems]
}

run "all_databases_rejects_null_tags" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "nulltags"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        instance_class                      = "db.t3.micro"
        manage_master_user_password         = true
        username                            = "dbadmin"
        aws_kms_alias                       = "validation"
        allocated_storage                   = "100"
        backup_retention_period             = null
        backup_window                       = null
        blue_green_update                   = false
        ca_cert_identifier                  = null
        dedicated_log_volume                = true
        delete_automated_backups            = true
        deletion_protection                 = true
        max_allocated_storage               = "1000"
        skip_final_snapshot                 = false
        storage_type                        = "gp3"
        vpc_security_group_ids              = ["sg-validation"]
        tags                                = null
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "all_databases_rejects_null_db_name" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = null
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        instance_class                      = "db.t3.micro"
        manage_master_user_password         = true
        username                            = "dbadmin"
        aws_kms_alias                       = "validation"
        allocated_storage                   = "100"
        backup_retention_period             = null
        backup_window                       = null
        blue_green_update                   = false
        ca_cert_identifier                  = null
        dedicated_log_volume                = true
        delete_automated_backups            = true
        deletion_protection                 = true
        max_allocated_storage               = "1000"
        skip_final_snapshot                 = false
        storage_type                        = "gp3"
        vpc_security_group_ids              = ["sg-validation"]
        tags = {
          Backup   = true
          Function = "Null database name validation"
        }
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "all_databases_rejects_null_aws_kms_alias" {
  command = plan

  variables {
    all_databases = [
      {
        region                              = "us-east-1"
        availability_zone                   = "us-east-1a"
        db_name                             = "nullkmsalias"
        db_subnet_group_name                = "db-subnets"
        engine                              = "postgres"
        engine_version                      = "16.3"
        iam_database_authentication_enabled = false
        instance_class                      = "db.t3.micro"
        manage_master_user_password         = true
        username                            = "dbadmin"
        aws_kms_alias                       = null
        allocated_storage                   = "100"
        backup_retention_period             = null
        backup_window                       = null
        blue_green_update                   = false
        ca_cert_identifier                  = null
        dedicated_log_volume                = true
        delete_automated_backups            = true
        deletion_protection                 = true
        max_allocated_storage               = "1000"
        skip_final_snapshot                 = false
        storage_type                        = "gp3"
        vpc_security_group_ids              = ["sg-validation"]
        tags = {
          Backup   = true
          Function = "Null KMS alias validation"
        }
      }
    ]
  }

  expect_failures = [var.all_databases]
}

run "load_balancers_reject_duplicate_resource_keys" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        resource_key = "duplicate"
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_invalid_resource_key_characters" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        resource_key = (
          load_balancer.resource_key == "validation_alb" ?
          "invalid key" : load_balancer.resource_key
        )
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_missing_subnet_selection" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        subnets        = []
        subnet_mapping = []
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_regions_outside_aws_config" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        region = "eu-west-1"
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "all_load_balancers_rejects_null_region" {
  command = plan

  variables {
    all_load_balancers = [
      merge(var.all_load_balancers[0], {
        region = null
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_internal_dualstack_addressing" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        ip_address_type = "dualstack"
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_invalid_target_group_resource_key_characters" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        target_groups = concat(
          load_balancer.target_groups,
          [
            for target_group in load_balancer.target_groups : merge(target_group, {
              resource_key = "invalid key"
            })
          ]
        )
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_duplicate_listener_resource_keys" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = concat(load_balancer.listeners, load_balancer.listeners)
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_missing_rule_target_group_key_reference" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          for listener in load_balancer.listeners : merge(listener, {
            rules = [
              for rule in listener.rules : merge(rule, {
                action = merge(rule.action, {
                  target_group_key = "missing"
                })
              })
            ]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_rule_action_payload_mismatching_type" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          for listener in load_balancer.listeners : merge(listener, {
            rules = [
              for rule in listener.rules : merge(rule, {
                action = merge(rule.action, {
                  redirect = {
                    host        = null
                    path        = null
                    port        = null
                    protocol    = null
                    query       = null
                    status_code = "HTTP_301"
                  }
                })
              })
            ]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_empty_target_group_function" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        target_groups = [
          for target_group in load_balancer.target_groups : merge(target_group, {
            function = " "
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_rules_without_conditions" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          for listener in load_balancer.listeners : merge(listener, {
            rules = [
              for rule in listener.rules : merge(rule, {
                conditions = []
              })
            ]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_empty_rule_condition_values" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          for listener in load_balancer.listeners : merge(listener, {
            rules = [
              for rule in listener.rules : merge(rule, {
                conditions = [
                  for condition in rule.conditions : merge(condition, {
                    path_pattern = []
                  })
                ]
              })
            ]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}

run "load_balancers_reject_duplicate_additional_certificate_arns" {
  command = plan

  variables {
    all_load_balancers = [
      for load_balancer in var.all_load_balancers : merge(load_balancer, {
        listeners = [
          for listener in load_balancer.listeners : merge(listener, {
            additional_certificate_arns = ["duplicate", "duplicate"]
          })
        ]
      })
    ]
  }

  expect_failures = [var.all_load_balancers]
}
