mock_provider "aws" {
  alias = "us_east_1"

  # The verified-image lookup asserts state; unmocked attributes come back as random
  # strings, so the default has to say what a healthy image looks like.
  mock_data "aws_ami" {
    defaults = {
      state = "available"
    }
  }

  # The runner group derives its VPC from the systems' subnets, so the mock has to answer with a
  # coherent VPC. Runs that need a SECOND VPC override this per-subnet.
  mock_data "aws_subnet" {
    defaults = {
      vpc_id            = "vpc-runneringress"
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
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
      hostname             = "runner-host-a"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-runner-a"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

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
        Function = "Runner ingress subject"
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

      # Two interfaces on one system, so "attached to EVERY ENI" is actually exercised: the first
      # declares its own inline group, the second only carries a standing group.
      network_interfaces = [
        {
          private_ip      = "10.0.0.41"
          security_groups = ["sg-0123456789abcdef0"]
          description     = "Interface owning its firewall inline."
          interface_type  = null
          ingress = [
            {
              description                  = "Agent events from the deploy subnet"
              ip_protocol                  = "tcp"
              from_port                    = 1514
              to_port                      = 1515
              cidr_ipv4                    = "10.1.10.0/24"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          egress = []
          tags   = {}
        },
        {
          private_ip      = "10.0.0.42"
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

# CASE 1: the default. Nothing is created and no ENI's security_groups changes, so a consumer
# that never sets runner_ip sees exactly today's plan.
run "null_runner_ip_creates_nothing_and_attaches_nothing" {
  command = plan

  assert {
    condition = (
      length(aws_security_group.runner_ingress_us_east_1) == 0 &&
      length(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1) == 0
    )
    error_message = "A null runner_ip must create no security group and no ingress rule."
  }

  # eni-0 keeps its standing group plus its own inline group; eni-1 keeps only the standing one.
  assert {
    condition = (
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-0"].security_groups) == 2 &&
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-1"].security_groups) == 1
    )
    error_message = "A null runner_ip must leave every ENI's security_groups exactly as it was."
  }
}

# CASE 2 and 5: one group, exactly the two transport ports, sourced from the /32 the module
# derives, attached to every ENI, and carrying the framework tag block.
run "valid_runner_ip_creates_one_group_three_rules_on_every_eni" {
  command = plan

  variables {
    runner_ip = "203.0.113.7"
  }

  # The group id is provider-computed and unknown at plan, so pin it: the point of this run is
  # the wiring (which ENIs receive the group), not what AWS would name it.
  override_resource {
    target          = aws_security_group.runner_ingress_us_east_1
    override_during = plan
    values = {
      id = "sg-runneringress0"
    }
  }

  assert {
    condition     = length(aws_security_group.runner_ingress_us_east_1) == 1
    error_message = "A non-null runner_ip must create exactly one security group."
  }

  assert {
    condition     = contains(keys(aws_security_group.runner_ingress_us_east_1), "runner-ingress-123456789-test")
    error_message = "The group name must derive from repository_id and environment so two stacks in one VPC cannot collide."
  }

  # The three rules are the transports the consumer's matrix defines: SSH-direct, WinRM-direct,
  # and ICMP for reachability. Anything else here means the module-owned literals drifted.
  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1) == 3 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-ssh-203.0.113.7"].from_port == 22 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-ssh-203.0.113.7"].to_port == 22 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-winrm-203.0.113.7"].from_port == 5986 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-winrm-203.0.113.7"].to_port == 5986
    )
    error_message = "The group must carry exactly tcp/22 and tcp/5986."
  }

  # ICMP carries no ports: -1/-1 in the port fields means every type and code, scoped to the
  # runner's single address.
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-icmp-203.0.113.7"].ip_protocol == "icmp" &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-icmp-203.0.113.7"].from_port == -1 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-icmp-203.0.113.7"].to_port == -1
    )
    error_message = "The group must carry an ICMP rule covering every type and code."
  }

  assert {
    condition = alltrue([
      for _, rule in aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1 :
      rule.cidr_ipv4 == "203.0.113.7/32"
    ])
    error_message = "Every runner rule must be sourced from the single-host /32 built from runner_ip."
  }

  # Nothing beyond the three module-owned runner transports may appear, whatever else changes.
  # A key names its transport AND its source, because several sources may now grant access.
  assert {
    condition = sort(keys(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1)) == sort([
      "runner-ingress-123456789-test-ssh-203.0.113.7",
      "runner-ingress-123456789-test-winrm-203.0.113.7",
      "runner-ingress-123456789-test-icmp-203.0.113.7",
    ])
    error_message = "The runner group must carry exactly the ssh, winrm and icmp rules and nothing else."
  }

  # "attach to EVERY ENI": both interfaces gain the group on top of what they already had.
  assert {
    condition = alltrue([
      for key in ["runner-host-a-eni-0", "runner-host-a-eni-1"] :
      contains(local.elastic_network_interfaces.us_east_1[key].security_groups, "sg-runneringress0")
    ])
    error_message = "The runner group must be attached to every ENI the framework creates."
  }

  assert {
    condition = (
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-0"].security_groups) == 3 &&
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-1"].security_groups) == 2
    )
    error_message = "The runner group must be added to each ENI's existing groups, not replace them."
  }

  # Tagging is load-bearing: a consumer's deploy role authorizes group creation on the identity
  # tags, so a group missing them is denied at apply rather than merely untidy.
  assert {
    condition = alltrue([
      for key, expected in {
        Environment  = "test"
        ManagedBy    = "Terraform"
        Name         = "runner-ingress-123456789-test"
        Repository   = "nwarila-platform/aws-terraform-framework"
        RepositoryId = "123456789"
        RunId        = "42"
      } :
      aws_security_group.runner_ingress_us_east_1["runner-ingress-123456789-test"].tags[key] == expected
    ])
    error_message = "The runner group must carry the same framework identity tags every other group builds."
  }

  assert {
    condition = alltrue([
      for _, rule in aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1 :
      rule.tags["RepositoryId"] == "123456789"
    ])
    error_message = "Runner ingress rules must carry the identity tags the deploy role authorizes on."
  }
}

