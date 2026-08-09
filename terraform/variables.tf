# Variable declarations. Provider-neutral system/database identity first, then the
# AWS-specific configuration and managed-capability maps.

variable "environment" {
  description = <<-EOT
    Deployment environment tag value applied to managed AWS resources. Exactly one of dev, test,
    or prod (lowercase).
  EOT
  type        = string
  nullable    = false

  # A closed, case-exact lowercase set rather than a free-form string: the value lands verbatim in
  # the Environment tag on every managed resource, so accepting spelling or case variants ("Dev",
  # "PROD", "production") would fragment the estate's tag-based inventory and cost queries.
  # Lowercase matches the pinned consumer's environment = "dev", keeping this change non-breaking.
  # Bounding the set also subsumes the former non-empty and 256-character tag-value-length checks.
  validation {
    condition = contains(["dev", "test", "prod"], var.environment)
    error_message = join(" ", [
      "environment must be exactly one of \"dev\", \"test\", or \"prod\" (lowercase); the value",
      "is stamped verbatim onto every managed resource's Environment tag, so case and spelling",
      "variants are rejected.",
    ])
  }
}

variable "refresh_serial" {
  description = <<-EOT
    Monotonic counter that forces replacement of all refresh=true instances when incremented. Bump
    it (0 -> 1 -> 2 ...) to intentionally rebuild the refresh fleet; leaving it unchanged keeps
    plans clean. Replaces the previous timestamp() trigger that rebuilt the fleet on every apply.
  EOT
  type        = number
  default     = 0
  nullable    = false

  validation {
    condition = var.refresh_serial >= 0 && floor(var.refresh_serial) == var.refresh_serial
    error_message = join(" ", [
      "refresh_serial must be a whole number >= 0; increment it to rebuild the refresh",
      "fleet.",
    ])
  }
}

