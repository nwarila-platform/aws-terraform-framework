# The brain of the plan: every object consumed by resources.tf is shaped here from
# variables, data lookups, and managed-capability resources.

# Statically Configured LOCALS
locals {

  #region ------ [ Amazon Machine Image Resolution ] ------------------------------------------- #

  # Images are addressed, never discovered. A selector is either the literal-id escape hatch
  # (ami-<hex>) or a catalog address: a bare family floats on every publish, and each "@"-suffixed
  # segment pins one level further until an atomic build date freezes it exactly. The grammar is
  # enforced on var.all_systems, so everything below may assume a well-formed lowercase selector.
  #
  # Deduplicated to the distinct selectors actually in play: twenty systems sharing one image cost
  # one parameter read and one image lookup, not twenty of each.
  ami_selectors = toset([for system in var.all_systems : system.ami])

  # A literal id bypasses the catalog; every other selector resolves through it.
  catalog_selectors = toset([for ami in local.ami_selectors : ami if !startswith(ami, "ami-")])

  # Accounts a literal ami- id may belong to. "self" is the deploying account (793496711039),
  # which publishes the catalog; the other two are vendor accounts whose base images are pinned
  # directly because the catalog does not republish them:
  #
  #   679593333241  CIS hardened images from the AWS Marketplace
  #   801119661308  Amazon-published Windows Server images
  #
  # TEMPORARY: hardcoded until those images are mirrored into the catalog, at which point they
  # become ordinary selectors and this list collapses back to ["self"]. It applies ONLY to
  # literal ids - a catalog selector is always held to the deploying account, so widening this
  # cannot loosen what a named selector resolves to.
  direct_ami_owners = ["self", "679593333241", "801119661308"]

  # Selector to exact SSM key: "@" becomes a path separator, and a bare family addresses the
  # floating "latest" pointer. This is a pure string transformation - no name filter, no
  # most_recent, no discovery of any kind. An address that was never published fails the plan
  # instead of silently resolving to the closest thing available.
  ami_parameter_name = {
    for ami in local.catalog_selectors : ami =>
    "/nwarila/ami/${strcontains(ami, "@") ? replace(ami, "@", "/") : "${ami}/latest"}"
  }

  # One verified image object per selector, keyed the way the rest of the plan already keys
  # images. Consumers read .id, .platform, .platform_details, .root_device_name and
  # .block_device_mappings from here and never learn whether the id was pinned or resolved.
  amazon_machine_images = {
    for ami in local.ami_selectors : ami => {
      us_east_1 = try(data.aws_ami.us_east_1_verified[ami], null)
    }
  }

  #endregion --- [ Amazon Machine Image Resolution ] ------------------------------------------- #


  #region ------ [ Deployment Identity Tags ] -------------------------------------------------- #

  # The identity keys whose value is identical on every resource, applied as provider
  # default_tags in providers.tf.
  #
  # That placement is load-bearing, not stylistic. default_tags is the only mechanism that puts
  # tags inside the create API call itself: RunInstances carries them in its TagSpecifications,
  # so the volumes it creates are tagged as they are born and a launch policy conditioning on
  # aws:RequestTag matches. Tags written in a resource's own tags block are applied by a separate
  # CreateTags call after the resource exists - too late for that condition, which sees a request
  # carrying no aws:RequestTag key at all and cannot match.
  #
  # This does not replace the per-resource tag maps. Those carry the keys whose value varies by
  # resource - Name, Index, DeviceName, OS, Backup, Function - which one static provider map
  # cannot express. RunInstances applies a single tag set to every volume in the request, so
  # per-device values could not live there even in principle. The two are complementary: this
  # covers the request, the explicit maps cover per-device values and state visibility.
  identity_tags = {
    CommitSha    = var.commit_sha
    Environment  = var.environment
    ManagedBy    = "Terraform"
    Repository   = var.repository
    RepositoryId = var.repository_id
    RunId        = var.run_id
  }

  #endregion --- [ Deployment Identity Tags ] -------------------------------------------------- #


  #region ------ [ Connection Transport ] ------------------------------------------------------ #

  # connection_type carries two facts in one field: the protocol on the wire, and whether the
  # system is reached directly or through an SSM tunnel. SSM is a channel, not a protocol - a
  # tunnelled system still runs sshd or a WinRM listener - so the protocol half keeps driving
  # user_data, get_password_data and the Windows-only check. Null means "ssh".
  connection_protocol = {
    for system in var.all_systems : system.hostname =>
    contains(["winrm", "winrm-ssm"], coalesce(system.connection_type, "ssh")) ? "winrm" : "ssh"
  }

  # Nothing reaches a tunnelled system inbound, so it is given no runner ingress group and cannot
  # run the readiness gate (var.all_systems requires readiness_gate = false for these).
  connection_over_ssm = {
    for system in var.all_systems : system.hostname =>
    contains(["ssh-ssm", "winrm-ssm"], coalesce(system.connection_type, "ssh"))
  }

  #endregion --- [ Connection Transport ] ------------------------------------------------------ #


  #region ------ [ SSH Bootstrap User Data ] --------------------------------------------------- #

  # user_data covers three things: making sure sshd is actually running, installing the launch
  # key, and making sure the SSM agent is running on Linux. Installing OpenSSH and cloud-init is
  # still the AMI's job. Every step below is idempotent, so an image that already has them
  # enabled pays nothing.
  #
  # The SSM step is here because "in-house images ship the agent" is not yet true of anything
  # this framework launches: the catalog is unpopulated, so every image in play is a vendor one
  # reached through the literal ami- escape hatch. Amazon's Windows images register on their own;
  # CIS RHEL ships the agent without enabling it, so an instance launches healthy and never
  # becomes manageable. TEMPORARY on the same terms as that escape hatch - it goes when images
  # are mirrored into the catalog and the in-house assumption starts holding.
  #
  # The enable-and-start guard stays because "installed but not enabled" is the plausible failure
  # mode on a hardened or third-party image, and it strands the box with no way in. On Windows,
  # Start-Service runs LAST, after the key is on disk: starting the listener first would accept
  # connections it cannot yet authenticate. Set-Service is only registry config, so it stays up
  # top with the rest of the configuration.
  #
  # Windows also opens the port, mirroring what the WinRM path does for 5986. A hardened image
  # may ship OpenSSH with its inbound rule absent or disabled, and the host firewall then refuses
  # the connection whether or not sshd is listening - the readiness gate times out against a
  # machine that is running perfectly. The rule sits with the other configuration, before
  # Start-Service: opening a port nothing is listening on yet is inert.
  #
  # Windows additionally needs the key install: EC2Launch populates the Administrator password
  # path, not administrators_authorized_keys. The OpenSSH default shell is deliberately left as
  # cmd; setting it to PowerShell breaks the remote-exec SCP upload the readiness gate uses.
  # Linux needs no key step at all - cloud-init installs the launch key into the login user's
  # authorized_keys by itself.
  windows_ssh_user_data = <<-WINDOWS_USER_DATA
    <powershell>
    $ErrorActionPreference = "Stop"

    Set-Service -Name sshd -StartupType Automatic
    New-NetFirewallRule -DisplayName "OpenSSH SSH Server" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow

    $token = Invoke-RestMethod -Method PUT -Uri http://169.254.169.254/latest/api/token -Headers @{ "X-aws-ec2-metadata-token-ttl-seconds" = "21600" }
    $publicKey = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key -Headers @{ "X-aws-ec2-metadata-token" = $token }
    $authorizedKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
    Set-Content -Path $authorizedKeys -Value $publicKey -Encoding ascii
    icacls $authorizedKeys /inheritance:r /grant "Administrators:F" "SYSTEM:F"

    Start-Service -Name sshd
    </powershell>
  WINDOWS_USER_DATA

  # WinRM is the transport for Windows images that cannot install the OpenSSH Feature-on-Demand:
  # WS-Management is in-box, so it works with no Windows Update egress and no local source, which
  # is exactly where the SSH path fails. Selected per system by connection_type = "winrm".
  #
  # HTTPS/5986 only, never HTTP/5985. Terraform's WinRM client does NTLM authentication but no
  # WinRM message sealing, so AllowUnencrypted = false rejects unencrypted SOAP with a 401; TLS
  # supplies the encryption instead. The listener therefore binds a certificate generated in-box,
  # the default HTTP listener is removed, and the stock WinRM firewall group is disabled, leaving
  # 5986 as the only exposed port.
  windows_winrm_user_data = <<-WINDOWS_WINRM_USER_DATA
    <powershell>
    $ErrorActionPreference = "Stop"

    $certificate = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My

    Get-ChildItem -Path WSMan:\localhost\Listener | Where-Object { $_.Keys -contains "Transport=HTTP" } | Remove-Item -Recurse -Force
    New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $certificate.Thumbprint -Force

    Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
    Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false
    Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $true

    Disable-NetFirewallRule -DisplayGroup "Windows Remote Management"
    New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

    Set-Service -Name WinRM -StartupType Automatic
    Restart-Service -Name WinRM
    </powershell>
  WINDOWS_WINRM_USER_DATA

  # sshd.service on RHEL-family images, ssh.service on Debian-family ones.
  # __AWS_REGION__ is substituted with the hyphenated region where user_data is rendered, so the
  # agent is fetched from the S3 bucket in the region it is booting into rather than across one.
  #
  # Enable first, download second: the common case on a hardened image is an agent that is
  # installed but not enabled, and that path needs no network at all. The install only runs when
  # enabling failed, and it needs egress at boot - on an image with no route to S3 it fails, and
  # the failure lands in the console log and in cloud-init's status rather than leaving a host
  # that looks healthy and is unreachable.
  linux_ssh_user_data = <<-LINUX_USER_DATA
    #cloud-config
    runcmd:
      - systemctl enable --now sshd || systemctl enable --now ssh
      - systemctl enable --now amazon-ssm-agent 2>/dev/null || curl -sSL -o /root/amazon-ssm-agent.rpm https://s3.__AWS_REGION__.amazonaws.com/amazon-ssm-__AWS_REGION__/latest/linux_amd64/amazon-ssm-agent.rpm
      - test -f /root/amazon-ssm-agent.rpm && rpm -Uvh --replacepkgs /root/amazon-ssm-agent.rpm && systemctl enable --now amazon-ssm-agent
  LINUX_USER_DATA

  #endregion --- [ SSH Bootstrap User Data ] --------------------------------------------------- #


  #region ------ [ Readiness Gate Wait Commands ] ---------------------------------------------- #

  # Readiness-gate wait commands (selected per-OS in terraform_data.readiness_gate), both executed
  # over SSH. Each blocks until the OS launch/provisioning agent reports completion after
  # Terraform has first connected.
  windows_readiness_command = "\"C:\\Program Files\\Amazon\\EC2Launch\\EC2Launch.exe\" status -b"
  linux_readiness_command   = "cloud-init status --wait"

  # Default upload directory for the Linux remote-exec script. The login user's home is
  # the usual escape hatch on images that mount /tmp noexec.
  linux_readiness_script_dir = "/home/ec2-user"

  #endregion --- [ Readiness Gate Wait Commands ] ---------------------------------------------- #
}