# CASE 6: a system reached over SSM accepts nothing inbound, so the group the runner uses to
# open SSH, WinRM and ICMP is not attached to it. Its interfaces keep exactly what the consumer
# listed.
run "an_ssm_reached_system_is_not_given_the_runner_group" {
  command = plan

  variables {
    runner_ip = "203.0.113.7"

    all_systems = [
      merge(var.all_systems[0], {
        connection_type = "ssh-ssm"
        readiness_gate  = false
      }),
    ]
  }

  # Nothing is left to attach to, so the group is never built rather than created as an orphan.
  assert {
    condition = (
      length(aws_security_group.runner_ingress_us_east_1) == 0 &&
      length(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1) == 0
    )
    error_message = "A region whose systems are all reached over SSM must build no runner group at all."
  }

  assert {
    condition = (
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-0"].security_groups) == 2 &&
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-1"].security_groups) == 1
    )
    error_message = "An SSM-reached system's interfaces must keep exactly the groups the consumer gave them."
  }
}

# CASE 7: the selective half. One group is still built for the directly-reached system, and only
# its interfaces receive it - the tunnelled system alongside it is left alone.
run "a_mixed_fleet_attaches_the_group_only_to_directly_reached_systems" {
  command = plan

  variables {
    runner_ip = "203.0.113.7"

    all_systems = [
      var.all_systems[0],
      merge(var.all_systems[0], {
        hostname        = "runner-host-b"
        connection_type = "ssh-ssm"
        readiness_gate  = false
        # Same subnet as host A, so the addresses are left for AWS to pick rather than pinned.
        network_interfaces = [
          for nic in var.all_systems[0].network_interfaces : merge(nic, { private_ip = null })
        ]
      }),
    ]
  }

  override_resource {
    target          = aws_security_group.runner_ingress_us_east_1
    override_during = plan
    values = {
      id = "sg-runneringress0"
    }
  }

  assert {
    condition     = length(aws_security_group.runner_ingress_us_east_1) == 1
    error_message = "One directly-reached system is enough to require the runner group."
  }

  assert {
    condition = alltrue([
      for key in ["runner-host-a-eni-0", "runner-host-a-eni-1"] :
      contains(local.elastic_network_interfaces.us_east_1[key].security_groups, "sg-runneringress0")
    ])
    error_message = "A directly-reached system must still receive the runner group on every interface."
  }

  # Counted rather than searched: host B's own inline group id is provider-computed, so a
  # negative contains() over that list is unknown at plan. The counts are known, and they say
  # the same thing - B's interfaces carry exactly what the consumer gave them, A's carry one more.
  assert {
    condition = (
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-0"].security_groups) == 3 &&
      length(local.elastic_network_interfaces.us_east_1["runner-host-a-eni-1"].security_groups) == 2 &&
      length(local.elastic_network_interfaces.us_east_1["runner-host-b-eni-0"].security_groups) == 2 &&
      length(local.elastic_network_interfaces.us_east_1["runner-host-b-eni-1"].security_groups) == 1
    )
    error_message = "A tunnelled system must not receive the runner group, even when a neighbour does."
  }
}

