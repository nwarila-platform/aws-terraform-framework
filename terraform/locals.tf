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
  # Deduplicated per region to the distinct selectors actually in play: twenty systems sharing one
  # image in one region cost one parameter read and one image lookup, not twenty of each.
  ami_selectors_by_region = {
    for region in var.aws_config.regions : region => toset([
      for system in local.systems_by_region[region] : system.ami
    ])
  }

  # A literal id bypasses the catalog; every other selector resolves through it.
  catalog_selectors_by_region = {
    for region in var.aws_config.regions : region => toset([
      for ami in local.ami_selectors_by_region[region] : ami if !startswith(ami, "ami-")
    ])
  }

  catalog_selectors = toset([
    for system in var.all_systems : system.ami
    if !startswith(system.ami, "ami-")
  ])

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

  # One verified image object per selector in each region. Consumers read .id, .platform,
  # .platform_details, .root_device_name and .block_device_mappings from here and never learn
  # whether the id was pinned or resolved.
  amazon_machine_images = {
    us_east_1 = {
      for ami in local.ami_selectors_by_region.us_east_1 : ami =>
      data.aws_ami.us_east_1_verified[ami]
    }
  }

  #endregion --- [ Amazon Machine Image Resolution ] ------------------------------------------- #


  #region ------ [ Pre-Existing Infrastructure Selectors ] ------------------------------------- #

  # What each pre-existing-infrastructure lookup in data.tf iterates. Every set is deduplicated,
  # so systems sharing an alias, key pair, subnet or instance profile cost one read between them.
  # A KMS alias reaches this framework three ways, and all three land in the same region's key.
  kms_alias_selectors = {
    for region in var.aws_config.regions : region => toset(concat(
      [
        for system in local.systems_by_region[region] : system.aws_kms_alias
      ],
      [
        for database in local.databases_by_region[region] : database.aws_kms_alias
      ],
      [
        for volume in values(local.shared_volumes_by_region[region]) : volume.aws_kms_alias
      ],
    ))
  }

  key_pair_selectors = {
    for region in var.aws_config.regions : region => toset([
      for system in local.systems_by_region[region] : system.key_name
    ])
  }

  subnet_selectors = {
    for region in var.aws_config.regions : region => toset([
      for system in local.systems_by_region[region] : system.subnet_id
    ])
  }

  # An instance profile is a global IAM object, so this partition is the region of the systems
  # that reference it rather than a property of the profile itself.
  iam_instance_profile_selectors = {
    for region in var.aws_config.regions : region => toset([
      for system in local.systems_by_region[region] : system.iam_instance_profile
    ])
  }

  #endregion --- [ Pre-Existing Infrastructure Selectors ] ------------------------------------- #


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

  # user_data covers four things: installing OpenSSH itself when the image ships without it,
  # making sure sshd is actually running, installing the launch key, and making sure the SSM
  # agent is running on Linux. cloud-init is still the AMI's job. Every step below is
  # idempotent, so an image that already has them enabled pays nothing.
  #
  # The OpenSSH install exists because Server 2022 images ship without the OpenSSH.Server
  # capability, and an isolated instance cannot pull it from Windows Update. The payload comes
  # from the caller's bucket (var.windows_fod_source: bucket, its region, key prefix), rendered
  # in at plan time - nothing is looked up on the instance. The switch on OS build is the
  # per-version dispatch table: FoD cabs only apply to their own build, so each supported build
  # names its cab and the key is <key_prefix>/<build>/<cab>; supporting a new version is one
  # switch arm plus one staged object. -LimitAccess keeps DISM off Windows Update entirely, so
  # the only egress is S3 in the bucket's region. Server 2025 ships sshd in-box, so the branch
  # never runs there. The install runs first because sshd does not exist as a service until the
  # capability lands.
  #
  # The launch key is the only metadata read, so the IMDSv2 token is fetched right before it,
  # after the install, where a slow DISM run cannot outlive it.
  #
  # The launch key goes into administrators_authorized_keys before sshd starts, so the listener
  # never accepts a connection it cannot authenticate. sshd only creates C:\ProgramData\ssh on
  # its first start, so the bootstrap creates the directory itself - after a fresh capability
  # install there is nothing there yet.
  #
  # The single try/catch is the whole failure path: any error - unstaged build, unset bucket,
  # missing S3 object, DISM rejecting the cab - becomes one readable line in the EC2Launch log
  # and a nonzero exit instead of a PowerShell error cascade. The instance still fails loudly:
  # the readiness gate times out against a box with no sshd and surfaces the launch failure.
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
  # Null source renders as empty strings; the script throws the moment it needs them.
  windows_fod_bucket     = try(var.windows_fod_source.bucket, "")
  windows_fod_region     = try(var.windows_fod_source.region, "")
  windows_fod_key_prefix = try(var.windows_fod_source.key_prefix, "")

  windows_ssh_user_data = <<-WINDOWS_USER_DATA
    <powershell>
    $ErrorActionPreference = "Stop"

    # Rendered by Terraform from var.windows_fod_source; all empty when the source is unset.
    $fodBucket    = "${local.windows_fod_bucket}"
    $fodRegion    = "${local.windows_fod_region}"
    $fodKeyPrefix = "${local.windows_fod_key_prefix}"

    $capability     = "OpenSSH.Server~~~~0.0.1.0"
    $authorizedKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
    $imdsBase       = "http://169.254.169.254/latest"

    try {
      # 1. Install OpenSSH Server when the image ships without it. Each supported OS build
      #    names its own FoD cab; the payload comes from the staged bucket and DISM stays
      #    off Windows Update.
      $state = (Get-WindowsCapability -Online -Name $capability).State
      if ($state -ne "Installed") {
        if (-not $fodBucket) { throw "OpenSSH.Server is absent and windows_fod_source is unset" }

        $build = [int](Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild)
        $cab   = switch ($build) {
          20348   { "OpenSSH-Server-Package~31bf3856ad364e35~amd64~~.cab" }
          default { throw "no OpenSSH FoD is staged for Windows build $build" }
        }

        $stagingDir = "C:\Windows\Temp\fod"
        New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
        Read-S3Object -BucketName $fodBucket -Region $fodRegion -Key "$fodKeyPrefix/$build/$cab" -File "$stagingDir\$cab" | Out-Null
        Add-WindowsCapability -Online -Name $capability -Source $stagingDir -LimitAccess | Out-Null
        Remove-Item -Path $stagingDir -Recurse -Force
      }

      # 2. Enable the service and open the host firewall. Both are idempotent.
      Set-Service -Name sshd -StartupType Automatic
      New-NetFirewallRule -DisplayName "OpenSSH SSH Server" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null

      # 3. Install the launch key pair's public key for Administrator, read from IMDSv2. sshd only
      #    creates C:\ProgramData\ssh on its first start, so the directory is created here.
      $token     = Invoke-RestMethod -Method Put -Uri "$imdsBase/api/token" -Headers @{ "X-aws-ec2-metadata-token-ttl-seconds" = "300" }
      $publicKey = Invoke-RestMethod -Method Get -Uri "$imdsBase/meta-data/public-keys/0/openssh-key" -Headers @{ "X-aws-ec2-metadata-token" = $token }

      New-Item -Path (Split-Path -Path $authorizedKeys) -ItemType Directory -Force | Out-Null
      Set-Content -Path $authorizedKeys -Value $publicKey -Encoding Ascii
      icacls.exe $authorizedKeys /inheritance:r /grant "Administrators:F" "SYSTEM:F" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "icacls failed with exit code $LASTEXITCODE" }

      # 4. Start sshd only now, once it has a key it can authenticate.
      Start-Service -Name sshd
      Write-Output "SSH bootstrap complete"
    } catch {
      Write-Output "SSH bootstrap failed: $_"
      exit 1
    }
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

  # Readiness-gate wait commands (selected per-OS in terraform_data.readiness_gate). Each blocks
  # until the OS launch/provisioning agent reports completion after Terraform has first
  # connected.
  windows_readiness_command = "\"C:\\Program Files\\Amazon\\EC2Launch\\EC2Launch.exe\" status -b"
  linux_readiness_command   = "cloud-init status --wait"

  # Default upload directory for the Linux remote-exec script. The login user's home is
  # the usual escape hatch on images that mount /tmp noexec.
  linux_readiness_script_dir = "/home/ec2-user"

  #endregion --- [ Readiness Gate Wait Commands ] ---------------------------------------------- #
}


