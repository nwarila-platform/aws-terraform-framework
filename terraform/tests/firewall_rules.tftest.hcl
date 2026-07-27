mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-fromsubnetlookup"
    }
  }
}

variables {
  environment = "TEST"

  all_systems = [
    {
      region               = "us_east_1"
      hostname             = "stability-host"
      availability_zone    = "us-east-1a"
      subnet_id            = "subnet-preexisting"
      key_name             = "preexisting-key"
      iam_instance_profile = "preexisting-profile"
      aws_kms_alias        = "preexisting"
      ami                  = "test-linux"

      refresh        = false
      instance_type  = "m6i.large"
      readiness_user = null
      readiness_gate = false
      imds_hop_limit = 1
      set_state      = null

      tags = {
        Function = "Rule-key stability"
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

      ebs_block_devices = []

      network_interfaces = [
        {
          private_ip      = "10.0.0.80"
          security_groups = []
          description     = "Rule-key stability interface."
          interface_type  = null
          ingress = [
            {
              description                  = "SSH from operations"
              ip_protocol                  = "tcp"
              from_port                    = 22
              to_port                      = 22
              cidr_ipv4                    = "10.1.0.0/16"
              cidr_ipv6                    = null
              prefix_list_id               = null
              referenced_security_group_id = null
            },
            {
              description                  = "HTTPS from IPv6 services"
              ip_protocol                  = "tcp"
              from_port                    = 443
              to_port                      = 443
              cidr_ipv4                    = null
              cidr_ipv6                    = "2001:db8:1::/64"
              prefix_list_id               = null
              referenced_security_group_id = null
            }
          ]
          egress = []
          tags   = {}
        }
      ]

      associate_public_ip = false
    }
  ]
}

# The two authored rules establish the content-derived keys that must survive list edits.
run "rule_keys_before_front_insert" {
  command = plan

  assert {
    condition = toset(keys(aws_vpc_security_group_ingress_rule.us_east_1)) == toset([
      "stability-host-eni-0-sg/ingress-protocol-tcp-ports-22-22-cidr-ipv4-10-1-0-0-16-${substr(sha256(jsonencode(["ingress", "tcp", 22, 22, "cidr_ipv4", "10.1.0.0/16"])), 0, 12)}",
      "stability-host-eni-0-sg/ingress-protocol-tcp-ports-443-443-cidr-ipv6-2001-db8-1-64-${substr(sha256(jsonencode(["ingress", "tcp", 443, 443, "cidr_ipv6", "2001:db8:1::/64"])), 0, 12)}",
    ])
    error_message = "Rule keys must be derived from the rule identity rather than its list position."
  }
}

# Inserting the new rule at index zero must add exactly one key without changing either existing
# rule's key.
run "front_insert_preserves_existing_rule_keys" {
  command = plan

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "stability-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Rule-key stability after a front insert"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.80"
            security_groups = []
            description     = "Rule-key stability interface."
            interface_type  = null
            ingress = [
              {
                description                  = "Application traffic from the service prefix list"
                ip_protocol                  = "tcp"
                from_port                    = 8443
                to_port                      = 8443
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = "pl-0123456789abcdef0"
                referenced_security_group_id = null
              },
              {
                description                  = "SSH from operations"
                ip_protocol                  = "tcp"
                from_port                    = 22
                to_port                      = 22
                cidr_ipv4                    = "10.1.0.0/16"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "HTTPS from IPv6 services"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = null
                cidr_ipv6                    = "2001:db8:1::/64"
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            egress = []
            tags   = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(aws_security_group.us_east_1) == 1,
      contains(keys(aws_security_group.us_east_1), "stability-host-eni-0-sg"),
      length(aws_vpc_security_group_ingress_rule.us_east_1) == 3,
      contains(keys(aws_vpc_security_group_ingress_rule.us_east_1), "stability-host-eni-0-sg/ingress-protocol-tcp-ports-22-22-cidr-ipv4-10-1-0-0-16-${substr(sha256(jsonencode(["ingress", "tcp", 22, 22, "cidr_ipv4", "10.1.0.0/16"])), 0, 12)}"),
      contains(keys(aws_vpc_security_group_ingress_rule.us_east_1), "stability-host-eni-0-sg/ingress-protocol-tcp-ports-443-443-cidr-ipv6-2001-db8-1-64-${substr(sha256(jsonencode(["ingress", "tcp", 443, 443, "cidr_ipv6", "2001:db8:1::/64"])), 0, 12)}"),
    ])
    error_message = "A front insertion must add one rule key while retaining the security-group key and both pre-existing rule keys."
  }
}