variable "all_systems" {
  description = <<-EOT
    Define all EC2 systems managed by this framework. Each network interface with non-null ingress
    and egress creates and attaches its own <hostname>-eni-<interface index>-sg security group.
  EOT

  type = list(object({
    # Required: give each attribute below a real value.
    ami                  = string
    availability_zone    = string
    aws_kms_alias        = string
    hostname             = string
    iam_instance_profile = string
    key_name             = string
    refresh              = bool
    region               = string
    subnet_id            = string

    tags = object({
      #OS                   = <Set Automatically From 'each.ami' Data Object Lookup>
      #Name                 = string
      Backup   = bool
      Function = string
      #ManagedBy            = <Statically Set To 'Terraform'>
      #Repository           = <Set Automatically From 'var.repository'>
      #RepositoryId         = <Set Automatically From 'var.repository_id'>
      #CommitSha            = <Set Automatically From 'var.commit_sha'>
      #RunId                = <Set Automatically From 'var.run_id'>
      #Environment          = <Set Automatically From 'var.environment'>
    })

    # Opt-out: still mandatory in the object type, because optional() is banned
    # (ADR repo/0002). Set null, [] or {} to decline one.
    instance_type = string
    # Transport the readiness gate uses, and the bootstrap user_data rendered to match. Null
    # selects "ssh". "winrm" is Windows-only and exists for images that cannot install the
    # OpenSSH Feature-on-Demand, which is every stock Windows AMI with no Windows Update egress:
    # WS-Management is in-box, so it works where SSH cannot be installed at all. Choosing it also
    # turns on get_password_data, because WinRM authenticates with the launch password.
    connection_type = string
    # SSH login user for the readiness gate. Null selects the OS default: ec2-user on Linux,
    # Administrator on Windows. Override for images with a different default user (for example,
    # ubuntu, rocky, or admin).
    readiness_user = string
    # Command the readiness gate runs over SSH to block until the instance has finished
    # provisioning. Null selects the OS default: "cloud-init status --wait" on Linux, EC2Launch
    # status -b on Windows. Override for images whose provisioning completes on a different
    # signal.
    readiness_command = string
    # Absolute directory on a Linux instance where the readiness gate uploads its remote-exec
    # script. Must be writable by the readiness user AND mounted exec (NOT noexec) - hardened AMIs
    # commonly mount /tmp, /var/tmp and /dev/shm noexec, which breaks the upload. Null selects
    # /home/ec2-user. Ignored on Windows, which needs no upload directory.
    readiness_script_dir = string
    # Path, on the machine running Terraform, to the OpenSSH private key the readiness gate
    # authenticates with. Every platform uses SSH with the launch key pair; the Windows bootstrap
    # installs the launch public key for Administrator. Null leaves the gate without a key, which
    # is the plan/CI posture - a real apply of a gated system needs a readable path here.
    readiness_private_key_path = string
    # Set false to skip the SSH readiness gate for this system entirely (no terraform_data
    # resource is created). Required for zero-inbound systems reached only through SSM, where the
    # machine running Terraform cannot open a TCP connection to the instance's private IP.
    readiness_gate = bool
    set_state      = string
    # IMDSv2 PUT response hop limit. Use 1 unless the system runs containers that need
    # instance-role credentials, where Docker's NAT adds one hop (2). http_tokens stays
    # module-owned and always "required" (ADR repo/0001).
    imds_hop_limit = number

    root_block_device = object({
      delete_on_termination = bool
      #encrypted            = # Statically set to 'true'
      iops = string
      #kms_key_id           = # Calculated automatically from system.aws_kms_alias
      tags        = map(string)
      throughput  = string
      volume_size = string
      volume_type = string
    })

    ebs_block_devices = list(
      object({
        # Stable resource and attachment identity. Keep both values unchanged when reordering.
        resource_key = string
        # Stable device suffix: 0 maps to sdd/xvdd and 22 maps to sdz/xvdz.
        device_index = number
        #encrypted            = # Statically set to 'true'
        iops = string
        #kms_key_id           = # Calculated automatically from system.aws_kms_alias
        skip_destroy = bool
        snapshot_id  = string
        tags         = map(string)
        throughput   = string
        volume_size  = string
        volume_type  = string
      })
    )

    # Overrides for block devices the AMI itself defines. `device_name` must match the AMI's
    # mapping exactly; the rendered block replaces it, which is the only way to encrypt a device
    # the AMI ships unencrypted. Use [] when the AMI defines nothing beyond its root device.
    ami_block_device_overrides = list(
      object({
        delete_on_termination = bool
        device_name           = string
        #encrypted            = # Statically set to 'true'
        iops = string
        #kms_key_id           = # Calculated automatically from system.aws_kms_alias
        #snapshot_id          = # Never set: the AMI mapping supplies the snapshot.
        throughput  = string
        volume_size = string
        volume_type = string
      })
    )

    network_interfaces = list(
      object({
        #subnet_id      = # Calculated automatically from parent object
        #region         = # Calculated automatically from parent object
        description    = string
        interface_type = string
        # Omit (null) to let AWS pick a free address from the subnet CIDR. A pinned address is
        # checked against the real subnet at plan time by a network-interface precondition.
        private_ip      = string
        security_groups = list(string)
        # Non-null ingress and egress declare this interface's own group, named
        # "<hostname>-eni-<interface index>-sg" and attached only to this interface. Both null
        # means attach only the pre-created groups listed above. At creation, the group's
        # description is set from this interface's description when non-null, otherwise from a
        # fixed framework string, and is not updated afterwards. Its tags use this interface's
        # tags.
        # This framework is IPv4-only, so a rule's source or destination is one of cidr_ipv4,
        # prefix_list_id, or referenced_security_group_id. There is no cidr_ipv6.
        ingress = list(object({
          description                  = string
          ip_protocol                  = string
          from_port                    = number
          to_port                      = number
          cidr_ipv4                    = string
          prefix_list_id               = string
          referenced_security_group_id = string
        }))

        egress = list(object({
          description                  = string
          ip_protocol                  = string
          from_port                    = number
          to_port                      = number
          cidr_ipv4                    = string
          prefix_list_id               = string
          referenced_security_group_id = string
        }))

        tags = map(string)
      })
    )

    # Allocate an Elastic IP and associate it with this system's primary ENI (<hostname>-eni-0),
    # giving the system a stable public IPv4 address. The subnet is pre-created, so whether it
    # routes to an internet gateway is the consumer's responsibility, not this framework's.
    associate_public_ip = bool

  }))

  default  = []
  nullable = false

  # Image selector grammar. Either the literal-id escape hatch, or a catalog address: a lowercase
  # family, optionally suffixed with "@" and up to three dot-separated numeric segments. Leading
  # segments are 1-4 digit vendor version components; a build date is atomic YYYYMMDD and may
  # appear only last. Every omitted trailing segment is drift the consumer accepts, so "rhel@8"
  # takes minor and patch drift, "rhel@8.10" takes patch drift, and "rhel@8.10.20260808" is exact.
  #
  # Rejecting the near-misses here is the point. A 6-digit month ("rhel@8.10.202608") looks like a
  # pin but behaves like a floating pointer until the month ends and then becomes a stale one, so
  # it matches nothing. Uppercase is rejected rather than folded, because the selector is used
  # verbatim as an SSM key and two spellings would address two different parameters.
  validation {
    condition = alltrue([
      for system in var.all_systems : (
        can(regex("^ami-[0-9a-f]{8,17}$", system.ami)) ||
        (
          can(regex("^[a-z][a-z0-9-]+(@[0-9][0-9.]*)?$", system.ami)) &&
          length(try(split(".", split("@", system.ami)[1]), [])) <= 3 &&
          alltrue([
            for index, segment in try(split(".", split("@", system.ami)[1]), []) :
            can(regex("^[0-9]{1,4}$", segment)) ||
            (
              can(regex("^[0-9]{8}$", segment)) &&
              index == length(try(split(".", split("@", system.ami)[1]), [])) - 1
            )
          ])
        )
      )
    ])
    error_message = join(" ", [
      "Each all_systems ami must be a literal \"ami-<hex>\" id, a lowercase family such as",
      "\"rhel\", or a catalog address such as \"rhel@8.10.20260808\" - at most three numeric",
      "segments, where only the last may be an 8-digit YYYYMMDD build date. Month prefixes like",
      "\"8.10.202608\" are invalid by design: they cannot freeze a patch level and go stale",
      "silently.",
    ])
  }

  # An omitted attribute is already rejected by the type checker, so this only fires on an
  # explicit null. That matters most for ebs_block_devices: locals filters on non-null, so a
  # null there silently produces zero volumes instead of failing.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.connection_type == null ||
      contains(["ssh", "winrm", "ssh-ssm", "winrm-ssm"], system.connection_type)
    ])
    error_message = join(" ", [
      "Each all_systems connection_type must be \"ssh\", \"winrm\", \"ssh-ssm\", \"winrm-ssm\",",
      "or null to take the SSH default. The first half names the protocol on the wire; the",
      "\"-ssm\" suffix means the system is reached through an SSM tunnel rather than directly, so",
      "no inbound path is opened to it. WinRM is Windows-only; a Linux system asking for it is",
      "rejected at plan time, because the operating system is data-resolved and not visible to",
      "this validation.",
    ])
  }

  # An SSM-reached system has no inbound path, and Terraform's connection block speaks only
  # direct SSH and WinRM - it has no ProxyCommand and does not read ssh_config, so it cannot
  # dial through a Session Manager tunnel on its own. Reaching one would need the runner to
  # port-forward first and the gate to target localhost, which is not built. Rejected here
  # rather than silently ignored, so the config states what actually happens.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      !contains(["ssh-ssm", "winrm-ssm"], coalesce(system.connection_type, "ssh")) ||
      system.readiness_gate == false
    ])
    error_message = join(" ", [
      "An all_systems entry using connection_type \"ssh-ssm\" or \"winrm-ssm\" must set",
      "readiness_gate = false. The gate connects directly over SSH or WinRM and cannot traverse",
      "an SSM tunnel, so leaving it enabled would only fail after its ten-minute timeout.",
    ])
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      try(system.tags.Backup != null, false) &&
      system.readiness_gate != null &&
      system.root_block_device != null &&
      system.ebs_block_devices != null &&
      system.ami_block_device_overrides != null &&
      system.network_interfaces != null &&
      alltrue(flatten([
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) : [
          for rule in concat(
            nic.ingress == null ? [] : nic.ingress,
            nic.egress == null ? [] : nic.egress,
          ) : rule.ip_protocol != null
        ]
      ]))
    ])
    error_message = join(" ", [
      "tags.Backup, readiness_gate, root_block_device, ebs_block_devices,",
      "ami_block_device_overrides, and network_interfaces carry no defaults and must not be",
      "null. Give each a real value; use [] for an empty list rather than null.",
      "Network-interface ingress and egress rule ip_protocol values must not be null.",
    ])
  }

  # As above: the type checker catches omission, this catches an explicit null.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.refresh != null && system.associate_public_ip != null
    ])
    error_message = join(" ", [
      "refresh and associate_public_ip carry no defaults and must not be null. Use false to opt",
      "out of either.",
    ])
  }

  # As above: the type checker catches omission, this catches an explicit null.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.instance_type != null
    ])
    error_message = join(" ", [
      "instance_type carries no default and must not be null. Name the instance type this system",
      "runs on.",
    ])
  }

  # IMDS hop limit: explicit and bounded. 1 is the former hardcode; 2 exists only for
  # container hosts whose workloads need IMDS credentials through Docker's NAT hop.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.imds_hop_limit != null && contains([1, 2], system.imds_hop_limit)
    ])
    error_message = join(" ", [
      "Each all_systems entry must set imds_hop_limit explicitly to 1 or 2; use 1 to preserve",
      "the former hardcode, 2 only for systems running containers that need IMDS credentials.",
    ])
  }

  validation {
    condition = length(distinct([
      for system in var.all_systems : system.hostname
    ])) == length(var.all_systems)
    error_message = "Each all_systems entry must have a unique hostname."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      contains(var.aws_config.regions, replace(system.region, "-", "_"))
    ])
    error_message = "Each all_systems entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.set_state == null || contains(["running", "stopped"], system.set_state)
    ])
    error_message = "all_systems set_state, when set, must be exactly \"running\" or \"stopped\"."
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.ebs_block_devices == null || length(system.ebs_block_devices) <= 23
    ])
    error_message = join(" ", [
      "Each all_systems entry supports at most 23 ebs_block_devices (device names run",
      "/dev/sdd..sdz); split larger volume sets across instances.",
    ])
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.ebs_block_devices == null || (
        alltrue([
          for volume in system.ebs_block_devices :
          volume.device_index >= 0 &&
          volume.device_index <= 22 &&
          floor(volume.device_index) == volume.device_index
        ]) &&
        length(distinct([
          for volume in system.ebs_block_devices : volume.device_index
        ])) == length(system.ebs_block_devices)
      )
    ])
    error_message = join(" ", [
      "Each all_systems ebs_block_devices device_index must be a unique integer from 0 through",
      "22 within its system.",
    ])
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.ebs_block_devices == null || length(distinct([
        for volume in system.ebs_block_devices : volume.resource_key
      ])) == length(system.ebs_block_devices)
    ])
    error_message = join(" ", [
      "Each all_systems ebs_block_devices entry must have a unique resource_key within its",
      "system.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for system in var.all_systems : system.ebs_block_devices == null ? [] : [
        for volume in system.ebs_block_devices :
        can(regex("^[0-9A-Za-z][0-9A-Za-z_-]*$", volume.resource_key))
      ]
    ]))
    error_message = join(" ", [
      "Each all_systems ebs_block_devices resource_key must start with a letter or number and",
      "contain only letters, numbers, underscores, or hyphens.",
    ])
  }

  # An arbitrary AMI's platform is data-resolved after variable validation, so reserve both
  # platform spellings derived from each standalone volume's stable device_index.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.ami_block_device_overrides == null || (
        alltrue([
          for override in system.ami_block_device_overrides :
          try(trimspace(override.device_name) != "", false)
        ]) &&
        length(distinct([
          for override in system.ami_block_device_overrides : override.device_name
        ])) == length(system.ami_block_device_overrides) &&
        alltrue([
          for override in system.ami_block_device_overrides :
          try(!contains(
            concat(
              [
                for volume in(system.ebs_block_devices == null ? [] : system.ebs_block_devices) :
                "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
              ],
              [
                for volume in(system.ebs_block_devices == null ? [] : system.ebs_block_devices) :
                "xvd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
              ],
            ),
            override.device_name,
          ), false)
        ])
      )
    ])
    error_message = format(
      join(" ", [
        "Each ami_block_device_overrides device_name must be non-empty, unique within its",
        "system, and distinct from the /dev/sdd../dev/sdz or xvdd..xvdz names reserved by that",
        "system's",
        "ebs_block_devices. Offending system/device pairs: %s.",
      ]),
      join(", ", distinct(flatten([
        for system in var.all_systems : [
          for override in(
            system.ami_block_device_overrides == null ? [] : system.ami_block_device_overrides
          ) :
          format("%s/%s", system.hostname, jsonencode(override.device_name))
          if !try(trimspace(override.device_name) != "", false) ||
          length([
            for candidate in system.ami_block_device_overrides : candidate
            if candidate.device_name == override.device_name
          ]) > 1 ||
          try(contains(
            concat(
              [
                for volume in(system.ebs_block_devices == null ? [] : system.ebs_block_devices) :
                "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
              ],
              [
                for volume in(system.ebs_block_devices == null ? [] : system.ebs_block_devices) :
                "xvd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
              ],
            ),
            override.device_name,
          ), false)
        ]
      ]))),
    )
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      !startswith(system.aws_kms_alias, "alias/")
    ])
    error_message = join(" ", [
      "all_systems aws_kms_alias must NOT include the 'alias/' prefix (it is added",
      "automatically).",
    ])
  }

  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.network_interfaces == null ? true : length(system.network_interfaces) >= 1
    ])
    error_message = join(" ", [
      "Each all_systems entry must define at least one network_interface (the primary",
      "<hostname>-eni-0).",
    ])
  }

  # A network interface is covered when it names at least one pre-created group, OR when both rule
  # collections are non-null and therefore declare that interface's own group. The validation and
  # locals.tf attachment use the same per-interface predicate; otherwise AWS silently supplies the
  # VPC default allow-all group to an uncovered interface.
  validation {
    condition = alltrue([
      for system in var.all_systems : alltrue([
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
        nic.security_groups != null && (
          (nic.ingress != null && nic.egress != null) ||
          length(nic.security_groups) > 0
        )
      ])
    ])
    error_message = join(" ", [
      "Each all_systems network interface must have a non-null security_groups list and either",
      "declare its own group with non-null ingress and egress or list at least one pre-created",
      "group; otherwise AWS attaches the VPC default (allow-all) security group.",
    ])
  }

  # Both rule collections declare the interface's group together. A paired null is the explicit
  # off switch; a half-null pair is ambiguous and would otherwise fail later inside expressions.
  validation {
    condition = alltrue(flatten([
      for system in var.all_systems : [
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
        (nic.ingress == null) == (nic.egress == null)
      ]
    ]))
    error_message = join(" ", [
      "Each all_systems network interface must use matching ingress and egress modes: paired",
      "null creates no interface-owned group and attaches only the pre-created security_groups,",
      "while",
      "non-null lists create the group and [] means that direction has no rules.",
    ])
  }

  # Every rule maps to one provider source/destination attribute. Guard both nullable rule
  # collections here so an invalid rule fails at the framework boundary rather than in AWS.
  validation {
    condition = alltrue(flatten([
      for system in var.all_systems : [
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) : [
          for rule in concat(
            nic.ingress == null ? [] : nic.ingress,
            nic.egress == null ? [] : nic.egress,
            ) : length([
              for source in [
                rule.cidr_ipv4,
                rule.prefix_list_id,
                rule.referenced_security_group_id,
              ] : source if source != null
          ]) == 1
        ]
      ]
    ]))
    error_message = join(" ", [
      "Each network-interface ingress and egress rule must set exactly one of cidr_ipv4,",
      "prefix_list_id, or referenced_security_group_id.",
    ])
  }

  # The derived name is "<hostname>-eni-<interface index>-sg", where index is the interface's raw
  # zero-based position. Validate the rendered framework name rather than a separate hostname
  # approximation. The nine-character "-eni-0-sg" suffix leaves a 246-character hostname budget;
  # index 10 has a ten-character suffix and therefore a 245-character budget.
  validation {
    condition = alltrue(flatten([
      for system in var.all_systems : [
        for interface_index, nic in(
          system.network_interfaces == null ? [] : system.network_interfaces
          ) : (
          length("${system.hostname}-eni-${interface_index}-sg") <= 255 &&
          !startswith(lower("${system.hostname}-eni-${interface_index}-sg"), "sg-") &&
          can(regex(
            "^[0-9A-Za-z][0-9A-Za-z._-]*$",
            "${system.hostname}-eni-${interface_index}-sg"
          ))
        )
        if nic.ingress != null && nic.egress != null
      ]
    ]))
    error_message = join(" ", [
      "A network interface's own group is named \"<hostname>-eni-<interface index>-sg\" from the",
      "interface's raw zero-based position, so the rendered name must be at most 255 characters",
      "(a",
      "246-character hostname at index 0; 245 at index 10), must not start with \"sg-\" in any",
      "letter case, and must contain only letters, numbers, dots, underscores, and hyphens after",
      "a",
      "leading alphanumeric.",
    ])
  }

  # EC2 security-group names are case-insensitive within a VPC. Hostname uniqueness above is
  # deliberately unchanged for backward compatibility, so apply the stricter comparison only to
  # interfaces declaring their own groups and scope it to the normalized region known here. VPC
  # identity is not resolvable during variable validation, so this remains conservative within one
  # region: case-variant names in two different VPCs are rejected even though EC2 would accept
  # them.
  validation {
    condition = length(distinct(flatten([
      for system in var.all_systems : [
        for interface_index, nic in(
          system.network_interfaces == null ? [] : system.network_interfaces
        ) :
        jsonencode([
          replace(system.region, "-", "_"),
          lower("${system.hostname}-eni-${interface_index}-sg"),
        ])
        if nic.ingress != null && nic.egress != null
      ]
      ]))) == sum(concat([0], [
      for system in var.all_systems : length([
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) : nic
        if nic.ingress != null && nic.egress != null
      ])
    ]))
    error_message = join(" ", [
      "Network-interface security-group names derived as",
      "\"<hostname>-eni-<interface index>-sg\" must be unique without regard to letter case",
      "within each region because EC2 security-group names are case-insensitive within a VPC.",
      "Validation",
      "cannot resolve VPC identity, so different VPCs in one region remain subject to this",
      "conservative restriction.",
    ])
  }

  # An interface's own group is attached automatically; naming any such derived group in a
  # security_groups list is invalid. A shared group belongs outside this framework, and
  # cross-system reachability in interface-owned groups is expressed with CIDR rules.
  validation {
    condition = alltrue([
      for system in var.all_systems : alltrue([
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
        nic.security_groups == null || length(setintersection(
          toset([for group in nic.security_groups : lower(group)]),
          toset(flatten([
            for peer in var.all_systems : [
              for interface_index, peer_nic in(
                peer.network_interfaces == null ? [] : peer.network_interfaces
              ) :
              lower("${peer.hostname}-eni-${interface_index}-sg")
              if peer_nic.ingress != null && peer_nic.egress != null
            ]
          ])),
        )) == 0
      ])
    ])
    error_message = join(" ", [
      "An all_systems network_interfaces security_groups list must not name an interface-owned",
      "group (\"<hostname>-eni-<interface index>-sg\"); that group is attached to its own",
      "interface automatically. A group shared across systems belongs outside this framework;",
      "express",
      "cross-system reachability with CIDR rules.",
    ])
  }

  # The provider accepts "-1", zero-padded numeric equivalents, and "all" without regard to
  # letter case as all-protocol spellings. EC2 ignores any port range on those rules, so require
  # null ports to keep the authored rule's apparent scope equal to its effective scope.
  validation {
    condition = alltrue(flatten([
      for system in var.all_systems : [
        for nic in(
          system.network_interfaces == null ? [] : system.network_interfaces
          ) : alltrue([
            for rule in concat(
              nic.ingress == null ? [] : nic.ingress,
              nic.egress == null ? [] : nic.egress,
              ) : rule.ip_protocol == null || (
              (
                lower(rule.ip_protocol) != "all" &&
                !can(regex("^-0*1$", rule.ip_protocol))
              ) ||
              (rule.from_port == null && rule.to_port == null)
            )
        ])
      ]
    ]))
    error_message = join(" ", [
      "All-protocol security-group rules (ip_protocol \"-1\", a zero-padded numeric equivalent,",
      "or \"all\" in any letter case) must leave from_port and to_port null because EC2 ignores",
      "supplied ports and opens all ports.",
    ])
  }

  # The world-open ingress ban (docs/reference/invariants.md) bound to every interface-owned
  # group. Ingress-only by design; unrestricted egress stays supported.
  validation {
    condition = alltrue(flatten([
      for system in var.all_systems : [
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
        nic.ingress == null || alltrue([
          for rule in nic.ingress :
          rule.cidr_ipv4 == null || try(tonumber(split("/", rule.cidr_ipv4)[1]) != 0, false)
        ])
      ]
    ]))
    error_message = format(
      join(" ", [
        "A network-interface security-group ingress rule must not accept a world-open IPv4",
        "source; `cidr_ipv4` must be a well-formed CIDR with a non-zero prefix length.",
        "Unrestricted egress remains supported. Offending system/CIDR pairs: %s.",
      ]),
      join(", ", distinct(flatten([
        for system in var.all_systems : flatten([
          for nic in(system.network_interfaces == null ? [] : system.network_interfaces) : [
            for rule in(nic.ingress == null ? [] : nic.ingress) :
            format("%s/%s", system.hostname, jsonencode(rule.cidr_ipv4))
            if rule.cidr_ipv4 != null &&
            !try(tonumber(split("/", rule.cidr_ipv4)[1]) != 0, false)
          ]
        ])
      ]))),
    )
  }

  validation {
    condition = alltrue([
      for system in var.all_systems : alltrue([
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
        nic.private_ip == null || can(cidrhost("${nic.private_ip}/32", 0))
      ])
    ])
    error_message = join(" ", [
      "Each all_systems network_interfaces private_ip must be a valid IP address or null to let",
      "AWS pick.",
    ])
  }

  # Every interface on a system inherits that system's subnet_id, so two pinned addresses that
  # collide - on one system or across systems sharing a subnet - are a guaranteed apply failure
  # after the ENIs ahead of them in the graph already exist. Auto-assigned (null) addresses cannot
  # collide and are excluded.
  validation {
    condition = length(flatten([
      for system in var.all_systems : [
        for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
        "${system.subnet_id}|${nic.private_ip}"
        if nic.private_ip != null
      ]
      ])) == length(distinct(flatten([
        for system in var.all_systems : [
          for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
          "${system.subnet_id}|${nic.private_ip}"
          if nic.private_ip != null
        ]
    ])))
    error_message = join(" ", [
      "Each pinned all_systems network_interfaces private_ip must be unique within its subnet;",
      "two interfaces in one subnet cannot claim the same address. Leave private_ip null to let",
      "AWS",
      "pick.",
    ])
  }


  # These keys are written by this framework in each tag map's non-overwritable section.
  # A consumer map that reuses one would be silently overwritten, so reject it up front.
  # Matched case-insensitively: AWS tag keys are case-sensitive, so allowing `environment`
  # beside the framework's `Environment` would just recreate the duplicate-tag problem.
  validation {
    condition = alltrue([
      for tags in concat(
        [
          for system in var.all_systems :
          try(system.root_block_device.tags == null ? {} : system.root_block_device.tags, {})
        ],
        flatten([
          for system in var.all_systems : system.ebs_block_devices == null ? [] : [
            for volume in system.ebs_block_devices : volume.tags == null ? {} : volume.tags
          ]
        ]),
        flatten([
          for system in var.all_systems : [
            for nic in(system.network_interfaces == null ? [] : system.network_interfaces) :
            nic.tags == null ? {} : nic.tags
          ]
        ]),
        ) : alltrue([
          for key in keys(tags) : !contains(
            [
              "name", "environment", "managedby", "repository", "repositoryid", "commitsha",
              "runid", "os", "index", "devicename", "backup",
            ],
            lower(key)
          )
      ])
    ])
    error_message = join(" ", [
      "Name, Environment, ManagedBy, Repository, RepositoryId, CommitSha, RunId, OS, Index,",
      "DeviceName, and Backup are written by this framework and would be silently overwritten;",
      "consumer-supplied tag maps must not set them, in any letter case.",
    ])
  }

  # A relative path silently uploads somewhere unexpected and a trailing slash produces a
  # doubled separator; both surface only as a readiness-gate timeout minutes into an apply.
  validation {
    condition = alltrue([
      for system in var.all_systems :
      system.readiness_script_dir == null || (
        startswith(system.readiness_script_dir, "/") &&
        !endswith(system.readiness_script_dir, "/")
      )
    ])
    error_message = join(" ", [
      "Each all_systems readiness_script_dir must be null, which selects /home/ec2-user, or an",
      "absolute path with no trailing slash.",
    ])
  }
}

