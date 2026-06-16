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
      region            = "us-west-2"
      hostname          = "west-state"
      availability_zone = "us-west-2a"
      subnet_id         = "subnet-west-a"
      key_name          = "west-key"
      aws_kms_alias     = "alias/west"
      set_state         = "stopped"

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
      region            = "us_west_2"
      hostname          = "west-no-state"
      availability_zone = "us-west-2a"
      subnet_id         = "subnet-west-b"
      key_name          = "west-key"
      aws_kms_alias     = "alias/west"

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
      region            = "us-west-2"
      hostname          = "west-refresh"
      availability_zone = "us-west-2b"
      subnet_id         = "subnet-west-c"
      key_name          = "west-key"
      aws_kms_alias     = "alias/west"
      refresh           = true

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
      region            = "us-east-1"
      hostname          = "east-state"
      availability_zone = "us-east-1a"
      subnet_id         = "subnet-east-a"
      key_name          = "east-key"
      aws_kms_alias     = "alias/east"
      set_state         = "running"

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