# Three interfaces carry 1, 5, and 12 rules. Every supported destination kind appears.
run "three_interfaces_scale_without_rule_or_attachment_collisions" {
  command = apply

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "scale-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Many rules on multiple interfaces"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.81"
            security_groups = []
            description     = "One-rule interface."
            interface_type  = null
            ingress = [
              {
                description                  = "HTTPS from application clients"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = "10.10.0.0/16"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            egress = []
            tags   = {}
          },
          {
            private_ip      = "10.0.0.82"
            security_groups = []
            description     = "Five-rule interface."
            interface_type  = null
            ingress = [
              {
                description                  = "SSH from operations"
                ip_protocol                  = "tcp"
                from_port                    = 22
                to_port                      = 22
                cidr_ipv4                    = "10.20.0.0/16"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "HTTPS from IPv6 clients"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = null
                cidr_ipv6                    = "2001:db8:20::/64"
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Metrics from a collector group"
                ip_protocol                  = "tcp"
                from_port                    = 9090
                to_port                      = 9090
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = "sg-0123456789abcdef0"
              }
            ]
            egress = [
              {
                description                  = "TLS to service endpoints"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = "pl-0123456789abcdef0"
                referenced_security_group_id = null
              },
              {
                description                  = "DNS to resolvers"
                ip_protocol                  = "udp"
                from_port                    = 53
                to_port                      = 53
                cidr_ipv4                    = "10.20.0.2/32"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            tags = {}
          },
          {
            private_ip      = "10.0.0.83"
            security_groups = []
            description     = "Twelve-rule interface."
            interface_type  = null
            ingress = [
              {
                description                  = "Application port one"
                ip_protocol                  = "tcp"
                from_port                    = 8001
                to_port                      = 8001
                cidr_ipv4                    = "10.30.1.0/24"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Application port two"
                ip_protocol                  = "tcp"
                from_port                    = 8002
                to_port                      = 8002
                cidr_ipv4                    = "10.30.2.0/24"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "IPv6 application clients"
                ip_protocol                  = "tcp"
                from_port                    = 8003
                to_port                      = 8003
                cidr_ipv4                    = null
                cidr_ipv6                    = "2001:db8:30::/64"
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Application prefix list"
                ip_protocol                  = "tcp"
                from_port                    = 8004
                to_port                      = 8004
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = "pl-11111111111111111"
                referenced_security_group_id = null
              },
              {
                description                  = "Peer application group"
                ip_protocol                  = "tcp"
                from_port                    = 8005
                to_port                      = 8005
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = "sg-11111111111111111"
              }
            ]
            egress = [
              {
                description                  = "Outbound service one"
                ip_protocol                  = "tcp"
                from_port                    = 9001
                to_port                      = 9001
                cidr_ipv4                    = "10.40.1.0/24"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Outbound service two"
                ip_protocol                  = "udp"
                from_port                    = 9002
                to_port                      = 9002
                cidr_ipv4                    = "10.40.2.0/24"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Outbound IPv6 service"
                ip_protocol                  = "tcp"
                from_port                    = 9003
                to_port                      = 9003
                cidr_ipv4                    = null
                cidr_ipv6                    = "2001:db8:40::/64"
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Outbound prefix service"
                ip_protocol                  = "tcp"
                from_port                    = 9004
                to_port                      = 9004
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = "pl-22222222222222222"
                referenced_security_group_id = null
              },
              {
                description                  = "Outbound peer group"
                ip_protocol                  = "tcp"
                from_port                    = 9005
                to_port                      = 9005
                cidr_ipv4                    = null
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = "sg-22222222222222222"
              },
              {
                description                  = "Outbound HTTPS"
                ip_protocol                  = "tcp"
                from_port                    = 443
                to_port                      = 443
                cidr_ipv4                    = "10.40.6.0/24"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              },
              {
                description                  = "Outbound NTP"
                ip_protocol                  = "udp"
                from_port                    = 123
                to_port                      = 123
                cidr_ipv4                    = "10.40.7.0/24"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            tags = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = toset(keys(aws_security_group.us_east_1)) == toset([
      "scale-host-eni-0-sg",
      "scale-host-eni-1-sg",
      "scale-host-eni-2-sg",
    ])
    error_message = "Three declaring interfaces must create three distinct interface-owned groups."
  }

  assert {
    condition = alltrue([
      length(local.network_interface_security_group_rules.us_east_1) == 18,
      length(distinct(keys(local.network_interface_security_group_rules.us_east_1))) == 18,
      length([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule if rule.sg_key == "scale-host-eni-0-sg"]) == 1,
      length([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule if rule.sg_key == "scale-host-eni-1-sg"]) == 5,
      length([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule if rule.sg_key == "scale-host-eni-2-sg"]) == 12,
    ])
    error_message = "The 1/5/12 rule sets must flatten without collisions and remain partitioned by their declaring group."
  }

  assert {
    condition = alltrue([
      anytrue([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule.cidr_ipv4 != null]),
      anytrue([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule.cidr_ipv6 != null]),
      anytrue([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule.prefix_list_id != null]),
      anytrue([for rule in values(local.network_interface_security_group_rules.us_east_1) : rule.referenced_security_group_id != null]),
    ])
    error_message = "The scale case must exercise every supported rule destination kind."
  }

  assert {
    condition = alltrue(concat(
      [
        for key, rule in aws_vpc_security_group_ingress_rule.us_east_1 :
        rule.security_group_id == aws_security_group.us_east_1[split("/", key)[0]].id
      ],
      [
        for key, rule in aws_vpc_security_group_egress_rule.us_east_1 :
        rule.security_group_id == aws_security_group.us_east_1[split("/", key)[0]].id
      ],
    ))
    error_message = "Every materialized rule must attach to the group named by its key prefix."
  }

  assert {
    condition = alltrue([
      aws_network_interface.us_east_1["scale-host-eni-0"].security_groups == toset([aws_security_group.us_east_1["scale-host-eni-0-sg"].id]),
      aws_network_interface.us_east_1["scale-host-eni-1"].security_groups == toset([aws_security_group.us_east_1["scale-host-eni-1-sg"].id]),
      aws_network_interface.us_east_1["scale-host-eni-2"].security_groups == toset([aws_security_group.us_east_1["scale-host-eni-2-sg"].id]),
    ])
    error_message = "Each interface must attach only its own interface-owned group."
  }
}

run "derived_and_precreated_groups_compose_in_authored_order" {
  command = apply

  variables {
    all_systems = [
      {
        region               = "us_east_1"
        hostname             = "composed-group-host"
        availability_zone    = "us-east-1a"
        subnet_id            = "subnet-preexisting"
        key_name             = "preexisting-key"
        iam_instance_profile = "preexisting-profile"
        aws_kms_alias        = "preexisting"
        ami                  = "test-linux"

        refresh        = false
        instance_type  = "m6i.large"
        readiness_user = null
        readiness_gate = false
        imds_hop_limit = 1
        set_state      = null

        tags = {
          Function = "Composed security groups"
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

        ebs_block_devices = []

        network_interfaces = [
          {
            private_ip      = "10.0.0.85"
            security_groups = ["sg-0123456789abcdef0"]
            description     = "Derived and pre-created groups."
            interface_type  = null
            ingress = [
              {
                description                  = "SSH from operations"
                ip_protocol                  = "tcp"
                from_port                    = 22
                to_port                      = 22
                cidr_ipv4                    = "10.60.0.0/16"
                cidr_ipv6                    = null
                prefix_list_id               = null
                referenced_security_group_id = null
              }
            ]
            egress = []
            tags   = {}
          }
        ]

        associate_public_ip = false
      }
    ]
  }

  assert {
    condition = alltrue([
      length(local.elastic_network_interfaces.us_east_1["composed-group-host-eni-0"].security_groups) == 2,
      local.elastic_network_interfaces.us_east_1["composed-group-host-eni-0"].security_groups[0] == "sg-0123456789abcdef0",
      local.elastic_network_interfaces.us_east_1["composed-group-host-eni-0"].security_groups[1] == aws_security_group.us_east_1["composed-group-host-eni-0-sg"].id,
      length(distinct(local.elastic_network_interfaces.us_east_1["composed-group-host-eni-0"].security_groups)) == 2,
      aws_network_interface.us_east_1["composed-group-host-eni-0"].security_groups == toset([
        "sg-0123456789abcdef0",
        aws_security_group.us_east_1["composed-group-host-eni-0-sg"].id,
      ]),
    ])
    error_message = "The authored group must remain first, the derived group must append once, and neither group may be dropped."
  }
}