# Dynamically Configured LOCALS
locals {

  #region ------ [ Inputs Partitioned By Region ] ---------------------------------------------- #

  # Region normalization lives here so every downstream consumer shares one partition rule.
  systems_by_region = {
    for region in var.aws_config.regions : region => [
      for system in var.all_systems : system
      if replace(system.region, "-", "_") == region
    ]
  }

  load_balancers_by_region = {
    for region in var.aws_config.regions : region => [
      for load_balancer in var.all_load_balancers : load_balancer
      if replace(load_balancer.region, "-", "_") == region
    ]
  }

  databases_by_region = {
    for region in var.aws_config.regions : region => [
      for database in var.all_databases : database
      if replace(database.region, "-", "_") == region
    ]
  }

  shared_volumes_by_region = {
    for region in var.aws_config.regions : region => {
      for volume_key, volume in var.shared_ebs_volumes : volume_key => volume
      if replace(volume.region, "-", "_") == region
    }
  }

  #endregion --- [ Inputs Partitioned By Region ] ---------------------------------------------- #


  #region ------ [ Interface-Owned Security Groups ] ------------------------------------------- #

  # Each interface with non-null rule collections declares one group at its raw interface index.
  # Its "<hostname>-eni-<index>-sg" name pairs it visibly with the corresponding ENI. The region
  # and VPC come from the parent system because every interface already uses that system's subnet.
  # Description and tags come from the interface itself; a null description uses a stable
  # framework string.
  network_interface_security_groups = merge([
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
  ]...)

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


  #region ------ [ Run-Scoped Ingress Security Group ] ----------------------------------------- #

  # One group, attached to every directly-reached interface the framework builds, so whoever must
  # reach the fleet can for the life of a single run: the CI runner, an operator, or both. A
  # system reached over SSM accepts nothing inbound and is left out. No address at all
  # collapses every map below to {}, so the resources plan to nothing and no ENI gains a group.
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
  run_ingress_grants = merge(
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
  run_ingress_vpc_ids = {
    for region in var.aws_config.regions : region => distinct([
      for system in local.systems_by_region[region] :
      data.aws_subnet.us_east_1[system.subnet_id].vpc_id
      if !local.connection_over_ssm[system.hostname]
    ])
  }

  # True when nothing grants access, and when a region declares no systems: with nothing to
  # attach to there is no group to build, and indexing an empty VPC list would fail.
  run_ingress_disabled = {
    for region in var.aws_config.regions : region =>
    length(local.run_ingress_grants) == 0 || length(local.run_ingress_vpc_ids[region]) == 0
  }

  run_ingress_security_groups = {
    for region in var.aws_config.regions : region => (
      local.run_ingress_disabled[region] ? {} : {
        (local.runner_ingress_name) = {

          # AWS Security Group Properties
          description = "Run-scoped ingress. Managed by aws-terraform-framework."
          name        = local.runner_ingress_name
          # [0] rather than one(): one() is absent from Packer and unused here by style. A list
          # longer than 1 is caught by the single-VPC precondition on the group resource.
          vpc_id = local.run_ingress_vpc_ids[region][0]

          # The group declares no consumer tags, so this map is wholly framework-owned.
          tags = merge(local.identity_tags, {
            Name = local.runner_ingress_name
          })
        }
      }
    )
  }

  run_ingress_security_group_rules = {
    for region in var.aws_config.regions : region => (
      length(local.run_ingress_grants) == 0 || length(local.run_ingress_vpc_ids[region]) == 0 ? {} : {
        for key, grant in local.run_ingress_grants :
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

  # Name -> run-scoped SG id, mirroring network_interface_security_group_ids.
  run_ingress_security_group_ids = {
    us_east_1 = { for name, group in aws_security_group.runner_ingress_us_east_1 : name => group.id }
  }

  #endregion --- [ Run-Scoped Ingress Security Group ] ----------------------------------------- #


  #region ------ [ Elastic IPs ] --------------------------------------------------------------- #

  # Systems that requested a stable public IPv4: an EIP is allocated and associated with the
  # primary ENI.
  eip_systems = {
    for region in var.aws_config.regions : region => {
      for system in local.systems_by_region[region] : system.hostname => {

        # An Elastic IP declares no consumer tags, so this map is wholly framework-owned.
        tags = merge(local.identity_tags, {
          Name = system.hostname
        })
      }
      if system.associate_public_ip
    }
  }

  #endregion --- [ Elastic IPs ] --------------------------------------------------------------- #


  #region ------ [ Elastic Compute Cloud (EC2s) ] ---------------------------------------------- #

  elastic_compute_cloud = {
    for region in var.aws_config.regions : region => {
      for system in local.systems_by_region[region] : system.hostname => {

        ami                        = system.ami
        availability_zone          = system.availability_zone
        hostname                   = system.hostname
        iam_instance_profile       = system.iam_instance_profile
        imds_hop_limit             = system.imds_hop_limit
        instance_type              = system.instance_type
        is_windows                 = local.amazon_machine_images[region][system.ami].platform == "windows"
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

        # WinRM authenticates as Administrator with the launch password, so the encrypted blob has
        # to be fetched. Only for WinRM: it costs apply latency while the provider waits for the
        # password to become available, and the SSH path has no use for it. Tunnelling over SSM
        # does not change how the far end authenticates, so this keys off the protocol.
        get_password_data = (
          local.amazon_machine_images[region][system.ami].platform == "windows" &&
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
          local.amazon_machine_images[region][system.ami].platform == "windows"
          ? (
            local.connection_protocol[system.hostname] == "winrm"
            ? local.windows_winrm_user_data
            : local.windows_ssh_user_data
          )
          : replace(local.linux_ssh_user_data, "__AWS_REGION__", replace(region, "_", "-"))
        )

        root_block_device = {
          iops        = system.root_block_device.iops
          kms_key_id  = system.aws_kms_alias
          throughput  = system.root_block_device.throughput
          volume_size = system.root_block_device.volume_size
          volume_type = system.root_block_device.volume_type

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
            device_name = override.device_name
            iops        = override.iops
            kms_key_id  = system.aws_kms_alias
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
          for mapping in try(local.amazon_machine_images[region][system.ami].block_device_mappings, []) :
          mapping.device_name
          if length(try(mapping.ebs, {})) > 0 &&
          try(mapping.no_device, "") == "" &&
          try(mapping.virtual_name, "") == "" &&
          mapping.device_name != try(local.amazon_machine_images[region][system.ami].root_device_name, "") &&
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
            OS   = local.amazon_machine_images[region][system.ami].platform_details
          }
        )
      }
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

  # Combine each instance's runtime facts (id, private IP) with its system's OS and transport, so
  # the readiness gate can pick the right login user, wait command and connection per instance.
  # Systems that set readiness_gate = false (for example zero-inbound SSM-only boxes) are excluded
  # entirely.
  readiness_targets = {
    for region in var.aws_config.regions : region => {
      for hostname, system in local.elastic_compute_cloud[region] : hostname => {
        id         = local.all_ec2_instances[hostname].id
        private_ip = local.all_ec2_instances[hostname].private_ip
        # Everything the gate needs is decided here: the connection mechanics and both
        # OS-specific fallbacks, so the resource reads fields and makes no choices.
        readiness_user = coalesce(
          system.readiness_user,
          system.is_windows ? "Administrator" : "ec2-user",
        )
        readiness_command = coalesce(
          system.readiness_command,
          system.is_windows ? local.windows_readiness_command : local.linux_readiness_command,
        )
        target_platform = system.is_windows ? "windows" : "unix"
        script_path = (
          system.is_windows
          ? null
          : "${coalesce(system.readiness_script_dir, local.linux_readiness_script_dir)}/terraform_%RAND%.sh"
        )
        private_key_path = system.readiness_private_key_path

        # WinRM reaches 5986 over TLS with a certificate the instance generated for itself, so the
        # client cannot verify it and insecure has to be true. NTLM carries the authentication.
        use_winrm  = system.connection_protocol == "winrm"
        winrm_port = 5986

        # Decrypted in flight from the encrypted blob AWS returns, with the launch private key the
        # gate already requires. Only the ciphertext ever reaches state.
        password = (
          system.connection_protocol == "winrm" && system.readiness_private_key_path != null
          ? rsadecrypt(local.all_ec2_instances[hostname].password_data, file(system.readiness_private_key_path))
          : null
        )
      }
      if system.readiness_gate
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
      for hostname, system in local.elastic_compute_cloud[region] : hostname => {
        instance_id = local.all_ec2_instances[hostname].id
        state       = system.set_state
      }
      if system.set_state != null
    }
  }

  #endregion --- [ Elastic Compute Cloud (EC2s) ] ---------------------------------------------- #


  #region ------ [ Elastic Network Interfaces (ENIs) ] ----------------------------------------- #

  # Each interface's authored private IPv4 addresses, normalized. additional_private_ips has
  # two off spellings - the attribute's own null and an empty list - and both have to mean
  # "this interface is unchanged", so they collapse to one empty list here instead of at each
  # place that reads them.
  interface_authored_addresses = merge([
    for system in var.all_systems : {
      for index in range(length(system.network_interfaces)) :
      "${system.hostname}-eni-${index}" => {
        primary = system.network_interfaces[index].private_ip
        additional = (
          system.network_interfaces[index].additional_private_ips == null
          ? []
          : system.network_interfaces[index].additional_private_ips
        )
      }
    }
  ]...)

  # What the provider is actually handed for each interface's private IPv4 addressing.
  #
  # An interface carrying at most one authored address keeps the unordered `private_ips` set
  # this framework has always written, so an interface that asks for no further address plans
  # no change.
  #
  # Further addresses move the interface to `private_ip_list`, which reaches AWS in authored order
  # and whose first element AWS marks primary. The set cannot carry them, for two reasons. Its
  # members reach AWS in SDKv2 hash order, so the primary would be whichever address hashed lowest
  # rather than the one the consumer authored - for ["10.0.0.5", "10.0.0.6"] the primary becomes
  # 10.0.0.6. And that 32-bit hash collides on real addresses: 10.200.129.167 and 10.200.142.0
  # share one code, so a set holding both would silently keep only one. A Windows failover cluster
  # needs the opposite of both: the node's own address primary, and every cluster address a
  # secondary the operating system never configures.
  #
  # The provider declares the two mutually exclusive, so exactly one of them is ever non-null.
  # An explicit null does not count as a configured value for that exclusivity, which is what
  # lets both attributes stay listed on the resource.
  interface_private_addressing = {
    for key, addresses in local.interface_authored_addresses :
    key => {
      private_ip_list_enabled = length(addresses.additional) > 0

      private_ips = (
        length(addresses.additional) > 0 || addresses.primary == null
        ? null
        : [addresses.primary]
      )

      private_ip_list = (
        length(addresses.additional) > 0
        ? concat([addresses.primary], addresses.additional)
        : null
      )
    }
  }

  elastic_network_interfaces = {
    for region in var.aws_config.regions : region => merge([
      for system in local.systems_by_region[region] : {
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
          private_ip              = system.network_interfaces[index].private_ip
          additional_private_ips  = local.interface_authored_addresses["${system.hostname}-eni-${index}"].additional
          private_ips             = local.interface_private_addressing["${system.hostname}-eni-${index}"].private_ips
          private_ip_list         = local.interface_private_addressing["${system.hostname}-eni-${index}"].private_ip_list
          private_ip_list_enabled = local.interface_private_addressing["${system.hostname}-eni-${index}"].private_ip_list_enabled
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
              length(local.run_ingress_grants) == 0 ||
              local.connection_over_ssm[system.hostname]
            ) ? [] : [local.run_ingress_security_group_ids[region][local.runner_ingress_name]],
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
    ]...)
  }

  #endregion --- [ Elastic Network Interfaces (ENIs) ] ----------------------------------------- #


  #region ------ [ Elastic Block Store (EBS) ] ------------------------------------------------- #

  ebs_block_devices = {
    for region in var.aws_config.regions : region => merge(
      merge([
        for system in local.systems_by_region[region] : {
          for volume in system.ebs_block_devices :
          "${system.hostname}-ebs-${volume.resource_key}" => {

            # AWS Elastic Block Store Properties
            availability_zone    = system.availability_zone
            hostname             = system.hostname
            index                = volume.device_index
            iops                 = volume.iops
            kms_key_id           = system.aws_kms_alias
            multi_attach_enabled = null
            snapshot_id          = volume.snapshot_id
            throughput           = volume.throughput
            volume_size          = volume.volume_size
            volume_type          = volume.volume_type

            device_name = (
              local.elastic_compute_cloud[region][system.hostname].is_windows
              ? "xvd${substr("defghijklmnopqrstuvwxyz", volume.device_index, 1)}"
              : "/dev/sd${substr("defghijklmnopqrstuvwxyz", volume.device_index, 1)}"
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
                  ? "xvd${substr("defghijklmnopqrstuvwxyz", volume.device_index, 1)}"
                  : "/dev/sd${substr("defghijklmnopqrstuvwxyz", volume.device_index, 1)}"
                )

              }
            )
          }
        }
        if system.ebs_block_devices != null
      ]...),
      {
        for volume_key, volume in local.shared_volumes_by_region[region] :
        volume_key => {
          availability_zone    = volume.availability_zone
          iops                 = volume.iops
          kms_key_id           = volume.aws_kms_alias
          multi_attach_enabled = true
          snapshot_id          = null
          throughput           = null
          volume_size          = volume.volume_size
          volume_type          = "io2"

          tags = merge(volume.tags, local.identity_tags, {
            Name = volume_key
          })
        }
      },
    )
  }

  # Each shared volume's device index, keyed by the host it is attached to. Attachment hostnames
  # are validated unique within a volume, so this map is total and the attachments list is
  # searched here once instead of at every place a device name is spelled.
  shared_volume_device_indexes = {
    for volume_key, volume in var.shared_ebs_volumes : volume_key => {
      for attachment in volume.attachments : attachment.hostname => attachment.device_index
    }
  }

  # The one attachment map spans stable, refresh, standalone, and shared lifecycles. Standalone
  # keys stay unchanged; JSON tuple keys keep shared volume/host identities unambiguous.
  ebs_volume_attachments = {
    for region in var.aws_config.regions : region => merge(
      merge([
        for system in local.systems_by_region[region] : {
          for volume in system.ebs_block_devices :
          "${system.hostname}-ebs-${volume.resource_key}" => {
            device_name = local.ebs_block_devices[region][
              "${system.hostname}-ebs-${volume.resource_key}"
            ].device_name
            hostname   = system.hostname
            volume_key = "${system.hostname}-ebs-${volume.resource_key}"
          }
        }
        if system.ebs_block_devices != null
      ]...),
      merge([
        for volume_key, volume in local.shared_volumes_by_region[region] : {
          for hostname in distinct([
            for attachment in volume.attachments : attachment.hostname
            ]) : jsonencode([volume_key, hostname]) => {
            hostname   = hostname
            volume_key = volume_key

            # Device letters come from device_index: 0 is sdd/xvdd, through 22 for sdz/xvdz.
            device_name = (
              local.elastic_compute_cloud[region][hostname].is_windows
              ? "xvd${substr("defghijklmnopqrstuvwxyz", local.shared_volume_device_indexes[volume_key][hostname], 1)}"
              : "/dev/sd${substr("defghijklmnopqrstuvwxyz", local.shared_volume_device_indexes[volume_key][hostname], 1)}"
            )
          }
          if contains(keys(local.elastic_compute_cloud[region]), hostname)
        }
      ]...),
    )
  }

  #endregion --- [ Elastic Block Store (EBS) ] ------------------------------------------------- #


  #region ------ [ Elastic Load Balancers (ELBs) ] --------------------------------------------- #

  elastic_load_balancers = {
    for region in var.aws_config.regions : region => {
      for load_balancer in local.load_balancers_by_region[region] : load_balancer.resource_key => {

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
    }
  }

  lb_target_groups = {
    for region in var.aws_config.regions : region => merge([
      for load_balancer in local.load_balancers_by_region[region] : {
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
    ]...)
  }

  lb_target_group_attachments = {
    for region in var.aws_config.regions : region => merge(flatten([
      for load_balancer in local.load_balancers_by_region[region] : [
        for target_group in load_balancer.target_groups : {
          for system in local.systems_by_region[region] :
          "${load_balancer.resource_key}/${target_group.resource_key}/${system.hostname}" => {

            hostname = system.hostname
            port     = target_group.port
            tg_key   = "${load_balancer.resource_key}/${target_group.resource_key}"

          }
          if(
            system.tags.Function == target_group.function &&
            data.aws_subnet.us_east_1[system.subnet_id].vpc_id == target_group.vpc_id
          )
        }
      ]
    ])...)
  }

  lb_listeners = {
    for region in var.aws_config.regions : region => merge([
      for load_balancer in local.load_balancers_by_region[region] : {
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
    ]...)
  }

  # A rendered key that collides fails the plan here instead of silently losing a resource:
  # merge() keeps the last value for a duplicate key, a single for expression refuses it. The
  # entries carry identity components; the map below renders the key, as the security-group rule
  # pair above does.
  lb_listener_rule_entries = {
    for region in var.aws_config.regions : region => flatten([
      for load_balancer in local.load_balancers_by_region[region] : [
        for listener in load_balancer.listeners : [
          for rule in listener.rules : {
            load_balancer_key = load_balancer.resource_key
            listener_key      = listener.resource_key
            rule              = rule
          }
        ]
      ]
    ])
  }

  lb_listener_rules = {
    for region in var.aws_config.regions : region => {
      for entry in local.lb_listener_rule_entries[region] :
      "${entry.load_balancer_key}/${entry.listener_key}/${entry.rule.resource_key}" => {

        conditions   = entry.rule.conditions
        listener_key = "${entry.load_balancer_key}/${entry.listener_key}"
        priority     = entry.rule.priority

        action = {
          type             = entry.rule.action.type
          target_group_key = entry.rule.action.target_group_key == null ? null : "${entry.load_balancer_key}/${entry.rule.action.target_group_key}"
          redirect         = entry.rule.action.redirect
          fixed_response   = entry.rule.action.fixed_response
        }

      }
    }
  }

  lb_listener_certificate_entries = {
    for region in var.aws_config.regions : region => flatten([
      for load_balancer in local.load_balancers_by_region[region] : [
        for listener in load_balancer.listeners : [
          for certificate_arn in listener.additional_certificate_arns : {
            load_balancer_key = load_balancer.resource_key
            listener_key      = listener.resource_key
            certificate_arn   = certificate_arn
          }
        ]
      ]
    ])
  }

  lb_listener_certificates = {
    for region in var.aws_config.regions : region => {
      for entry in local.lb_listener_certificate_entries[region] :
      "${entry.load_balancer_key}/${entry.listener_key}/${entry.certificate_arn}" => {

        listener_key    = "${entry.load_balancer_key}/${entry.listener_key}"
        certificate_arn = entry.certificate_arn
      }
    }
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
      for database in local.databases_by_region[region] : database.db_name => {

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
    }
  }

  relational_database_service_credentials = {
    for region in var.aws_config.regions : region => {
      for database in local.databases_by_region[region] : database.db_name => {
        username = sensitive(database.username)
      }
    }
  }

  #endregion --- [ Relational Database Service (RDS) ] ----------------------------------------- #

}