variable "all_databases" {
  description = <<-EOT
    Define all RDS database instances managed by this framework.
  EOT

  type = list(object({
    # Required: give each attribute below a real value.
    # manage_master_user_password must be true so AWS owns the master secret.
    availability_zone    = string
    aws_kms_alias        = string
    db_name              = string
    db_subnet_group_name = string
    engine               = string
    engine_version       = string
    # Let clients authenticate with a short-lived IAM token instead of a static password, so an
    # application never holds a credential at all. MySQL, MariaDB and PostgreSQL only: the
    # provider rejects it on engines that cannot do it, so this stays a consumer choice rather
    # than a module-owned constant.
    iam_database_authentication_enabled = bool
    instance_class                      = string
    manage_master_user_password         = bool
    region                              = string
    username                            = string

    tags = object({
      #Name        = <Set Automatically From 'db_name'>
      Backup   = bool
      Function = string
      #ManagedBy   = <Statically Set To 'Terraform'>
      #Repository   = <Set Automatically From 'var.repository'>
      #RepositoryId = <Set Automatically From 'var.repository_id'>
      #CommitSha    = <Set Automatically From 'var.commit_sha'>
      #RunId        = <Set Automatically From 'var.run_id'>
      #Environment = <Set Automatically From 'var.environment'>
    })

    # Opt-out: still mandatory in the object type, because optional() is banned
    # (ADR repo/0002). Set null, [] or {} to decline one.
    allocated_storage        = string
    backup_retention_period  = string
    backup_window            = string
    blue_green_update        = bool
    ca_cert_identifier       = string
    dedicated_log_volume     = bool
    delete_automated_backups = bool
    deletion_protection      = bool
    max_allocated_storage    = string
    skip_final_snapshot      = bool
    storage_type             = string
    vpc_security_group_ids   = list(string)

  }))

  default  = []
  nullable = false

  # As above: the type checker catches omission, this catches an explicit null.
  validation {
    condition = alltrue([
      for database in var.all_databases :
      try(database.tags.Backup != null, false) &&
      database.blue_green_update != null
    ])
    error_message = join(" ", [
      "tags.Backup and blue_green_update carry no defaults and must not be null. Give each a",
      "real boolean.",
    ])
  }

  # As above: the type checker catches omission, this catches an explicit null.
  validation {
    condition = alltrue([
      for database in var.all_databases :
      database.allocated_storage != null &&
      database.dedicated_log_volume != null &&
      database.delete_automated_backups != null &&
      database.deletion_protection != null &&
      database.max_allocated_storage != null &&
      database.skip_final_snapshot != null &&
      database.storage_type != null
    ])
    error_message = join(" ", [
      "allocated_storage, dedicated_log_volume, delete_automated_backups, deletion_protection,",
      "max_allocated_storage, skip_final_snapshot, and storage_type carry no defaults and must",
      "not be null.",
    ])
  }

  validation {
    condition = length(distinct([
      for database in var.all_databases : lower(database.db_name)
    ])) == length(var.all_databases)
    error_message = join(" ", [
      "Each all_databases entry must have a case-insensitively unique db_name because the RDS",
      "identifier is lowercased.",
    ])
  }

  validation {
    condition = alltrue([
      for database in var.all_databases :
      contains(var.aws_config.regions, replace(database.region, "-", "_"))
    ])
    error_message = "Each all_databases entry region must normalize to one of aws_config.regions."
  }

  validation {
    condition = alltrue([
      for database in var.all_databases :
      !startswith(database.aws_kms_alias, "alias/")
    ])
    error_message = join(" ", [
      "all_databases aws_kms_alias must NOT include the 'alias/' prefix (it is added",
      "automatically).",
    ])
  }

  validation {
    condition = alltrue([
      for database in var.all_databases :
      database.manage_master_user_password == true
    ])
    error_message = join(" ", [
      "Each all_databases entry must set manage_master_user_password to true. Plaintext RDS",
      "master passwords are not accepted because Terraform would persist them in plans and",
      "state.",
    ])
  }

  validation {
    condition = alltrue([
      for database in var.all_databases :
      try(length(database.vpc_security_group_ids), 0) > 0
    ])
    error_message = join(" ", [
      "Each all_databases entry must specify at least one vpc_security_group_id; a null or empty",
      "list makes AWS attach the VPC default security group.",
    ])
  }
}