# CASE 3: a prefix is rejected by the input type, which is what makes a range structurally
# impossible rather than merely discouraged.
run "cidr_runner_ip_is_rejected" {
  command = plan

  variables {
    runner_ip = "203.0.113.0/24"
  }

  expect_failures = [var.runner_ip]
}

# CASE 4, pinned deliberately: 0.0.0.0/32 is a host route, NOT /0, so the world-open ingress ban
# does not catch it. It is never a reachable runner, so reject it outright.
run "unspecified_address_runner_ip_is_rejected" {
  command = plan

  variables {
    runner_ip = "0.0.0.0"
  }

  expect_failures = [var.runner_ip]
}

run "malformed_runner_ip_is_rejected" {
  command = plan

  variables {
    runner_ip = "203.0.113.999"
  }

  expect_failures = [var.runner_ip]
}

# One security group lives in one VPC. A fleet spread across two must fail loudly instead of
# attaching to whichever VPC happened to sort first.
run "runner_ip_across_two_vpcs_fails_the_precondition" {
  command = plan

  variables {
    runner_ip = "203.0.113.7"

    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "vpc-a-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-vpc-a"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

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
          Function = "VPC A"
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
            private_ip      = "10.0.0.41"
            security_groups = ["sg-0123456789abcdef0"]
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
        hostname             = "vpc-b-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-vpc-b"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

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
          Function = "VPC B"
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
            private_ip      = "10.0.0.51"
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

  override_data {
    target = data.aws_subnet.us_east_1["subnet-vpc-b"]
    values = {
      vpc_id            = "vpc-second"
      cidr_block        = "10.0.0.0/8"
      availability_zone = "us-east-1a"
    }
  }

  expect_failures = [aws_security_group.runner_ingress_us_east_1]
}


# The operator half. debug_ips carries the runner's three transports PLUS RDP, because a person
# on a Windows host needs a desktop and CI never does -- so granting an operator access must not
# be expressible as widening what the automation may reach.
run "debug_ip_carries_rdp_as_well_as_the_runner_transports" {
  command = plan

  variables {
    runner_ip = null
    debug_ip  = "198.51.100.20"
  }

  assert {
    condition     = length(aws_security_group.runner_ingress_us_east_1) == 1
    error_message = "debug_ip alone must create the run-scoped group, exactly as runner_ip does."
  }

  assert {
    condition = sort(keys(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1)) == sort([
      "runner-ingress-123456789-test-ssh-198.51.100.20",
      "runner-ingress-123456789-test-winrm-198.51.100.20",
      "runner-ingress-123456789-test-icmp-198.51.100.20",
      "runner-ingress-123456789-test-rdp-198.51.100.20",
    ])
    error_message = "A debug address must carry ssh, winrm, icmp and rdp, and nothing else."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-rdp-198.51.100.20"].from_port == 3389 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-rdp-198.51.100.20"].to_port == 3389 &&
      aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1["runner-ingress-123456789-test-rdp-198.51.100.20"].ip_protocol == "tcp"
    )
    error_message = "The RDP rule must be tcp/3389 exactly."
  }

  assert {
    condition = alltrue([
      for _, rule in aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1 :
      rule.cidr_ipv4 == "198.51.100.20/32"
    ])
    error_message = "Every debug rule must be sourced from the single-host /32 built from the address."
  }
}

