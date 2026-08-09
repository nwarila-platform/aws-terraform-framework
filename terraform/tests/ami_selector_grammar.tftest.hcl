// Grammar fixtures for the image selector. These runs exist to prove the near-misses fail at
// terraform validate rather than resolving to something plausible at plan time: a selector that
// looks like a pin but drifts is worse than one that is obviously wrong.

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

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "grammar-host"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "rhel@8.10.20260808"

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
        Function = "AMI selector grammar fixture"
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
          private_ip      = "10.0.0.60"
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

# A fully pinned selector is the reference case: three segments ending in an atomic build date.
run "accepts_a_fully_pinned_selector" {
  command = plan

  assert {
    condition     = local.ami_parameter_name["rhel@8.10.20260808"] == "/nwarila/ami/rhel/8.10.20260808"
    error_message = "A fully pinned selector must address the immutable dated leaf for that version."
  }
}

# Truncation is how a consumer opts into drift, so every depth has to be accepted and has to
# address a different key.
run "accepts_each_truncation_depth" {
  command = plan

  # Three systems in one subnet, so the addresses are left for AWS to pick rather than pinned.
  variables {
    all_systems = [
      merge(var.all_systems[0], {
        ami                = "rhel"
        hostname           = "grammar-bare"
        network_interfaces = [merge(var.all_systems[0].network_interfaces[0], { private_ip = null })]
      }),
      merge(var.all_systems[0], {
        ami                = "rhel@8"
        hostname           = "grammar-major"
        network_interfaces = [merge(var.all_systems[0].network_interfaces[0], { private_ip = null })]
      }),
      merge(var.all_systems[0], {
        ami                = "rhel@8.10"
        hostname           = "grammar-minor"
        network_interfaces = [merge(var.all_systems[0].network_interfaces[0], { private_ip = null })]
      }),
    ]
  }

  assert {
    condition = alltrue([
      local.ami_parameter_name["rhel"] == "/nwarila/ami/rhel/latest",
      local.ami_parameter_name["rhel@8"] == "/nwarila/ami/rhel/8",
      local.ami_parameter_name["rhel@8.10"] == "/nwarila/ami/rhel/8.10",
    ])
    error_message = "Each truncation depth must address its own pointer: bare family to latest, and one key per pinned depth."
  }
}

# The signature failure this grammar exists to prevent. A 6-digit month reads as a pin but
# behaves like a floating pointer until the month ends, then silently becomes a stale one.
run "rejects_a_month_prefix_in_place_of_a_build_date" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], { ami = "rhel@8.10.202608" }),
    ]
  }

  expect_failures = [var.all_systems]
}

# Selectors are used verbatim as SSM keys, so folding case would let two spellings address two
# different parameters. Rejected rather than normalised.
run "rejects_an_uppercase_family" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], { ami = "RHEL@8" }),
    ]
  }

  expect_failures = [var.all_systems]
}

# The build date terminates the selector. Anything after it is not a version component this
# framework knows how to publish or resolve.
run "rejects_a_segment_after_the_build_date" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], { ami = "rhel@8.10.20260808.1" }),
    ]
  }

  expect_failures = [var.all_systems]
}

# Four segments exceed the grammar regardless of whether the last one is a date.
run "rejects_more_than_three_segments" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], { ami = "rhel@8.10.4.2" }),
    ]
  }

  expect_failures = [var.all_systems]
}

# The escape hatch still works, and bypasses the catalog rather than being addressed through it.
run "accepts_a_literal_image_id_and_keeps_it_out_of_the_catalog" {
  command = plan

  variables {
    all_systems = [
      merge(var.all_systems[0], { ami = "ami-0123456789abcdef0" }),
    ]
  }

  assert {
    condition = alltrue([
      length(local.catalog_selectors) == 0,
      length(local.ami_parameter_name) == 0,
      contains(keys(data.aws_ami.us_east_1_verified), "ami-0123456789abcdef0"),
    ])
    error_message = "A literal id must be verified like any other image but must not produce a catalog parameter read."
  }
}