# Deployment identity, stamped onto every taggable resource this framework creates. Supplied one
# -var at a time by the deploy workflow (see docs/reference/runner-protocol.md) rather than as a
# single object: a command-line -var outranks every tfvars source, so a runner cannot quietly
# restate any of these in a value file. Every field is required and non-nullable — there is no
# "unattributed" deployment, so no coherence rule is needed to hold the set together.

variable "repository" {
  description = "GitHub owner/name slug of the deploying repository, stamped as the Repository tag."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository))
    error_message = "repository must be an owner/name slug (e.g. nwarila-platform/aws-terraform-framework)."
  }

  validation {
    condition     = length(var.repository) <= 256
    error_message = "repository must be at most 256 characters so its tag value fits the EC2 tag-value limit."
  }
}

variable "repository_id" {
  description = "Numeric, rename-stable GitHub repository id — the anchor of the deployment identity, stamped as the RepositoryId tag."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+$", var.repository_id))
    error_message = "repository_id must be the numeric, rename-stable GitHub repository id."
  }

  validation {
    condition     = length(var.repository_id) <= 256
    error_message = "repository_id must be at most 256 characters so its tag value fits the EC2 tag-value limit."
  }
}

variable "commit_sha" {
  description = "Checked-out commit (git rev-parse HEAD after checkout, not github.sha), stamped as the CommitSha tag."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.commit_sha))
    error_message = "commit_sha must be the lowercase 40-character checked-out commit SHA (git rev-parse HEAD after checkout, not github.sha)."
  }
}

