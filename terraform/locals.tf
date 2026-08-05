# The brain of the plan: every object consumed by resources.tf is shaped here from
# variables, data lookups, and managed-capability resources.

# Statically Configured LOCALS
locals {
  public_ami_aliases = toset([
    "windows_server_2022_base",
    "windows_server_2025_base",
  ])

  ami_specs = {
    for ami in toset([for system in var.all_systems : system.ami]) : ami => {
      is_direct_id    = can(regex("^ami-[0-9a-f]{8,17}$", ami))
      is_public_alias = contains(local.public_ami_aliases, ami)
      is_versioned    = can(regex(":", ami))
      family          = split(":", ami)[0]
      version         = can(regex(":", ami)) ? split(":", ami)[1] : null
      glob            = can(regex(":", ami)) ? "${split(":", ami)[0]}_v${split(":", ami)[1]}_*" : "${ami}_v*"
      name_regex      = can(regex(":", ami)) ? "^${replace(split(":", ami)[0], ".", "\\.")}_v${replace(split(":", ami)[1], ".", "\\.")}_" : "^${replace(ami, ".", "\\.")}_v[0-9]"
    }
  }

  amazon_machine_images = merge(
    {
      "windows_server_2022_base" = {
        us_east_1 = try(data.aws_ami.us_east_1_windows_server_2022_base[0], null)
      }
      "windows_server_2025_base" = {
        us_east_1 = try(data.aws_ami.us_east_1_windows_server_2025_base[0], null)
      }
    },
    {
      for ami, spec in local.ami_specs : ami => {
        us_east_1 = try(data.aws_ami.us_east_1_direct[ami], null)
      }
      if spec.is_direct_id
    },
    {
      for ami, spec in local.ami_specs : ami => {
        us_east_1 = try(data.aws_ami.us_east_1_selfbuilt[ami], null)
      }
      if !spec.is_direct_id && !spec.is_public_alias
    }
  )

  # SSH bootstrap user_data.
  # Windows: self-contained, idempotent, version-aware OpenSSH bootstrap. It (1) installs the
  #   OpenSSH.Server capability only if not already Present (WS2025 ships it; WS2019/2022 install it
  #   as a Feature-on-Demand), preferring a local -Source when var.windows_openssh_source is set and
  #   otherwise pulling from Windows Update; (2) VERIFIES the capability is Installed and fails loudly
  #   (exit 1) if not, because the FoD install fails silently with no egress; (3) installs the launch
  #   key-pair public key from IMDSv2 for administrator SSH with the documented ACLs. The OpenSSH
  #   default shell is intentionally left as cmd; setting it to PowerShell breaks Terraform
  #   remote-exec SCP upload when this dormant SSH bootstrap is re-activated.
  # Linux: cloud-init enables sshd, then best-effort ensures the SSM agent — enabled in place if the
  #   AMI already ships it, else the region's RPM is fetched from S3 (reachable via an S3 gateway
  #   endpoint on private subnets, or the IGW/NAT otherwise) and installed. This makes non-Amazon
  #   AMIs that omit the agent (CIS/STIG RHEL) SSM-reachable without a public IP. The __AWS_REGION__
  #   sentinel is substituted with the hyphenated region per-system in local.elastic_compute_cloud.
  windows_ssh_user_data = <<-WINDOWS_USER_DATA
    <powershell>
    $ErrorActionPreference = "Stop"
    $source = "${var.windows_openssh_source}"

    # 1. Ensure the OpenSSH Server capability is present (idempotent + version-aware).
    $capability = Get-WindowsCapability -Online -Name "OpenSSH.Server*"
    if ($capability.State -ne "Installed") {
      if ($source) {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -Source $source -LimitAccess
      } else {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
      }
      $capability = Get-WindowsCapability -Online -Name "OpenSSH.Server*"
      if ($capability.State -ne "Installed") {
        Write-Error "OpenSSH.Server is still NotPresent after install (no Windows Update egress and no -Source supplied?). Aborting SSH bootstrap."
        exit 1
      }
    }

    # 2. Enable and start the sshd service.
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd

    # 3. Install the launch key-pair public key (from IMDSv2) for administrator SSH.
    $token = Invoke-RestMethod -Method PUT -Uri http://169.254.169.254/latest/api/token -Headers @{ "X-aws-ec2-metadata-token-ttl-seconds" = "21600" }
    $publicKey = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key -Headers @{ "X-aws-ec2-metadata-token" = $token }
    $authorizedKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
    Set-Content -Path $authorizedKeys -Value $publicKey -Encoding ascii
    icacls $authorizedKeys /inheritance:r /grant "Administrators:F" "SYSTEM:F"
    </powershell>
  WINDOWS_USER_DATA

  linux_ssh_user_data = <<-LINUX_USER_DATA
    #cloud-config
    runcmd:
      - systemctl enable --now sshd || systemctl enable --now ssh
      - systemctl enable --now amazon-ssm-agent 2>/dev/null || curl -sSL -o /root/amazon-ssm-agent.rpm https://s3.__AWS_REGION__.amazonaws.com/amazon-ssm-__AWS_REGION__/latest/linux_amd64/amazon-ssm-agent.rpm
      - test -f /root/amazon-ssm-agent.rpm && rpm -Uvh --replacepkgs /root/amazon-ssm-agent.rpm && systemctl enable --now amazon-ssm-agent
  LINUX_USER_DATA

  # Deployment identity tags. Applied to every taggable AWS resource through provider default_tags
  # (providers.tf) and merged explicitly into EC2 root_block_device tags below, which
  # provider default_tags cannot reach. Null resource_metadata (the default) emits zero tags so
  # consumers that have not opted in keep byte-identical plans.
  deployment_tags = var.resource_metadata == null ? {} : merge(
    {
      "nwarila:management:managed-by"    = "terraform"
      "nwarila:management:repository"    = var.resource_metadata.repository
      "nwarila:management:repository-id" = var.resource_metadata.repository_id
      "nwarila:management:stack"         = var.resource_metadata.stack
      "nwarila:management:environment"   = var.environment
      "nwarila:operations:owner"         = var.resource_metadata.owner
    },
    var.resource_metadata.commit_sha == null ? {} : { "nwarila:provenance:commit-sha" = var.resource_metadata.commit_sha },
    var.resource_metadata.run_id == null ? {} : { "nwarila:provenance:run-id" = var.resource_metadata.run_id },
  )

  # Readiness-gate wait commands (selected per-OS in terraform_data.readiness_gate), both executed
  # over SSH. Each blocks until the OS launch/provisioning agent reports completion after Terraform
  # has first connected.
  windows_readiness_command = "\"C:\\Program Files\\Amazon\\EC2Launch\\EC2Launch.exe\" status -b"
  linux_readiness_command   = "cloud-init status --wait"
}


