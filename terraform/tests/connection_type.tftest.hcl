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
      vpc_id            = "vpc-connectiontype"
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
      hostname             = "win-transport"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-transport"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "windows@2022"

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
        Function = "Transport selection subject"
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
          private_ip      = "10.0.30.10"
          security_groups = ["sg-0123456789abcdef0"]
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

# Null takes the SSH default: the key-install bootstrap, and no password fetch.
run "windows_defaults_to_ssh_and_fetches_no_password" {
  command = plan

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      id       = "ami-00000000000000021"
      platform = "windows"
    }
  }

  assert {
    condition = (
      local.elastic_compute_cloud.us_east_1["win-transport"].connection_type == "ssh" &&
      local.elastic_compute_cloud.us_east_1["win-transport"].get_password_data == false
    )
    error_message = "A null connection_type must select SSH and leave get_password_data off."
  }

  assert {
    condition = (
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "administrators_authorized_keys") &&
      !strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "WSMan")
    )
    error_message = "The SSH transport must render the key-install bootstrap, not the WinRM one."
  }

  assert {
    condition     = aws_instance.us_east_1["win-transport"].get_password_data == false
    error_message = "get_password_data must stay off on the SSH path, where the launch password is unused."
  }
}

# WinRM renders the WS-Management bootstrap and turns the password fetch on.
run "windows_winrm_renders_wsman_bootstrap_and_fetches_password" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        connection_type = "winrm"
      })
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      id       = "ami-00000000000000021"
      platform = "windows"
    }
  }

  assert {
    condition = (
      local.elastic_compute_cloud.us_east_1["win-transport"].connection_type == "winrm" &&
      local.elastic_compute_cloud.us_east_1["win-transport"].get_password_data == true &&
      aws_instance.us_east_1["win-transport"].get_password_data == true
    )
    error_message = "WinRM must select itself and turn on get_password_data, which its auth needs."
  }

  # HTTPS/5986 only. 5985 must not appear at all: Terraform's WinRM client does not seal
  # messages, so an unencrypted listener would be both open and unusable.
  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "-Transport HTTPS"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "New-SelfSignedCertificate"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "5986"),
      !strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "5985"),
    ])
    error_message = "The WinRM bootstrap must expose only HTTPS/5986 backed by an in-box certificate."
  }

  assert {
    condition = alltrue([
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "AllowUnencrypted -Value $false"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "Auth\\Basic -Value $false"),
      strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "Auth\\Negotiate -Value $true"),
    ])
    error_message = "The WinRM bootstrap must keep Negotiate on, Basic off, and unencrypted transport refused."
  }

  assert {
    condition     = !strcontains(local.elastic_compute_cloud.us_east_1["win-transport"].user_data, "administrators_authorized_keys")
    error_message = "The WinRM transport must not render the SSH key-install bootstrap."
  }
}

run "connection_type_rejects_an_unknown_transport" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        connection_type = "rdp"
      })
    ]
  }

  expect_failures = [var.all_systems]
}

# WinRM on Linux is meaningless. The OS is data-resolved, so a variable validation cannot see it
# and the guard has to be a precondition on the instance.
run "linux_winrm_is_rejected_by_the_instance_precondition" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname        = "linux-winrm"
        ami             = "test-linux"
        connection_type = "winrm"
        readiness_gate  = true
      })
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["test-linux"]
    values = {
      state            = "available"
      id               = "ami-00000000000000022"
      platform         = ""
      platform_details = "Red Hat Enterprise Linux"
    }
  }

  expect_failures = [aws_instance.us_east_1]
}

# The tunnelled form has to be rejected on the same terms. This system has no readiness gate at
# all, so while the rule lived on the gate nothing rejected it: the transport was accepted and
# then silently ignored, because user_data keys off the resolved platform.
run "linux_winrm_over_ssm_is_rejected_on_the_same_terms" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname        = "linux-winrm-ssm"
        ami             = "test-linux"
        connection_type = "winrm-ssm"
        readiness_gate  = false
      }),
    ]
  }

  expect_failures = [aws_instance.us_east_1]
}

# An SSM transport cannot be gated: Terraform's connection block dials SSH and WinRM directly and
# cannot traverse a Session Manager tunnel, so an enabled gate would only fail on timeout.
run "an_ssm_transport_rejects_an_enabled_readiness_gate" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname        = "gated-ssm"
        connection_type = "ssh-ssm"
        readiness_gate  = true
      }),
    ]
  }

  expect_failures = [var.all_systems]
}

# The protocol half still selects the bootstrap: something has to be listening for the tunnel to
# carry, so an SSM-reached Windows system renders the same WinRM listener as a direct one.
run "an_ssm_transport_still_renders_its_protocol_bootstrap" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        hostname        = "win-ssm"
        ami             = "windows@2022"
        connection_type = "winrm-ssm"
        readiness_gate  = false
      }),
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
    condition = alltrue([
      local.connection_protocol["win-ssm"] == "winrm",
      local.connection_over_ssm["win-ssm"],
      strcontains(local.elastic_compute_cloud.us_east_1["win-ssm"].user_data, "WSMan"),
      local.elastic_compute_cloud.us_east_1["win-ssm"].get_password_data,
    ])
    error_message = "A tunnelled WinRM system must still render the WinRM listener and fetch the launch password."
  }
}

# The gate has to actually switch transport, not merely record the choice.
run "readiness_gate_carries_the_winrm_transport" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        connection_type = "winrm"
        readiness_gate  = true
      })
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      id       = "ami-00000000000000021"
      platform = "windows"
    }
  }

  assert {
    condition = (
      local.readiness_targets.us_east_1["win-transport"].use_winrm == true &&
      local.readiness_targets.us_east_1["win-transport"].winrm_port == 5986 &&
      local.readiness_targets.us_east_1["win-transport"].target_platform == "windows"
    )
    error_message = "A WinRM system's readiness target must select WinRM on 5986."
  }

  assert {
    condition     = local.readiness_targets.us_east_1["win-transport"].readiness_user == "Administrator"
    error_message = "WinRM authenticates as Administrator with the launch password."
  }
}

run "readiness_gate_keeps_ssh_for_the_default_transport" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], {
        readiness_gate = true
      })
    ]
  }

  override_data {
    target = data.aws_ami.us_east_1_verified["windows@2022"]
    values = {
      state    = "available"
      id       = "ami-00000000000000021"
      platform = "windows"
    }
  }

  assert {
    condition = (
      local.readiness_targets.us_east_1["win-transport"].use_winrm == false &&
      local.readiness_targets.us_east_1["win-transport"].password == null
    )
    error_message = "The SSH default must not select WinRM or decrypt a launch password."
  }
}