variable "run_id" {
  description = "Numeric GitHub Actions run id, stamped as the RunId tag. The run record holds actors, timestamps, and approvals; those stay in deployment evidence rather than in tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+$", var.run_id))
    error_message = "run_id must be the numeric GitHub Actions run id."
  }
}

# Define Provider Configuration Options.
variable "runner_ip" {
  description = <<-EOT
    Public IPv4 address of the CI runner that must reach every instance for the life of one run.
    Non-null creates ONE security group carrying tcp/22 (SSH), tcp/5986 (WinRM) and ICMP, all
    sourced from "<runner_ip>/32", and attaches it to every network interface this framework
    creates. Null, the default, creates nothing and attaches nothing: the posture for local
    operator runs and for on-prem targets.

    The protocols are module-owned literals, not a consumer input, so no deployment can widen
    this group beyond the transports it exists to serve.

    A bare address, never a CIDR. Accepting a prefix would make a range representable at all;
    requiring a single host makes one structurally impossible, which is a stronger guarantee
    than the world-open ingress ban because the input type enforces it rather than a validation
    rule someone could later relax.

    Pass it at apply time (-var "runner_ip=..."), not from a value file: the address belongs to
    a single run, not to a deployment's committed configuration.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.runner_ip == null || can(regex(
      "^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])[.]){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$",
      var.runner_ip
    ))
    error_message = join(" ", [
      "runner_ip must be a single bare IPv4 address such as 203.0.113.7, carrying no prefix",
      "length. A CIDR is rejected so that a range cannot be expressed at all.",
    ])
  }

  # 0.0.0.0/32 is a host route, not /0, so the world-open ingress ban does not catch it. It is
  # never a real runner address either way, so reject it outright rather than reason about it.
  validation {
    condition = var.runner_ip != "0.0.0.0"
    error_message = join(" ", [
      "runner_ip must not be 0.0.0.0. It is the unspecified address, never a reachable runner,",
      "and 0.0.0.0/32 would slip past the world-open ingress ban because it is a host route.",
    ])
  }
}