# Dynamically Configured LOCALS
locals {

  # Resolve each referenced key-pair name to its source: the framework-managed aws_key_pair when
  # the name matches a managed_keypairs entry, otherwise the pre-existing key-pair data lookup.
  # Same keys the EC2 resources already use, so managed adoption never re-keys any resource.
  key_pair_names = {
    us_east_1 = merge(
      { for name, keypair in data.aws_key_pair.us_east_1 : name => keypair.key_name },
      { for name, keypair in aws_key_pair.us_east_1 : name => keypair.key_name },
    )
  }

  # Each interface with non-null rule collections declares one group at its raw interface index.
  # Its "<hostname>-eni-<index>-sg" name pairs it visibly with the corresponding ENI. The region
  # and VPC come from the parent system because every interface already uses that system's subnet.
  # Description and tags come from the interface itself; a null description uses a stable framework
  # string.
  network_interface_security_groups = merge(concat([{}], [
    for system in var.all_systems : {
      for interface_index, network_interface in system.network_interfaces :
      "${system.hostname}-eni-${interface_index}-sg" => {
        name   = "${system.hostname}-eni-${interface_index}-sg"
        region = replace(system.region, "-", "_")
        vpc_id = (
          contains(keys(var.managed_networks), system.subnet_id)
          ? system.subnet_id
          : lookup(
            local.alias_vpc_ids,
            system.subnet_id,
            data.aws_subnet.us_east_1_inline_security_group[system.subnet_id].vpc_id
          )
        )
        description = network_interface.description != null ? network_interface.description : "Managed by aws-terraform-framework."
        ingress     = network_interface.ingress
        egress      = network_interface.egress
        tags        = network_interface.tags
      }
      if network_interface.ingress != null && network_interface.egress != null
    }
  ])...)

  # Interface-owned security groups partitioned per region (same normalization rule the systems
  # use).
  network_interface_security_groups_by_region = {
    for region in var.aws_config.regions : region => {
      for name, group in local.network_interface_security_groups : name => group
      if group.region == region
    }
  }

  # Normalize every interface-owned rule into its AWS identity. Description is deliberately absent:
  # AWS duplicate detection and resource replacement are determined by direction, protocol, ports,
  # and destination. Field values in the readable prefix are lowercased, sanitized to alphanumerics
  # and hyphens, and bounded; the digest preserves the full normalized identity when sanitization or
  # truncation makes two readable prefixes alike.
  network_interface_security_group_rule_entries = {
    for region in var.aws_config.regions : region => flatten([
      for name, group in local.network_interface_security_groups_by_region[region] : concat(
        [
          for rule in group.ingress : {
            direction = "ingress"
            identity = jsonencode([
              "ingress",
              lower(rule.ip_protocol),
              rule.from_port,
              rule.to_port,
              rule.cidr_ipv4 != null ? "cidr_ipv4" : rule.cidr_ipv6 != null ? "cidr_ipv6" : rule.prefix_list_id != null ? "prefix_list_id" : rule.referenced_security_group_id != null ? "referenced_security_group_id" : "missing",
              lower(rule.cidr_ipv4 != null ? rule.cidr_ipv4 : rule.cidr_ipv6 != null ? rule.cidr_ipv6 : rule.prefix_list_id != null ? rule.prefix_list_id : rule.referenced_security_group_id != null ? rule.referenced_security_group_id : "missing"),
            ])
            readable_identity = join("-", [
              "ingress",
              "protocol",
              substr(replace(lower(rule.ip_protocol), "/[^0-9a-z]+/", "-"), 0, 32),
              "ports",
              rule.from_port == null ? "none" : tostring(rule.from_port),
              rule.to_port == null ? "none" : tostring(rule.to_port),
              rule.cidr_ipv4 != null ? "cidr-ipv4" : rule.cidr_ipv6 != null ? "cidr-ipv6" : rule.prefix_list_id != null ? "prefix-list-id" : rule.referenced_security_group_id != null ? "referenced-security-group-id" : "missing",
              substr(replace(lower(rule.cidr_ipv4 != null ? rule.cidr_ipv4 : rule.cidr_ipv6 != null ? rule.cidr_ipv6 : rule.prefix_list_id != null ? rule.prefix_list_id : rule.referenced_security_group_id != null ? rule.referenced_security_group_id : "missing"), "/[^0-9a-z]+/", "-"), 0, 64),
            ])
            rule   = rule
            sg_key = name
          }
        ],
        [
          for rule in group.egress : {
            direction = "egress"
            identity = jsonencode([
              "egress",
              lower(rule.ip_protocol),
              rule.from_port,
              rule.to_port,
              rule.cidr_ipv4 != null ? "cidr_ipv4" : rule.cidr_ipv6 != null ? "cidr_ipv6" : rule.prefix_list_id != null ? "prefix_list_id" : rule.referenced_security_group_id != null ? "referenced_security_group_id" : "missing",
              lower(rule.cidr_ipv4 != null ? rule.cidr_ipv4 : rule.cidr_ipv6 != null ? rule.cidr_ipv6 : rule.prefix_list_id != null ? rule.prefix_list_id : rule.referenced_security_group_id != null ? rule.referenced_security_group_id : "missing"),
            ])
            readable_identity = join("-", [
              "egress",
              "protocol",
              substr(replace(lower(rule.ip_protocol), "/[^0-9a-z]+/", "-"), 0, 32),
              "ports",
              rule.from_port == null ? "none" : tostring(rule.from_port),
              rule.to_port == null ? "none" : tostring(rule.to_port),
              rule.cidr_ipv4 != null ? "cidr-ipv4" : rule.cidr_ipv6 != null ? "cidr-ipv6" : rule.prefix_list_id != null ? "prefix-list-id" : rule.referenced_security_group_id != null ? "referenced-security-group-id" : "missing",
              substr(replace(lower(rule.cidr_ipv4 != null ? rule.cidr_ipv4 : rule.cidr_ipv6 != null ? rule.cidr_ipv6 : rule.prefix_list_id != null ? rule.prefix_list_id : rule.referenced_security_group_id != null ? rule.referenced_security_group_id : "missing"), "/[^0-9a-z]+/", "-"), 0, 64),
            ])
            rule   = rule
            sg_key = name
          }
        ],
      )
    ])
  }

  # Stable rule address:
  # "<sg>/<direction>-protocol-<protocol>-ports-<from>-<to>-<destination kind>-<destination>-<digest>".
  # An exact identity collision raises Terraform's duplicate-object-key error at plan time rather
  # than silently losing a rule.
  network_interface_security_group_rules = {
    for region in var.aws_config.regions : region => {
      for entry in local.network_interface_security_group_rule_entries[region] :
      "${entry.sg_key}/${entry.readable_identity}-${substr(sha256(entry.identity), 0, 12)}" => merge(
        entry.rule,
        {
          direction = entry.direction
          sg_key    = entry.sg_key
        },
      )
    }
  }

  # Name -> interface-owned SG id, used to attach each group only to its declaring interface.
  network_interface_security_group_ids = {
    us_east_1 = { for name, group in aws_security_group.us_east_1 : name => group.id }
  }

  # Managed networks partitioned per region (same normalization rule the systems use).
  managed_networks_by_region = {
    for region in var.aws_config.regions : region => {
      for name, network in var.managed_networks : name => network
      if replace(network.region, "-", "_") == region
    }
  }

  # Network key -> VPC id (framework-created VPC, or the BYO vpc_id passthrough).
  managed_vpc_ids = {
    us_east_1 = {
      for name, network in local.managed_networks_by_region.us_east_1 :
      name => network.vpc_id != null ? network.vpc_id : aws_vpc.us_east_1[name].id
    }
  }

  # Network key -> created subnet id, used to resolve managed names in all_systems[*].subnet_id.
  managed_subnet_ids = {
    us_east_1 = { for name, subnet in aws_subnet.us_east_1 : name => subnet.id }
  }

  # Alias key -> caller-supplied subnet id.
  alias_subnet_ids = { for name, alias in var.network_aliases : name => alias.subnet_id }

  # Alias key -> caller-supplied VPC id when present.
  alias_vpc_ids = {
    for name, alias in var.network_aliases : name => alias.vpc_id
    if alias.vpc_id != null
  }

  # Systems that requested a stable public IPv4: an EIP is allocated and associated with the
  # primary ENI.
  eip_systems = {
    for region in var.aws_config.regions : region => {
      for system in var.all_systems : system.hostname => system
      if replace(system.region, "-", "_") == region && system.associate_public_ip
    }
  }

  elastic_compute_cloud = {
    for region in var.aws_config.regions : region => {
      for system in var.all_systems : system.hostname => {

        region               = region
        ami                  = system.ami
        availability_zone    = system.availability_zone
        is_windows           = local.amazon_machine_images[system.ami][region].platform == "windows"
        key_name             = system.key_name
        iam_instance_profile = system.iam_instance_profile
        user_data            = trimspace(local.amazon_machine_images[system.ami][region].platform == "windows" ? local.windows_ssh_user_data : replace(local.linux_ssh_user_data, "__AWS_REGION__", replace(region, "_", "-")))
        hostname             = system.hostname
        instance_type        = system.instance_type
        readiness_user       = system.readiness_user
        readiness_gate       = system.readiness_gate
        refresh              = system.refresh
        set_state            = system.set_state
        imds_hop_limit       = system.imds_hop_limit

        root_block_device = {
          volume_size           = system.root_block_device.volume_size
          volume_type           = system.root_block_device.volume_type
          encrypted             = true
          iops                  = system.root_block_device.iops
          kms_key_id            = system.aws_kms_alias
          delete_on_termination = system.root_block_device.delete_on_termination
          throughput            = system.root_block_device.throughput

          tags = merge(
            system.root_block_device.tags,
            {
              index       = 0
              Name        = system.hostname
              Environment = var.environment
            },
            local.deployment_tags
          )
        }

        tags = merge(
          system.tags,
          # Normalized Overwritable Tags
          {
            Backup = system.tags["Backup"] ? "True" : "False"
          },
          # Non-Overwritable Default Tags
          {
            Name        = system.hostname
            Environment = var.environment
            Terraform   = "True"
            ManagedBy   = "Terraform"
            OS          = local.amazon_machine_images[system.ami][region].platform_details
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region
    }
  }

  # The ONLY place the physical instance resources are enumerated. Two resources exist because
  # `lifecycle` is a static meta-argument (base/refresh); HCL cannot
  # iterate resource addresses, so they are merged here once. Hostnames are validated-unique and
  # each system lives in exactly one region, so this merge is a disjoint union.
  all_ec2_instances = merge(
    aws_instance.us_east_1,
    aws_instance.us_east_1_refresh,
  )

  # Config entries keyed by hostname across all regions (disjoint union; see above).
  systems_by_hostname = merge(values(local.elastic_compute_cloud)...)

  # Combine each instance's runtime facts (id, private IP, key pair name) with its OS so the
  # readiness gate can pick the right login user and wait command per instance. Both platforms
  # authenticate over SSH with the launch key pair (the Windows bootstrap installs the launch
  # public key for Administrator); WinRM is decommissioned. Systems that set
  # readiness_gate = false (for example zero-inbound SSM-only boxes) are excluded entirely.
  readiness_targets = {
    for hostname, instance in local.all_ec2_instances : hostname => {
      id             = instance.id
      private_ip     = instance.private_ip
      key_name       = instance.key_name
      is_windows     = local.systems_by_hostname[hostname].is_windows
      readiness_user = local.systems_by_hostname[hostname].readiness_user
    }
    if local.systems_by_hostname[hostname].readiness_gate
  }

  elastic_network_interfaces = {
    for region in var.aws_config.regions : region => merge([
      for system in var.all_systems : {
        for index in range(length(system.network_interfaces)) :
        "${system.hostname}-eni-${index}" => {

          # AWS Network Interface Properties
          description    = system.network_interfaces[index].description
          hostname       = system.hostname
          index          = index
          interface_type = system.network_interfaces[index].interface_type
          # Null lets AWS pick a free address from the subnet CIDR.
          private_ips = system.network_interfaces[index].private_ip == null ? null : [system.network_interfaces[index].private_ip]
          # The pre-existing security-group ids the consumer listed plus this interface's own group
          # when its rule collections are non-null. The same per-interface predicate guards both
          # validation and attachment, so an interface can never silently receive the VPC default
          # allow-all group.
          security_groups = concat(
            system.network_interfaces[index].security_groups,
            (
              system.network_interfaces[index].ingress != null &&
              system.network_interfaces[index].egress != null
            ) ? [local.network_interface_security_group_ids[region]["${system.hostname}-eni-${index}-sg"]]
            : [],
          )
          subnet_id = lookup(local.managed_subnet_ids[region], system.subnet_id, lookup(local.alias_subnet_ids, system.subnet_id, system.subnet_id))

          # ?Note: Merges all of the defined user tags (if any) with the 'default' automatically
          # ?      calculated tags. The default tags cannot be overwritten, if the user provides
          # ?      tags with the same name, the default tags will take precedence.
          tags = merge(
            system.network_interfaces[index].tags,
            {
              Index       = index
              Name        = system.hostname
              Environment = var.environment
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region
    ]...)
  }

  ebs_block_devices = {
    for region in var.aws_config.regions : region => merge([
      for system in var.all_systems : {
        for index in range(length(system.ebs_block_devices)) :
        "${system.hostname}-ebs-${index}" => {

          # AWS Elastic Block Store Properties
          availability_zone = system.availability_zone
          # Device suffixes deliberately start at d and run d..z for up to 23 EBS volumes.
          device_name = local.elastic_compute_cloud[region][system.hostname].is_windows ? "xvd${jsondecode(format("\"\\u%04x\"", 100 + index))}" : (
            "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + index))}"
          )
          encrypted    = true
          hostname     = system.hostname
          index        = index
          iops         = system.ebs_block_devices[index].iops
          refresh      = system.refresh
          snapshot_id  = system.ebs_block_devices[index].snapshot_id
          skip_destroy = system.ebs_block_devices[index].skip_destroy
          throughput   = system.ebs_block_devices[index].throughput
          volume_size  = system.ebs_block_devices[index].volume_size
          volume_type  = system.ebs_block_devices[index].volume_type

          # ?Note: This is property relies on a data lookup, which is region specific, so its
          # ?  final value is actually calculated in the 'aws_ebs_volume' resource.
          kms_key_id = system.aws_kms_alias

          # ?Note: Merges all of the defined user tags (if any) with the 'default' automatically
          # ?      calculated tags. The default tags cannot be overwritten, if the user provides
          # ?      tags with the same name, the default tags will take precedence.
          tags = merge(
            try(system.ebs_block_devices[index].tags, {}),
            {
              Name        = system.hostname
              Index       = index
              Environment = var.environment
              # ?Note: Dynamically assign a predictable device name by using the index to increment
              # ?      a [char] lookup. Unicode character set is used in the conversion, so
              # ?      [INT]100 converted to Unicode [CHAR] is 'd', then each index increment after
              # ?      that will iterate through next characters (I.E. e, f, g, h, etc.) up to z.
              DeviceName = local.elastic_compute_cloud[region][system.hostname].is_windows ? "xvd${jsondecode(format("\"\\u%04x\"", 100 + index))}" : (
                "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + index))}"
              )
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region && system.ebs_block_devices != null
    ]...)
  }

  elastic_load_balancers = {
    for region in var.aws_config.regions : region => {
      for load_balancer in var.all_load_balancers : load_balancer.resource_key => {

        access_logs                                                  = load_balancer.access_logs
        client_keep_alive                                            = load_balancer.client_keep_alive
        connection_logs                                              = load_balancer.connection_logs
        customer_owned_ipv4_pool                                     = load_balancer.customer_owned_ipv4_pool
        desync_mitigation_mode                                       = load_balancer.desync_mitigation_mode
        dns_record_client_routing_policy                             = load_balancer.dns_record_client_routing_policy
        drop_invalid_header_fields                                   = load_balancer.drop_invalid_header_fields
        enable_cross_zone_load_balancing                             = load_balancer.enable_cross_zone_load_balancing
        enable_deletion_protection                                   = load_balancer.enable_deletion_protection
        enable_http2                                                 = load_balancer.enable_http2
        enable_tls_version_and_cipher_suite_headers                  = load_balancer.enable_tls_version_and_cipher_suite_headers
        enable_waf_fail_open                                         = load_balancer.enable_waf_fail_open
        enable_xff_client_port                                       = load_balancer.enable_xff_client_port
        enable_zonal_shift                                           = load_balancer.enable_zonal_shift
        enforce_security_group_inbound_rules_on_private_link_traffic = load_balancer.enforce_security_group_inbound_rules_on_private_link_traffic
        health_check_logs                                            = load_balancer.health_check_logs
        idle_timeout                                                 = load_balancer.idle_timeout
        internal                                                     = load_balancer.internal
        ip_address_type                                              = load_balancer.ip_address_type
        ipam_pools                                                   = load_balancer.ipam_pools
        load_balancer_type                                           = load_balancer.load_balancer_type
        minimum_load_balancer_capacity                               = load_balancer.minimum_load_balancer_capacity
        name                                                         = load_balancer.name
        name_prefix                                                  = load_balancer.name_prefix
        preserve_host_header                                         = load_balancer.preserve_host_header
        secondary_ips_auto_assigned_per_subnet                       = load_balancer.secondary_ips_auto_assigned_per_subnet
        security_groups                                              = load_balancer.security_groups
        subnet_mapping                                               = load_balancer.subnet_mapping
        subnets                                                      = length(load_balancer.subnets) > 0 ? load_balancer.subnets : null
        timeouts                                                     = load_balancer.timeouts
        xff_header_processing_mode                                   = load_balancer.xff_header_processing_mode

        tags = merge(
          load_balancer.tags,
          {
            Name        = coalesce(load_balancer.name, load_balancer.name_prefix, load_balancer.resource_key)
            Environment = var.environment
            Terraform   = "True"
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    }
  }

  lb_target_groups = {
    for region in var.aws_config.regions : region => merge([
      for load_balancer in var.all_load_balancers : {
        for target_group in load_balancer.target_groups :
        "${load_balancer.resource_key}/${target_group.resource_key}" => {

          lb_key                            = load_balancer.resource_key
          tg_key                            = target_group.resource_key
          function                          = target_group.function
          vpc_id                            = target_group.vpc_id
          port                              = target_group.port
          protocol                          = target_group.protocol
          protocol_version                  = target_group.protocol_version
          target_type                       = target_group.target_type
          deregistration_delay              = target_group.deregistration_delay
          slow_start                        = target_group.slow_start
          load_balancing_algorithm_type     = target_group.load_balancing_algorithm_type
          load_balancing_anomaly_mitigation = target_group.load_balancing_anomaly_mitigation
          load_balancing_cross_zone_enabled = target_group.load_balancing_cross_zone_enabled
          preserve_client_ip                = target_group.preserve_client_ip
          proxy_protocol_v2                 = target_group.proxy_protocol_v2
          connection_termination            = target_group.connection_termination
          ip_address_type                   = target_group.ip_address_type
          health_check                      = target_group.health_check
          stickiness                        = target_group.stickiness

          tags = merge(
            target_group.tags,
            {
              Name        = "${load_balancer.resource_key}/${target_group.resource_key}"
              Environment = var.environment
              Terraform   = "True"
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ]...)
  }

  lb_target_group_attachments = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in var.all_load_balancers : [
        for target_group in load_balancer.target_groups : {
          for system in var.all_systems :
          "${load_balancer.resource_key}/${target_group.resource_key}/${system.hostname}" => {
            tg_key   = "${load_balancer.resource_key}/${target_group.resource_key}"
            hostname = system.hostname
            port     = target_group.port
          }
          if replace(system.region, "-", "_") == region && system.tags.Function == target_group.function
        }
      ]
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ])...)
  }

  lb_listeners = {
    for region in var.aws_config.regions : region => merge([
      for load_balancer in var.all_load_balancers : {
        for listener in load_balancer.listeners :
        "${load_balancer.resource_key}/${listener.resource_key}" => {

          lb_key          = load_balancer.resource_key
          listener_key    = listener.resource_key
          port            = listener.port
          protocol        = listener.protocol
          ssl_policy      = listener.ssl_policy
          alpn_policy     = listener.alpn_policy
          certificate_arn = listener.certificate_arn

          default_action = {
            type             = listener.default_action.type
            target_group_key = listener.default_action.target_group_key == null ? null : "${load_balancer.resource_key}/${listener.default_action.target_group_key}"
            redirect         = listener.default_action.redirect
            fixed_response   = listener.default_action.fixed_response
          }
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ]...)
  }

  lb_listener_rules = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : {
          for rule in listener.rules :
          "${load_balancer.resource_key}/${listener.resource_key}/${rule.resource_key}" => {

            listener_key = "${load_balancer.resource_key}/${listener.resource_key}"
            priority     = rule.priority

            action = {
              type             = rule.action.type
              target_group_key = rule.action.target_group_key == null ? null : "${load_balancer.resource_key}/${rule.action.target_group_key}"
              redirect         = rule.action.redirect
              fixed_response   = rule.action.fixed_response
            }

            conditions = rule.conditions
          }
        }
      ]
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ])...)
  }

  lb_listener_certificates = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in var.all_load_balancers : [
        for listener in load_balancer.listeners : {
          for certificate_arn in listener.additional_certificate_arns :
          "${load_balancer.resource_key}/${listener.resource_key}/${certificate_arn}" => {

            listener_key    = "${load_balancer.resource_key}/${listener.resource_key}"
            certificate_arn = certificate_arn
          }
        }
      ]
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(load_balancer.region, "-", "_") == region
    ])...)
  }


  relational_database_service = {
    for region in var.aws_config.regions : region => nonsensitive({
      for database in var.all_databases : nonsensitive(database.db_name) => {

        allocated_storage           = nonsensitive(database.allocated_storage)
        availability_zone           = nonsensitive(database.availability_zone)
        backup_retention_period     = nonsensitive(database.backup_retention_period)
        backup_window               = nonsensitive(database.backup_window)
        blue_green_update           = nonsensitive(database.blue_green_update)
        ca_cert_identifier          = nonsensitive(database.ca_cert_identifier)
        db_name                     = nonsensitive(database.db_name)
        db_subnet_group_name        = nonsensitive(database.db_subnet_group_name)
        dedicated_log_volume        = nonsensitive(database.dedicated_log_volume)
        delete_automated_backups    = nonsensitive(database.delete_automated_backups)
        deletion_protection         = nonsensitive(database.deletion_protection)
        engine                      = nonsensitive(database.engine)
        engine_version              = nonsensitive(database.engine_version)
        final_snapshot_identifier   = "${nonsensitive(database.db_name)}-FINAL"
        identifier                  = lower(nonsensitive(database.db_name))
        instance_class              = nonsensitive(database.instance_class)
        kms_key_id                  = nonsensitive(database.aws_kms_alias)
        manage_master_user_password = nonsensitive(database.manage_master_user_password)
        max_allocated_storage       = nonsensitive(database.max_allocated_storage)
        #region                     = < This is set statically >
        skip_final_snapshot    = nonsensitive(database.skip_final_snapshot)
        storage_encrypted      = true
        storage_type           = nonsensitive(database.storage_type)
        vpc_security_group_ids = nonsensitive(database.vpc_security_group_ids)

        tags = merge(
          nonsensitive(database.tags),
          # Normalized Overwritable Tags
          {
            Backup = nonsensitive(database.tags["Backup"]) ? "True" : "False"
          },
          # Non-Overwritable Default Tags
          {
            Name        = nonsensitive(database.db_name)
            Environment = var.environment
            Terraform   = "True"
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(nonsensitive(database.region), "-", "_") == region
    })
  }

  relational_database_service_credentials = {
    for region in var.aws_config.regions : region => {
      for database in var.all_databases : nonsensitive(database.db_name) => {
        password = database.password == null ? null : sensitive(database.password)
        username = sensitive(database.username)
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(nonsensitive(database.region), "-", "_") == region
    }
  }

}