# Dynamically Configured LOCALS
locals {

  #region ------ [ EC2 Key Pairs ] ------------------------------------------------------------- #

  # Every referenced key pair is pre-existing: this framework consumes key pairs, it never
  # creates them, so the data lookup is the only source.
  key_pair_names = {
    us_east_1 = { for name, keypair in data.aws_key_pair.us_east_1 : name => keypair.key_name }
  }

  #endregion --- [ EC2 Key Pairs ] ------------------------------------------------------------- #


  #region ------ [ Interface-Owned Security Groups ] ------------------------------------------- #

  # Each interface with non-null rule collections declares one group at its raw interface index.
  # Its "<hostname>-eni-<index>-sg" name pairs it visibly with the corresponding ENI. The region
  # and VPC come from the parent system because every interface already uses that system's subnet.
  # Description and tags come from the interface itself; a null description uses a stable
  # framework string.
  network_interface_security_groups = merge(concat([{}], [
    for system in var.all_systems : {
      for interface_index, network_interface in system.network_interfaces :
      "${system.hostname}-eni-${interface_index}-sg" => {
        region      = replace(system.region, "-", "_")
        vpc_id      = data.aws_subnet.us_east_1[system.subnet_id].vpc_id
        description = network_interface.description != null ? network_interface.description : "Managed by aws-terraform-framework."
        ingress     = network_interface.ingress
        egress      = network_interface.egress

        tags = merge(
          network_interface.tags,
          # Non-Overwritable Default Tags
          local.identity_tags,
          {
            Name = "${system.hostname}-eni-${interface_index}-sg"
          }
        )
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

  # Tag each interface-owned rule with its direction and its single source/destination before
  # normalizing. This framework is IPv4-only, so that source is exactly one of cidr_ipv4,
  # prefix_list_id, or referenced_security_group_id.
  network_interface_security_group_rule_targets = {
    for region in var.aws_config.regions : region => flatten([
      for name, group in local.network_interface_security_groups_by_region[region] : [
        for tagged in concat(
          [for rule in group.ingress : { direction = "ingress", rule = rule }],
          [for rule in group.egress : { direction = "egress", rule = rule }],
          ) : {
          direction = tagged.direction
          rule      = tagged.rule
          sg_key    = name
          target = (
            tagged.rule.cidr_ipv4 != null
            ? { kind = "cidr_ipv4", value = tagged.rule.cidr_ipv4 }
            : tagged.rule.prefix_list_id != null
            ? { kind = "prefix_list_id", value = tagged.rule.prefix_list_id }
            : { kind = "referenced_security_group_id", value = tagged.rule.referenced_security_group_id }
          )
        }
      ]
    ])
  }

  # Normalize every interface-owned rule into its AWS identity. Description is deliberately
  # absent: AWS duplicate detection and resource replacement are determined by direction,
  # protocol, ports, and destination. Field values in the readable prefix are lowercased,
  # sanitized to alphanumerics and hyphens, and bounded; the digest preserves the full normalized
  # identity when sanitization or truncation makes two readable prefixes alike. The readable
  # target kind is the identity kind with underscores swapped for hyphens, so the two can never
  # drift apart.
  network_interface_security_group_rule_entries = {
    for region in var.aws_config.regions : region => [
      for entry in local.network_interface_security_group_rule_targets[region] : {
        direction = entry.direction
        identity = jsonencode([
          entry.direction,
          lower(entry.rule.ip_protocol),
          entry.rule.from_port,
          entry.rule.to_port,
          entry.target.kind,
          lower(entry.target.value),
        ])
        readable_identity = join("-", [
          entry.direction,
          "protocol",
          substr(replace(lower(entry.rule.ip_protocol), "/[^0-9a-z]+/", "-"), 0, 32),
          "ports",
          entry.rule.from_port == null ? "none" : tostring(entry.rule.from_port),
          entry.rule.to_port == null ? "none" : tostring(entry.rule.to_port),
          replace(entry.target.kind, "_", "-"),
          substr(replace(lower(entry.target.value), "/[^0-9a-z]+/", "-"), 0, 64),
        ])
        rule   = entry.rule
        sg_key = entry.sg_key
      }
    ]
  }

  # Stable rule address:
  # "<sg>/<direction>-protocol-<protocol>-ports-<from>-<to>-<destination
  # kind>-<destination>-<digest>". An exact identity collision raises Terraform's
  # duplicate-object-key error at plan time rather than silently losing a rule.
  network_interface_security_group_rules = {
    for region in var.aws_config.regions : region => {
      for entry in local.network_interface_security_group_rule_entries[region] :
      "${entry.sg_key}/${entry.readable_identity}-${substr(sha256(entry.identity), 0, 12)}" => merge(
        entry.rule,
        {
          direction = entry.direction
          sg_key    = entry.sg_key

          # A rule declares no consumer tags, so this map is wholly framework-owned.
          tags = merge(local.identity_tags, {
            Name = "${substr("${entry.sg_key}/${entry.readable_identity}", 0, 243)}-${substr(sha256(entry.identity), 0, 12)}"
          })
        },
      )
    }
  }

  # Name -> interface-owned SG id, used to attach each group only to its declaring interface.
  network_interface_security_group_ids = {
    us_east_1 = { for name, group in aws_security_group.us_east_1 : name => group.id }
  }

  # aws_vpc_security_group_ingress_rule and _egress_rule are separate resources, so the
  # direction split belongs here rather than in a for_each filter.
  network_interface_security_group_ingress_rules = {
    for region in var.aws_config.regions : region => {
      for key, rule in local.network_interface_security_group_rules[region] : key => rule
      if rule.direction == "ingress"
    }
  }

  network_interface_security_group_egress_rules = {
    for region in var.aws_config.regions : region => {
      for key, rule in local.network_interface_security_group_rules[region] : key => rule
      if rule.direction == "egress"
    }
  }

  #endregion --- [ Interface-Owned Security Groups ] ------------------------------------------- #


  #region ------ [ Runner Ingress Security Group ] --------------------------------------------- #

  # One group, attached to every interface the framework builds, so a CI runner can reach the
  # fleet for the life of a single run. var.runner_ip == null collapses every map below to {},
  # so the resources plan to nothing and no ENI gains a group.
  #
  # The name has to be unique per VPC: several repositories deploy into one shared subnet and
  # all of them use environment = "dev", so environment alone would collide. repository_id is
  # numeric, rename-stable, and required, which makes it the stable half of the identity.
  runner_ingress_name = "runner-ingress-${var.repository_id}-${var.environment}"

  # tcp/22 carries SSH-direct, tcp/5986 carries WinRM-direct, and ICMP carries reachability
  # checks. Module-owned literals rather than a consumer list: a list invites 0-65535, and these
  # are exactly the transports this exists to serve.
  #
  # ICMP has no ports - the rule encodes type and code in from_port/to_port, and -1/-1 means
  # every type and code. That is scoped to one /32 here, so it grants ping and the PMTUD and
  # unreachable messages that make a failed connection diagnosable rather than a silent hang.
  runner_ingress_rules = {
    ssh = {
      description = "Run-scoped SSH ingress."
      ip_protocol = "tcp"
      from_port   = 22
      to_port     = 22
    }
    winrm = {
      description = "Run-scoped WinRM ingress."
      ip_protocol = "tcp"
      from_port   = 5986
      to_port     = 5986
    }
    icmp = {
      description = "Run-scoped ICMP ingress for reachability checks."
      ip_protocol = "icmp"
      from_port   = -1
      to_port     = -1
    }
  }

  # What a HUMAN needs to sit on the host: the three above plus tcp/3389, because a Windows
  # desktop is the one thing CI never wants and a person debugging one cannot do without. Also
  # module-owned literals, for the same reason -- an operator input here would be a port list,
  # and a port list invites 0-65535.
  debug_ingress_rules = merge(local.runner_ingress_rules, {
    rdp = {
      description = "Run-scoped RDP ingress."
      ip_protocol = "tcp"
      from_port   = 3389
      to_port     = 3389
    }
  })

  # One grant per transport per address, keyed by both so that an address given as BOTH the
  # runner and the operator collapses to a single rule instead of colliding: AWS would reject the
  # duplicate, and the two would be asking for the identical opening anyway. The operator is
  # merged last, so a shared address keeps the wider transport set.
  runner_ingress_grants = merge(
    var.runner_ip == null ? {} : {
      for transport, rule in local.runner_ingress_rules :
      "${transport}-${var.runner_ip}" => {
        address = var.runner_ip
        origin  = "CI runner"
        rule    = rule
      }
    },
    var.debug_ip == null ? {} : {
      for transport, rule in local.debug_ingress_rules :
      "${transport}-${var.debug_ip}" => {
        address = var.debug_ip
        origin  = "operator"
        rule    = rule
      }
    }
  )

  # Every distinct VPC the fleet resolves to. One security group cannot span VPCs, so a length
  # other than 1 is a hard error, raised by a precondition on the group itself.
  #
  # Counts only systems that will actually receive the group, so a region reached entirely over
  # SSM contributes no VPC and builds no group rather than an orphan attached to nothing.
  runner_ingress_vpc_ids = {
    for region in var.aws_config.regions : region => distinct([
      for system in var.all_systems :
      data.aws_subnet.us_east_1[system.subnet_id].vpc_id
      if replace(system.region, "-", "_") == region &&
      !local.connection_over_ssm[system.hostname]
    ])
  }

  # Empty when nothing grants access, and also when a region declares no systems: with nothing
  # to attach to there is no group to build, and indexing an empty VPC list would fail.
  runner_ingress_security_groups = {
    for region in var.aws_config.regions : region => (
      length(local.runner_ingress_grants) == 0 || length(local.runner_ingress_vpc_ids[region]) == 0 ? {} : {
        (local.runner_ingress_name) = {

          # AWS Security Group Properties
          description = "Run-scoped CI runner ingress. Managed by aws-terraform-framework."
          name        = local.runner_ingress_name
          # [0] rather than one(): one() is absent from Packer and unused here by style. A list
          # longer than 1 is caught by the single-VPC precondition on the group resource.
          vpc_id = local.runner_ingress_vpc_ids[region][0]

          # The group declares no consumer tags, so this map is wholly framework-owned.
          tags = merge(local.identity_tags, {
            Name = local.runner_ingress_name
          })
        }
      }
    )
  }

  runner_ingress_security_group_rules = {
    for region in var.aws_config.regions : region => (
      length(local.runner_ingress_grants) == 0 || length(local.runner_ingress_vpc_ids[region]) == 0 ? {} : {
        for key, grant in local.runner_ingress_grants :
        "${local.runner_ingress_name}-${key}" => {

          # AWS Security Group Ingress Rule Properties
          cidr_ipv4                    = "${grant.address}/32"
          description                  = "${grant.rule.description} (${grant.origin})"
          from_port                    = grant.rule.from_port
          ip_protocol                  = grant.rule.ip_protocol
          prefix_list_id               = null
          referenced_security_group_id = null
          sg_key                       = local.runner_ingress_name
          to_port                      = grant.rule.to_port

          # A rule declares no consumer tags, so this map is wholly framework-owned.
          tags = local.identity_tags
        }
      }
    )
  }

  # Name -> runner-ingress SG id, mirroring network_interface_security_group_ids.
  runner_ingress_security_group_ids = {
    us_east_1 = { for name, group in aws_security_group.runner_ingress_us_east_1 : name => group.id }
  }

  #endregion --- [ Runner Ingress Security Group ] --------------------------------------------- #


  #region ------ [ Elastic IPs ] --------------------------------------------------------------- #

  # Systems that requested a stable public IPv4: an EIP is allocated and associated with the
  # primary ENI.
  eip_systems = {
    for region in var.aws_config.regions : region => {
      for system in var.all_systems : system.hostname => {

        # An Elastic IP declares no consumer tags, so this map is wholly framework-owned.
        tags = merge(local.identity_tags, {
          Name = system.hostname
        })
      }
      if replace(system.region, "-", "_") == region && system.associate_public_ip
    }
  }

  #endregion --- [ Elastic IPs ] --------------------------------------------------------------- #


  #region ------ [ Elastic Compute Cloud (EC2s) ] ---------------------------------------------- #

  elastic_compute_cloud = {
    for region in var.aws_config.regions : region => {
      for system in var.all_systems : system.hostname => {

        ami                        = system.ami
        availability_zone          = system.availability_zone
        hostname                   = system.hostname
        iam_instance_profile       = system.iam_instance_profile
        imds_hop_limit             = system.imds_hop_limit
        instance_type              = system.instance_type
        is_windows                 = local.amazon_machine_images[system.ami][region].platform == "windows"
        key_name                   = system.key_name
        readiness_command          = system.readiness_command
        readiness_gate             = system.readiness_gate
        readiness_private_key_path = system.readiness_private_key_path
        readiness_script_dir       = system.readiness_script_dir
        readiness_user             = system.readiness_user
        refresh                    = system.refresh
        region                     = region
        set_state                  = system.set_state
        # Null selects SSH, the default transport. WinRM is only meaningful on Windows; a Linux
        # system asking for it is rejected by a precondition on the instance, because the OS is
        # data-resolved and a variable validation cannot see it.
        connection_type     = coalesce(system.connection_type, "ssh")
        connection_protocol = local.connection_protocol[system.hostname]
        connection_over_ssm = local.connection_over_ssm[system.hostname]

        # WinRM authenticates as Administrator with the launch password, so the encrypted blob has
        # to be fetched. Only for WinRM: it costs apply latency while the provider waits for the
        # password to become available, and the SSH path has no use for it. Tunnelling over SSM
        # does not change how the far end authenticates, so this keys off the protocol.
        get_password_data = (
          local.amazon_machine_images[system.ami][region].platform == "windows" &&
          local.connection_protocol[system.hostname] == "winrm"
        )

        # The protocol half selects the bootstrap: an SSM-reached system still needs something
        # listening for the tunnel to carry, so it renders the same user_data as a direct one.
        #
        # The SSM agent step inside that user_data is deliberately not gated on connection_type
        # at all. That field says how the framework's own readiness gate connects, not whether
        # the consumer will administer the host over SSM afterwards - an "ssh" system reached
        # through SSM by its configuration management is the normal case, so every Linux image
        # gets the agent.
        user_data = trimspace(
          local.amazon_machine_images[system.ami][region].platform == "windows"
          ? (
            local.connection_protocol[system.hostname] == "winrm"
            ? local.windows_winrm_user_data
            : local.windows_ssh_user_data
          )
          : replace(local.linux_ssh_user_data, "__AWS_REGION__", replace(region, "_", "-"))
        )

        root_block_device = {
          delete_on_termination = system.root_block_device.delete_on_termination
          iops                  = system.root_block_device.iops
          kms_key_id            = system.aws_kms_alias
          throughput            = system.root_block_device.throughput
          volume_size           = system.root_block_device.volume_size
          volume_type           = system.root_block_device.volume_type

          tags = merge(
            system.root_block_device.tags,
            # Non-Overwritable Default Tags
            local.identity_tags,
            {
              Index = 0
              Name  = system.hostname
            }
          )
        }

        ami_block_device_overrides = [
          for override in system.ami_block_device_overrides : {
            delete_on_termination = override.delete_on_termination
            device_name           = override.device_name
            iops                  = override.iops
            kms_key_id            = system.aws_kms_alias
            # Identity on the volume itself. default_tags puts it in the launch request, but only
            # a tag on the resource survives into state where an ec2:ResourceTag-scoped grant for
            # DeleteVolume, DetachVolume or ModifyVolume can be written against it - and where a
            # reaper can still find the volume after a failed run.
            tags = merge(local.identity_tags, {
              DeviceName = override.device_name
              Name       = system.hostname
            })
            throughput  = override.throughput
            volume_size = override.volume_size
            volume_type = override.volume_type
          }
        ]

        # Non-root EBS mappings the AMI itself declares that no override covers. RunInstances
        # creates each one with the source snapshot's own encryption state, so an uncovered
        # mapping silently lands outside the module's encryption invariant - the CIS RHEL 8 STIG
        # /dev/sdf case in docs/reference/invariants.md. The instance precondition rejects a
        # non-empty list. This cannot live in a variable validation: block_device_mappings is a
        # data lookup, and validations run before data is read.
        # Skipped: instance-store mappings (virtual_name, no EBS volume to encrypt) and
        # suppression entries (no_device, which removes the mapping instead of creating it).
        uncovered_ami_block_devices = sort([
          for mapping in try(local.amazon_machine_images[system.ami][region].block_device_mappings, []) :
          mapping.device_name
          if length(try(mapping.ebs, {})) > 0 &&
          try(mapping.no_device, "") == "" &&
          try(mapping.virtual_name, "") == "" &&
          mapping.device_name != try(local.amazon_machine_images[system.ami][region].root_device_name, "") &&
          !contains([for override in system.ami_block_device_overrides : override.device_name], mapping.device_name)
        ])

        tags = merge(
          system.tags,
          # Normalized Overwritable Tags
          {
            Backup = lower(system.tags["Backup"]) == "true" ? "True" : "False"
          },
          # Non-Overwritable Default Tags
          local.identity_tags,
          {
            Name = system.hostname
            OS   = local.amazon_machine_images[system.ami][region].platform_details
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region
    }
  }

  # The ONLY place the physical instance resources are enumerated. Two resources exist because
  # `lifecycle` is a static meta-argument (base/refresh); HCL cannot iterate resource addresses,
  # so they are merged here once. Hostnames are validated-unique and each system lives in exactly
  # one region, so this merge is a disjoint union.
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
    for region in var.aws_config.regions : region => {
      for hostname, instance in local.all_ec2_instances : hostname => {
        id         = instance.id
        private_ip = instance.private_ip
        # Everything the gate needs is decided here: the connection mechanics and both
        # OS-specific fallbacks, so the resource reads fields and makes no choices.
        readiness_user = coalesce(
          local.systems_by_hostname[hostname].readiness_user,
          local.systems_by_hostname[hostname].is_windows ? "Administrator" : "ec2-user",
        )
        readiness_command = coalesce(
          local.systems_by_hostname[hostname].readiness_command,
          local.systems_by_hostname[hostname].is_windows
          ? local.windows_readiness_command
          : local.linux_readiness_command,
        )
        target_platform = local.systems_by_hostname[hostname].is_windows ? "windows" : "unix"
        script_path = (
          local.systems_by_hostname[hostname].is_windows
          ? null
          : format("%s/terraform_%%RAND%%.sh", coalesce(
            local.systems_by_hostname[hostname].readiness_script_dir,
            local.linux_readiness_script_dir,
          ))
        )
        private_key_path = local.systems_by_hostname[hostname].readiness_private_key_path

        # WinRM reaches 5986 over TLS with a certificate the instance generated for itself, so the
        # client cannot verify it and insecure has to be true. NTLM carries the authentication.
        connection_type     = local.systems_by_hostname[hostname].connection_type
        connection_protocol = local.systems_by_hostname[hostname].connection_protocol
        use_winrm           = local.systems_by_hostname[hostname].connection_protocol == "winrm"
        winrm_port          = 5986

        # Decrypted in flight from the encrypted blob AWS returns, with the launch private key the
        # gate already requires. Only the ciphertext ever reaches state.
        password = (
          local.systems_by_hostname[hostname].connection_protocol == "winrm" &&
          local.systems_by_hostname[hostname].readiness_private_key_path != null
          ? rsadecrypt(instance.password_data, file(local.systems_by_hostname[hostname].readiness_private_key_path))
          : null
        )
      }
      if local.systems_by_hostname[hostname].readiness_gate &&
      local.systems_by_hostname[hostname].region == region
    }
  }

  # refresh = true instances live in their own resource so refresh_serial can replace the
  # fleet without touching everything else. That split is a property of the data, not of
  # the resource block, so it is made here.
  elastic_compute_cloud_stable = {
    for region in var.aws_config.regions : region => {
      for hostname, system in local.elastic_compute_cloud[region] : hostname => system
      if system.refresh == false
    }
  }

  elastic_compute_cloud_refresh = {
    for region in var.aws_config.regions : region => {
      for hostname, system in local.elastic_compute_cloud[region] : hostname => system
      if system.refresh == true
    }
  }

  # Secondary interfaces follow their instance's refresh setting. Their existing ENI keys become
  # the attachment resource keys, preserving each interface's identity and device index.
  network_interface_attachments_stable = {
    for region in var.aws_config.regions : region => {
      for key, network_interface in local.elastic_network_interfaces[region] :
      key => network_interface
      if network_interface.index > 0 &&
      local.elastic_compute_cloud[region][network_interface.hostname].refresh == false
    }
  }

  network_interface_attachments_refresh = {
    for region in var.aws_config.regions : region => {
      for key, network_interface in local.elastic_network_interfaces[region] :
      key => network_interface
      if network_interface.index > 0 &&
      local.elastic_compute_cloud[region][network_interface.hostname].refresh == true
    }
  }

  # Only systems that explicitly asked for a power state get an aws_ec2_instance_state.
  ec2_instance_states = {
    for region in var.aws_config.regions : region => {
      for hostname, instance in local.all_ec2_instances : hostname => {
        instance_id = instance.id
        state       = local.elastic_compute_cloud[region][hostname].set_state
      }
      if local.elastic_compute_cloud[region][hostname].set_state != null
    }
  }

  #endregion --- [ Elastic Compute Cloud (EC2s) ] ---------------------------------------------- #


  #region ------ [ Elastic Network Interfaces (ENIs) ] ----------------------------------------- #

  elastic_network_interfaces = {
    for region in var.aws_config.regions : region => merge([
      for system in var.all_systems : {
        for index in range(length(system.network_interfaces)) :
        "${system.hostname}-eni-${index}" => {

          # AWS Network Interface Properties
          availability_zone = system.availability_zone
          description       = system.network_interfaces[index].description
          hostname          = system.hostname
          index             = index
          interface_type    = system.network_interfaces[index].interface_type
          # Null lets AWS pick a free address from the subnet CIDR. Carried both ways: the
          # scalar is what the pinned-address precondition reasons about, the list is what
          # the aws_network_interface attribute takes.
          private_ip  = system.network_interfaces[index].private_ip
          private_ips = system.network_interfaces[index].private_ip == null ? null : [system.network_interfaces[index].private_ip]
          # The pre-existing security-group ids the consumer listed plus this interface's own
          # group when its rule collections are non-null. The same per-interface predicate guards
          # both validation and attachment, so an interface can never silently receive the VPC
          # default allow-all group.
          security_groups = concat(
            system.network_interfaces[index].security_groups,
            (
              system.network_interfaces[index].ingress != null &&
              system.network_interfaces[index].egress != null
            ) ? [local.network_interface_security_group_ids[region]["${system.hostname}-eni-${index}-sg"]]
            : [],
            # Attached here, at ENI creation, rather than modified onto the interface afterwards:
            # creation-time attachment stays inside a consumer's existing IAM grants, where
            # ec2:ModifyNetworkInterfaceAttribute would force every consumer to widen its policy.
            # Skipped for tunnelled systems, which accept no inbound connection at all.
            (
              var.runner_ip == null ||
              local.connection_over_ssm[system.hostname]
            ) ? [] : [local.runner_ingress_security_group_ids[region][local.runner_ingress_name]],
          )
          subnet_id = system.subnet_id

          tags = merge(
            system.network_interfaces[index].tags,
            # Non-Overwritable Default Tags
            local.identity_tags,
            {
              Index = index
              Name  = system.hostname
            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region
    ]...)
  }

  #endregion --- [ Elastic Network Interfaces (ENIs) ] ----------------------------------------- #


  #region ------ [ Elastic Block Store (EBS) ] ------------------------------------------------- #

  ebs_block_devices = {
    for region in var.aws_config.regions : region => merge([
      for system in var.all_systems : {
        for volume in system.ebs_block_devices :
        "${system.hostname}-ebs-${volume.resource_key}" => {

          # AWS Elastic Block Store Properties
          availability_zone = system.availability_zone
          hostname          = system.hostname
          index             = volume.device_index
          iops              = volume.iops
          kms_key_id        = system.aws_kms_alias
          refresh           = system.refresh
          resource_key      = volume.resource_key
          skip_destroy      = volume.skip_destroy
          snapshot_id       = volume.snapshot_id
          throughput        = volume.throughput
          volume_size       = volume.volume_size
          volume_type       = volume.volume_type

          device_name = (
            local.elastic_compute_cloud[region][system.hostname].is_windows
            ? "xvd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
            : "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
          )

          tags = merge(
            try(volume.tags, {}),
            # Non-Overwritable Default Tags
            local.identity_tags,
            {
              Index = volume.device_index
              Name  = system.hostname

              # Device letters come from device_index: 0 is sdd/xvdd, through 22 for sdz/xvdz.
              DeviceName = (
                local.elastic_compute_cloud[region][system.hostname].is_windows
                ? "xvd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
                : "/dev/sd${jsondecode(format("\"\\u%04x\"", 100 + volume.device_index))}"
              )

            }
          )
        }
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(system.region, "-", "_") == region && system.ebs_block_devices != null
    ]...)
  }

  # Attachments follow their instance's refresh setting. Volumes do not consume this split so
  # changing refresh never changes a standalone data volume's resource address.
  ebs_block_devices_stable = {
    for region in var.aws_config.regions : region => {
      for key, volume in local.ebs_block_devices[region] : key => volume
      if volume.refresh == false
    }
  }

  ebs_block_devices_refresh = {
    for region in var.aws_config.regions : region => {
      for key, volume in local.ebs_block_devices[region] : key => volume
      if volume.refresh == true
    }
  }

  #endregion --- [ Elastic Block Store (EBS) ] ------------------------------------------------- #


  #region ------ [ Elastic Load Balancers (ELBs) ] --------------------------------------------- #

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
          # Non-Overwritable Default Tags
          local.identity_tags,
          {
            Name = coalesce(load_balancer.name, load_balancer.name_prefix, load_balancer.resource_key)
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

          connection_termination            = target_group.connection_termination
          deregistration_delay              = target_group.deregistration_delay
          health_check                      = target_group.health_check
          ip_address_type                   = target_group.ip_address_type
          load_balancing_algorithm_type     = target_group.load_balancing_algorithm_type
          load_balancing_anomaly_mitigation = target_group.load_balancing_anomaly_mitigation
          load_balancing_cross_zone_enabled = target_group.load_balancing_cross_zone_enabled
          port                              = target_group.port
          preserve_client_ip                = target_group.preserve_client_ip
          protocol                          = target_group.protocol
          protocol_version                  = target_group.protocol_version
          proxy_protocol_v2                 = target_group.proxy_protocol_v2
          slow_start                        = target_group.slow_start
          stickiness                        = target_group.stickiness
          target_type                       = target_group.target_type
          vpc_id                            = target_group.vpc_id

          tags = merge(
            target_group.tags,
            # Non-Overwritable Default Tags
            local.identity_tags,
            {
              Name = "${load_balancer.resource_key}/${target_group.resource_key}"
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

            hostname = system.hostname
            port     = target_group.port
            tg_key   = "${load_balancer.resource_key}/${target_group.resource_key}"

          }
          if(
            replace(system.region, "-", "_") == region &&
            system.tags.Function == target_group.function &&
            data.aws_subnet.us_east_1[system.subnet_id].vpc_id == target_group.vpc_id
          )
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

          alpn_policy     = listener.alpn_policy
          certificate_arn = listener.certificate_arn
          lb_key          = load_balancer.resource_key
          listener_key    = listener.resource_key
          port            = listener.port
          protocol        = listener.protocol
          ssl_policy      = listener.ssl_policy

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

            conditions   = rule.conditions
            listener_key = "${load_balancer.resource_key}/${listener.resource_key}"
            priority     = rule.priority

            action = {
              type             = rule.action.type
              target_group_key = rule.action.target_group_key == null ? null : "${load_balancer.resource_key}/${rule.action.target_group_key}"
              redirect         = rule.action.redirect
              fixed_response   = rule.action.fixed_response
            }

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

  #endregion --- [ Elastic Load Balancers (ELBs) ] --------------------------------------------- #


  #region ------ [ Relational Database Service (RDS) ] ----------------------------------------- #

  # final_snapshot_identifier carries var.run_id because AWS keeps a final snapshot after the
  # instance is gone and rejects a destroy whose snapshot name already exists. A name fixed to
  # db_name alone therefore makes the SECOND destroy of a database fail. run_id is unique per
  # deployment run and, unlike uuid() or timestamp(), leaves the plan deterministic. Repeated
  # local destroys must pass a different run_id.
  relational_database_service = {
    for region in var.aws_config.regions : region => {
      for database in var.all_databases : database.db_name => {

        allocated_storage                   = database.allocated_storage
        availability_zone                   = database.availability_zone
        backup_retention_period             = database.backup_retention_period
        backup_window                       = database.backup_window
        blue_green_update                   = database.blue_green_update
        ca_cert_identifier                  = database.ca_cert_identifier
        db_name                             = database.db_name
        db_subnet_group_name                = database.db_subnet_group_name
        dedicated_log_volume                = database.dedicated_log_volume
        delete_automated_backups            = database.delete_automated_backups
        deletion_protection                 = database.deletion_protection
        engine                              = database.engine
        engine_version                      = database.engine_version
        final_snapshot_identifier           = "${lower(database.db_name)}-final-${var.run_id}"
        iam_database_authentication_enabled = database.iam_database_authentication_enabled
        identifier                          = lower(database.db_name)
        instance_class                      = database.instance_class
        kms_key_id                          = database.aws_kms_alias
        manage_master_user_password         = database.manage_master_user_password
        max_allocated_storage               = database.max_allocated_storage
        skip_final_snapshot                 = database.skip_final_snapshot
        storage_type                        = database.storage_type
        vpc_security_group_ids              = database.vpc_security_group_ids

        tags = merge(
          database.tags,
          # Normalized Overwritable Tags
          {
            Backup = lower(database.tags["Backup"]) == "true" ? "True" : "False"
          },
          # Non-Overwritable Default Tags
          local.identity_tags,
          {
            Name = database.db_name
          }
        )
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(database.region, "-", "_") == region
    }
  }

  relational_database_service_credentials = {
    for region in var.aws_config.regions : region => {
      for database in var.all_databases : database.db_name => {
        username = sensitive(database.username)
      }
      # Normalize 'region' variable input to align with Terraform best practices.
      if replace(database.region, "-", "_") == region
    }
  }

  #endregion --- [ Relational Database Service (RDS) ] ----------------------------------------- #

}