# The runner never gains a desktop just because an operator asked for one.
run "runner_and_debug_addresses_keep_their_own_transports" {
  command = plan

  variables {
    runner_ip = "203.0.113.7"
    debug_ip  = "198.51.100.20"
  }

  assert {
    condition = sort(keys(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1)) == sort([
      "runner-ingress-123456789-test-ssh-203.0.113.7",
      "runner-ingress-123456789-test-winrm-203.0.113.7",
      "runner-ingress-123456789-test-icmp-203.0.113.7",
      "runner-ingress-123456789-test-ssh-198.51.100.20",
      "runner-ingress-123456789-test-winrm-198.51.100.20",
      "runner-ingress-123456789-test-icmp-198.51.100.20",
      "runner-ingress-123456789-test-rdp-198.51.100.20",
    ])
    error_message = "The runner address must carry no RDP rule while the debug address does."
  }
}


# An address that is both the runner and an operator asks for the same opening twice. AWS rejects
# a duplicate rule, so the two must collapse rather than collide -- and the surviving set is the
# wider one, because the person still needs their desktop.
run "an_address_that_is_both_runner_and_operator_collapses" {
  command = plan

  variables {
    runner_ip = "203.0.113.7"
    debug_ip  = "203.0.113.7"
  }

  assert {
    condition = sort(keys(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1)) == sort([
      "runner-ingress-123456789-test-ssh-203.0.113.7",
      "runner-ingress-123456789-test-winrm-203.0.113.7",
      "runner-ingress-123456789-test-icmp-203.0.113.7",
      "runner-ingress-123456789-test-rdp-203.0.113.7",
    ])
    error_message = "One address named twice must yield one rule per transport, not two."
  }
}

# Empty is the default and grants nothing, the same posture runner_ip holds at null.
run "empty_debug_inputs_create_nothing" {
  command = plan

  variables {
    runner_ip = null
    debug_ip  = null
  }

  assert {
    condition = (
      length(aws_security_group.runner_ingress_us_east_1) == 0 &&
      length(aws_vpc_security_group_ingress_rule.runner_ingress_us_east_1) == 0
    )
    error_message = "No runner and no operator must create no group and no rule."
  }
}

# The same structural guarantee runner_ip carries: a range must not be representable.
run "cidr_debug_ip_is_rejected" {
  command = plan

  variables {
    debug_ip = "198.51.100.0/24"
  }

  expect_failures = [var.debug_ip]
}

run "unspecified_address_debug_ip_is_rejected" {
  command = plan

  variables {
    debug_ip = "0.0.0.0"
  }

  expect_failures = [var.debug_ip]
}

run "malformed_debug_ip_is_rejected" {
  command = plan

  variables {
    debug_ip = "198.51.100.999"
  }

  expect_failures = [var.debug_ip]
}

# A name is resolved; an address is not a name. Passing one where the other belongs is refused so



# The point of a name: an address the configuration never records. A resolved address is treated

