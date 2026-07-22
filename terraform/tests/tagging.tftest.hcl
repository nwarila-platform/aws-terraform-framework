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
      region               = "us_east_1"
      hostname             = "tag-host"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

      tags = {
        Function = "tagging test host"
      }

      root_block_device = {
        tags = {
          Team = "platform"
        }
      }

      network_interfaces = [
        {
          private_ip      = "10.0.0.30"
          security_groups = ["sg-preexisting"]
        }
      ]
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
      output.deployment_tags["nwarila:management:environment"] == "TEST",
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

        tags = {
          Function = "reserved prefix test"
        }

        root_block_device = {
          tags = {
            "nwarila:management:owner-override" = "me"
          }
        }

        network_interfaces = [
          {
            private_ip      = "10.0.0.31"
            security_groups = ["sg-preexisting"]
          }
        ]
      }
    ]
  }

  expect_failures = [var.resource_metadata]
}