variable "aws_config" {
  description = <<-EOT
    Define all of the required environmental variables specific to the AWS provider.
  EOT
  type = object({
    regions = list(string)
  })

  default = {
    regions = ["us_east_1"]
  }
  nullable = false

  validation {
    condition = var.aws_config.regions == tolist(["us_east_1"])
    error_message = join(" ", [
      "aws_config.regions must be exactly [\"us_east_1\"]. Supporting additional regions",
      "requires new provider aliases and per-region resource blocks (a code change), not just a",
      "variable",
      "edit.",
    ])
  }
}

variable "all_load_balancers" {
  description = <<-EOT
    Define all Elastic Load Balancers managed by this framework.
  EOT

  type = list(object({
    # Required: give each attribute below a real value.
    region       = string
    resource_key = string

    # Opt-out: still mandatory in the object type, because optional() is banned
    # (ADR repo/0002). Set null, [] or {} to decline one.
    access_logs = object({
      bucket  = string
      enabled = bool
      prefix  = string
    })
    client_keep_alive = number
    connection_logs = object({
      bucket  = string
      enabled = bool
      prefix  = string
    })
    customer_owned_ipv4_pool                                     = string
    desync_mitigation_mode                                       = string
    dns_record_client_routing_policy                             = string
    drop_invalid_header_fields                                   = bool
    enable_cross_zone_load_balancing                             = bool
    enable_deletion_protection                                   = bool
    enable_http2                                                 = bool
    enable_tls_version_and_cipher_suite_headers                  = bool
    enable_waf_fail_open                                         = bool
    enable_xff_client_port                                       = bool
    enable_zonal_shift                                           = bool
    enforce_security_group_inbound_rules_on_private_link_traffic = string
    health_check_logs = object({
      bucket  = string
      enabled = bool
      prefix  = string
    })
    idle_timeout    = number
    internal        = bool
    ip_address_type = string
    ipam_pools = object({
      ipv4_ipam_pool_id = string
    })
    load_balancer_type = string
    minimum_load_balancer_capacity = object({
      capacity_units = number
    })
    name                                   = string
    name_prefix                            = string
    preserve_host_header                   = bool
    secondary_ips_auto_assigned_per_subnet = number
    security_groups                        = list(string)
    subnet_mapping = list(object({
      allocation_id        = string
      ipv6_address         = string
      private_ipv4_address = string
      subnet_id            = string
    }))
    subnets = list(string)
    target_groups = list(object({
      resource_key                      = string
      function                          = string
      vpc_id                            = string
      port                              = number
      protocol                          = string
      protocol_version                  = string
      target_type                       = string
      deregistration_delay              = number
      slow_start                        = number
      load_balancing_algorithm_type     = string
      load_balancing_anomaly_mitigation = string
      load_balancing_cross_zone_enabled = string
      preserve_client_ip                = string
      proxy_protocol_v2                 = bool
      connection_termination            = bool
      ip_address_type                   = string
      health_check = object({
        enabled             = bool
        healthy_threshold   = number
        interval            = number
        matcher             = string
        path                = string
        port                = string
        protocol            = string
        timeout             = number
        unhealthy_threshold = number
      })
      stickiness = object({
        type            = string
        cookie_duration = number
        cookie_name     = string
        enabled         = bool
      })
      tags = map(string)
    }))
    listeners = list(object({
      resource_key                = string
      port                        = number
      protocol                    = string
      ssl_policy                  = string
      alpn_policy                 = string
      certificate_arn             = string
      additional_certificate_arns = list(string)
      default_action = object({
        type             = string
        target_group_key = string
        redirect = object({
          status_code = string
          host        = string
          path        = string
          port        = string
          protocol    = string
          query       = string
        })
        fixed_response = object({
          content_type = string
          message_body = string
          status_code  = string
        })
      })
      rules = list(object({
        resource_key = string
        priority     = number
        action = object({
          type             = string
          target_group_key = string
          redirect = object({
            status_code = string
            host        = string
            path        = string
            port        = string
            protocol    = string
            query       = string
          })
          fixed_response = object({
            content_type = string
            message_body = string
            status_code  = string
          })
        })
        conditions = list(object({
          host_header         = list(string)
          path_pattern        = list(string)
          http_request_method = list(string)
          source_ip           = list(string)
          http_header = object({
            http_header_name = string
            values           = list(string)
          })
          query_string = list(object({
            key   = string
            value = string
          }))
        }))
      }))
    }))
    tags = map(string)
    timeouts = object({
      create = string
      delete = string
      update = string
    })
    xff_header_processing_mode = string
  }))

  default  = []
  nullable = false

  # As above: the type checker catches omission, this catches an explicit null.
  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers : try(
        load_balancer.internal != null &&
        load_balancer.ip_address_type != null &&
        load_balancer.load_balancer_type != null &&
        load_balancer.subnet_mapping != null &&
        load_balancer.subnets != null &&
        load_balancer.target_groups != null &&
        alltrue([
          for target_group in load_balancer.target_groups :
          target_group.target_type != null
        ]) &&
        load_balancer.listeners != null &&
        alltrue([
          for listener in load_balancer.listeners :
          listener.additional_certificate_arns != null &&
          listener.default_action.type != null &&
          listener.rules != null &&
          alltrue([
            for rule in listener.rules :
            rule.action.type != null
          ])
        ]),
        false
      )
    ])
    error_message = join(" ", [
      "Each all_load_balancers entry must explicitly set internal, ip_address_type,",
      "load_balancer_type, target_groups[*].target_type, listeners[*].default_action.type,",
      "listeners[*].rules[*].action.type, and the subnet_mapping, subnets, target_groups,",
      "listeners, listeners[*].rules, and listeners[*].additional_certificate_arns collections",
      "(use [] for unused collections); this variable carries no defaults. Which values each of",
      "those accepts is enforced by its own validation, not by this one.",
    ])
  }

  validation {
    condition = length(distinct([
      for load_balancer in var.all_load_balancers : load_balancer.resource_key
    ])) == length(var.all_load_balancers)
    error_message = "Each all_load_balancers entry must have a unique resource_key."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      can(regex("^[0-9A-Za-z][0-9A-Za-z_-]*$", load_balancer.resource_key))
    ])
    error_message = join(" ", [
      "Each all_load_balancers resource_key must start with a letter or number and contain only",
      "letters, numbers, underscores, or hyphens.",
    ])
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.subnets == null ||
      load_balancer.subnet_mapping == null ||
      (length(load_balancer.subnets) > 0 ? 1 : 0) +
      (length(load_balancer.subnet_mapping) > 0 ? 1 : 0) == 1
    ])
    error_message = join(" ", [
      "Each all_load_balancers entry must set exactly one of subnets or",
      "subnet_mapping.",
    ])
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      contains(var.aws_config.regions, replace(load_balancer.region, "-", "_"))
    ])
    error_message = join(" ", [
      "Each all_load_balancers entry region must normalize to one of",
      "aws_config.regions.",
    ])
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.internal == null ||
      load_balancer.ip_address_type == null ||
      !load_balancer.internal ||
      load_balancer.ip_address_type == "ipv4"
    ])
    error_message = "Internal load balancers must use ip_address_type ipv4."
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.internal == null || load_balancer.internal == true
    ])
    error_message = join(" ", [
      "Each all_load_balancers entry must be internal; public load balancers are not",
      "allowed.",
    ])
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.load_balancer_type == null ||
      !contains(["application", "network"], load_balancer.load_balancer_type) ||
      (load_balancer.security_groups != null && length(load_balancer.security_groups) > 0)
    ])
    error_message = join(" ", [
      "Application and network load balancers must specify at least one security group; omitting",
      "it attaches the VPC default (allow-all) security group.",
    ])
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.target_groups == null || length(distinct([
        for target_group in load_balancer.target_groups : target_group.resource_key
      ])) == length(load_balancer.target_groups)
    ])
    error_message = join(" ", [
      "Each all_load_balancers target_groups entry must have a unique resource_key within its",
      "load balancer.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.target_groups == null ? [] : [
        for target_group in load_balancer.target_groups :
        can(regex("^[0-9A-Za-z][0-9A-Za-z_-]*$", target_group.resource_key))
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers target_groups resource_key must start with a letter or number and",
      "contain only letters, numbers, underscores, or hyphens.",
    ])
  }

  validation {
    condition = alltrue([
      for load_balancer in var.all_load_balancers :
      load_balancer.listeners == null || length(distinct([
        for listener in load_balancer.listeners : listener.resource_key
      ])) == length(load_balancer.listeners)
    ])
    error_message = join(" ", [
      "Each all_load_balancers listeners entry must have a unique resource_key within its load",
      "balancer.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners :
        listener.rules == null || length(distinct([
          for rule in listener.rules : rule.resource_key
        ])) == length(listener.rules)
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener rule must have a unique resource_key within its",
      "listener.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners :
        listener.rules == null || length(distinct([
          for rule in listener.rules : rule.priority
        ])) == length(listener.rules)
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener rule must have a unique priority within its",
      "listener.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers :
      load_balancer.listeners == null || load_balancer.target_groups == null ? [] : [
        for listener in load_balancer.listeners :
        listener.default_action.target_group_key == null ? true : contains([
          for target_group in load_balancer.target_groups : target_group.resource_key
        ], listener.default_action.target_group_key)
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener default_action target_group_key must reference a",
      "target_groups resource_key on the same load balancer.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers :
      load_balancer.listeners == null || load_balancer.target_groups == null ? [] : [
        for listener in load_balancer.listeners : listener.rules == null ? [] : [
          for rule in listener.rules :
          rule.action.target_group_key == null ? true : contains([
            for target_group in load_balancer.target_groups : target_group.resource_key
          ], rule.action.target_group_key)
        ]
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener rule action target_group_key must reference a",
      "target_groups resource_key on the same load balancer.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners :
        listener.default_action.type == null ? true : (
          listener.default_action.type == "forward" ? (
            listener.default_action.target_group_key != null &&
            listener.default_action.redirect == null &&
            listener.default_action.fixed_response == null
            ) : listener.default_action.type == "redirect" ? (
            listener.default_action.target_group_key == null &&
            listener.default_action.redirect != null &&
            listener.default_action.fixed_response == null
            ) : listener.default_action.type == "fixed-response" ? (
            listener.default_action.target_group_key == null &&
            listener.default_action.redirect == null &&
            listener.default_action.fixed_response != null
          ) : false
        )
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener default_action must set exactly one payload matching",
      "type: forward requires target_group_key only, redirect requires redirect only, and",
      "fixed-response",
      "requires fixed_response only.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners : listener.rules == null ? [] : [
          for rule in listener.rules :
          rule.action.type == null ? true : rule.action.type == "forward" ? (
            rule.action.target_group_key != null &&
            rule.action.redirect == null &&
            rule.action.fixed_response == null
            ) : rule.action.type == "redirect" ? (
            rule.action.target_group_key == null &&
            rule.action.redirect != null &&
            rule.action.fixed_response == null
            ) : rule.action.type == "fixed-response" ? (
            rule.action.target_group_key == null &&
            rule.action.redirect == null &&
            rule.action.fixed_response != null
          ) : false
        ]
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener rule action must set exactly one payload matching type:",
      "forward requires target_group_key only, redirect requires redirect only, and",
      "fixed-response requires fixed_response only.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.target_groups == null ? [] : [
        for target_group in load_balancer.target_groups :
        target_group.function != null && trimspace(target_group.function) != ""
      ]
    ]))
    error_message = "Each all_load_balancers target_groups entry must set a non-empty function."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.target_groups == null ? [] : [
        for target_group in load_balancer.target_groups :
        target_group.target_type == null || target_group.target_type == "instance"
      ]
    ]))
    error_message = "Each all_load_balancers target_groups target_type must be instance."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners : listener.rules == null ? [] : [
          for rule in listener.rules :
          rule.conditions != null && length(rule.conditions) >= 1
        ]
      ]
    ]))
    error_message = "Each all_load_balancers listener rule must set at least one condition."
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners : listener.rules == null ? [] : [
          for rule in listener.rules : [
            for condition in rule.conditions == null ? [] : rule.conditions :
            length(compact([
              condition.host_header == null ? "" : "host_header",
              condition.http_header == null ? "" : "http_header",
              condition.http_request_method == null ? "" : "http_request_method",
              condition.path_pattern == null ? "" : "path_pattern",
              condition.query_string == null ? "" : "query_string",
              condition.source_ip == null ? "" : "source_ip",
            ])) == 1
          ]
        ]
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener rule condition must set exactly one of host_header,",
      "http_header, http_request_method, path_pattern, query_string, or source_ip.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners : listener.rules == null ? [] : [
          for rule in listener.rules : [
            for condition in rule.conditions == null ? [] : rule.conditions :
            (condition.host_header == null ? true : length(condition.host_header) > 0) &&
            (condition.path_pattern == null ? true : length(condition.path_pattern) > 0) &&
            (
              condition.http_request_method == null ?
              true : length(condition.http_request_method) > 0
            ) &&
            (condition.source_ip == null ? true : length(condition.source_ip) > 0) &&
            (condition.http_header == null ? true : length(condition.http_header.values) > 0) &&
            (condition.query_string == null ? true : length(condition.query_string) > 0)
          ]
        ]
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener rule condition value list must be non-empty when",
      "set.",
    ])
  }

  validation {
    condition = alltrue(flatten([
      for load_balancer in var.all_load_balancers : load_balancer.listeners == null ? [] : [
        for listener in load_balancer.listeners :
        listener.additional_certificate_arns == null ||
        length(distinct(listener.additional_certificate_arns)) ==
        length(listener.additional_certificate_arns)
      ]
    ]))
    error_message = join(" ", [
      "Each all_load_balancers listener additional_certificate_arns list must not contain",
      "duplicates.",
    ])
  }

  # Same reserved keys, bound to the load-balancer tag maps.
  validation {
    condition = alltrue([
      for tags in concat(
        [
          for load_balancer in var.all_load_balancers :
          load_balancer.tags == null ? {} : load_balancer.tags
        ],
        flatten([
          for load_balancer in var.all_load_balancers :
          load_balancer.target_groups == null ? [] : [
            for target_group in load_balancer.target_groups :
            target_group.tags == null ? {} : target_group.tags
          ]
        ]),
        ) : alltrue([
          for key in keys(tags) : !contains(
            [
              "name", "environment", "managedby", "repository", "repositoryid", "commitsha",
              "runid", "os", "index", "devicename", "backup",
            ],
            lower(key)
          )
      ])
    ])
    error_message = join(" ", [
      "Name, Environment, ManagedBy, Repository, RepositoryId, CommitSha, RunId, OS, Index,",
      "DeviceName, and Backup are written by this framework and would be silently overwritten;",
      "consumer-supplied tag maps must not set them, in any letter case.",
    ])
  }
}
