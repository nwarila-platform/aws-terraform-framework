# Manage EC2 readiness transports

Use this guide when adding EC2 instances whose Terraform readiness gate runs
over direct SSH or Windows WinRM before hand-off to a separate
configuration-management pipeline. It also covers the SSH and WinRM bootstrap
used when a later management pipeline reaches the instance through SSM.

## Operating model

Linux uses SSH. Windows defaults to SSH, whose `user_data` bootstraps OpenSSH
and installs the launch key pair's public key for Administrator. Selecting
WinRM instead configures HTTPS on TCP 5986 and authenticates with the AWS launch
password. The `-ssm` forms render the same protocol bootstrap but open no
run-scoped inbound path and require `readiness_gate = false`; Terraform does not
establish the Session Manager tunnel. Ansible runs outside this repository, in
a separate pipeline job, using its own connection settings.

This repository stops at creating reachable instances, gating initial readiness,
and emitting a non-secret inventory hand-off. It does not run Ansible, create IAM
roles, create networking, or create general-purpose shared/cross-system security
groups. Its only cross-system group is the optional run-scoped readiness ingress
group described below.

All four readiness inputs are per-system and fall back by OS when left null:

| Input | Null resolves to |
|---|---|
| `readiness_user` | `ec2-user` on Linux, `Administrator` on Windows |
| `readiness_command` | `cloud-init status --wait` on Linux, `EC2Launch.exe status -b` on Windows |
| `readiness_script_dir` | `/home/ec2-user` on Linux; unused on Windows, which needs no upload directory |
| `readiness_private_key_path` | no key, which is the plan/CI posture |

Override `readiness_command` for images whose provisioning completes on a different
signal, and `readiness_user` for images with a different default login (ubuntu, rocky,
admin). Each falls back independently, so overriding one leaves the others on their
defaults.

Set `readiness_script_dir` when the image mounts `/home` `noexec` - the gate uploads a
script there and a `noexec` mount fails the upload rather than the command. `/tmp`,
`/var/tmp` and `/dev/shm` are commonly `noexec` on hardened images, which is why the login
user's home is the default rather than `/tmp`.

`readiness_private_key_path` is per system rather than per key pair, so two
systems sharing a key pair may still read it from different paths. SSH uses the
key directly; WinRM uses it to decrypt the AWS launch-password blob. A real
apply of a gated system needs a path that exists on the machine running
Terraform.

## Configure the instance profile

Set `iam_instance_profile` on every `all_systems` entry. The framework validates
that the named profile exists and attaches it to the EC2 instance, but it does
not create IAM roles, instance profiles, or policies.

The profile is a general-purpose instance profile for workloads and platform
agents, such as a CloudWatch agent, application AWS access, or patch management.
Choose the least-privilege policies that match those instance responsibilities.

```hcl
all_systems = [
  {
    region                     = "us_east_1"
    hostname                   = "app01"
    availability_zone          = "us-east-1a"
    subnet_id                  = "subnet-replace-me"
    key_name                   = "app-linux-key"
    iam_instance_profile       = "ec2-REPLACE_ME-profile"
    aws_kms_alias              = "ebs-REPLACE_ME"
    ami                        = "app-linux"
    refresh                    = false
    instance_type              = "m6i.large"
    connection_type            = null
    readiness_user             = null
    readiness_command          = null
    readiness_script_dir       = null
    readiness_private_key_path = "/secure/path/REPLACE_ME-app-linux-key.pem"
    readiness_gate             = true
    imds_hop_limit             = 1
    set_state                  = null

    tags = {
      Function = "app"
      Backup   = true
    }

    root_block_device = {
      iops        = null
      tags        = {}
      throughput  = null
      volume_type = "gp3"
      volume_size = "100"
    }

    ebs_block_devices = []

    ami_block_device_overrides = []

    network_interfaces = [
      {
        # Null lets AWS pick a free address from the subnet CIDR, and the aws_instances output
        # reports whichever address it picked. Prefer this: a generated Ansible inventory reads
        # the address back after apply, so nothing needs it hand-allocated up front.
        private_ip = null
        # Null is the off switch, and [] means the same: this interface carries no further
        # private addresses.
        additional_private_ips = null
        security_groups        = ["sg-REPLACE_ME"]
        # Non-null ingress and egress declare this interface's own "app01-eni-0-sg" group. Its
        # description and tags come from this same interface, and the framework attaches it only
        # here. security_groups remains exclusively for pre-created group IDs.
        description    = "app01 inbound firewall."
        interface_type = null
        ingress = [
          {
            description                  = "HTTPS from the internal load-balancer subnet"
            ip_protocol                  = "tcp"
            from_port                    = 443
            to_port                      = 443
            cidr_ipv4                    = "10.0.0.0/16"
            prefix_list_id               = null
            referenced_security_group_id = null
          }
        ]
        egress = [
          {
            description                  = "All outbound"
            ip_protocol                  = "-1"
            from_port                    = null
            to_port                      = null
            cidr_ipv4                    = "0.0.0.0/0"
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
```

## Use readiness-ready images

Linux images must include an SSH server before this framework launches
instances. The readiness gate logs in as `ec2-user` by default; set
`readiness_user` per system for images with a different default login such as
`ubuntu`, `rocky`, or `admin`. The framework's Linux `user_data` only enables
and starts whichever SSH unit the distro provides at boot:

```sh
systemctl enable --now sshd || systemctl enable --now ssh
```

Images are addressed, never discovered. Write a selector such as `rhel@8.10` and
the framework turns it into one exact key in the image catalog, reads the AMI ID
stored there, and verifies that image before launching it. There is no name
filter and no `most_recent` anywhere, so a plan resolves to the same image every
time until the catalog itself changes.

How much drift a selector accepts is decided by how much of it you write. Each
omitted trailing segment floats:

| Selector | Resolves to | Drift accepted |
| --- | --- | --- |
| `rhel` | the family's floating `latest` pointer | any new publish |
| `rhel@8` | the major-version pointer | minor and build drift within 8 |
| `rhel@8.10` | the minor-version pointer | build drift within 8.10 |
| `rhel@8.10.20260808` | that day's immutable entry | none - bit-exact forever |

The build date is atomic: it is a full `YYYYMMDD` and may appear only as the last
segment. A month prefix such as `rhel@8.10.202608` is rejected at
`terraform validate`, because it reads as a pin but behaves like a floating
pointer until the month ends and a stale one after that. Selectors are lowercase
and used verbatim as catalog keys, so case is rejected rather than folded.

A selector naming a family or version that was never published fails the plan
rather than falling back to anything approximate.

A direct `ami-...` ID remains an exact pin and bypasses the catalog, but is still
verified.

Ownership is checked either way, with a deliberate asymmetry. A catalog selector
must resolve to an image the deploying account published - nothing else can
satisfy a named address. A literal ID may additionally name one of two vendor
accounts, because those base images are pinned directly rather than republished:

| Account | Images |
| --- | --- |
| the deploying account | everything this org builds |
| `679593333241` | CIS hardened images from the AWS Marketplace |
| `801119661308` | Amazon-published Windows Server images |

That list is temporary. Once those images are mirrored into the catalog they
become ordinary selectors and the exception goes away. An image owned by any
other account fails the plan whichever form you use.

The image is expected to arrive with OpenSSH and cloud-init installed. Bake those into the AMI.
Windows Server 2022 is the exception: its stock images ship without the `OpenSSH.Server`
capability, and an isolated instance cannot pull it from Windows Update, so `user_data`
installs it from a staged Feature-on-Demand cab when `windows_fod_source` is set (see below).

The SSM agent is the exception, on Linux only. `user_data` enables it if the image ships it
disabled, and installs it from the region's S3 bucket if the image lacks it entirely. That is
temporary: it exists because the image catalog is unpopulated, so every image in play today is a
vendor one reached through the literal `ami-` escape hatch, and CIS RHEL ships the agent without
enabling it. Amazon's Windows images register on their own and get no such step.

The install path needs egress at boot. On an image with no route to S3 it fails, and the failure
appears in the console log and in `cloud-init status` rather than leaving a host that looks
healthy and never becomes manageable.

What it does cover is what an image cannot carry. First, it enables and
starts `sshd`, because "installed but not enabled" is a plausible state on a
hardened or third-party image and it strands the box with no way in; both forms
are idempotent, so an image that already has it running pays nothing.

Second, on Windows only, it reads the launch key pair's public key from IMDSv2 into
`administrators_authorized_keys` with the ACLs OpenSSH requires, because
EC2Launch populates the Administrator password path rather than that file.
`Start-Service` runs after that write, so the listener never accepts a connection
it cannot yet authenticate. Linux needs no key step: cloud-init installs the
launch key into the login user's `authorized_keys` by itself.

Third, again on Windows only, it opens inbound TCP 22 in the host firewall,
mirroring what the WinRM path does for 5986. A hardened image may ship OpenSSH
with its inbound rule absent or disabled, and the firewall then refuses the
connection whether or not `sshd` is listening — the readiness gate times out
against a machine that is running perfectly. The rule is created with the rest of
the configuration, before `Start-Service`, because opening a port nothing is
listening on yet is inert. Linux needs no equivalent: security groups are the
only filter in front of it.

If OpenSSH is absent, `user_data` installs it before any of the above runs. Stage the
build's cab in an S3 bucket as `<key_prefix>/<OS build>/<package>.cab` (for Server 2022,
build 20348: `fod/20348/OpenSSH-Server-Package~31bf3856ad364e35~amd64~~.cab`, copied
unrenamed from the Windows Server Languages and Optional Features ISO) and point
`windows_fod_source` at it: the bucket's name, the region it lives in, and the key prefix.
All three are rendered into `user_data` at plan time; the instance looks nothing up. The
instance profile needs `s3:GetObject` on `<key_prefix>/*` in that bucket, and the instance
needs a route to S3 in the bucket's region — a gateway endpoint when that is its own region,
otherwise an internet or NAT route. DISM runs with `-LimitAccess`, so Windows Update is never
contacted. Server 2025 ships `sshd` in-box and skips the step. With `windows_fod_source`
null, or no cab staged for the image's build, `user_data` aborts with one line in the
EC2Launch log, so an unreachable image fails loudly rather than silently.

Runtime verification beyond the Terraform readiness gate is outside this
repository. The pipeline should check that each emitted target is reachable
before it runs configuration management.

Prefer `windows@2025` over `windows@2022` for new deployments; Windows Server 2022 mainstream
support ends on 2026-10-13. Windows selectors are two-deep - an LTSC year and a build date - and
no minor segment is invented for them. The image owner is hardcoded to the deploying account and
is not a consumer input, so publishing a Windows image into the catalog is what makes it
selectable.

## Choosing a transport

`connection_type` selects how a system is reached, and which bootstrap `user_data` renders to
match. Null takes `ssh`, which is the default for every platform.

It names two things at once: the protocol on the wire, and whether the system is reached
directly or only through an SSM tunnel.

| Value | Protocol | Reached | Readiness gate |
| --- | --- | --- | --- |
| `ssh` (or null) | SSH | directly | supported |
| `winrm` | WinRM | directly | supported |
| `ssh-ssm` | SSH | SSM tunnel only | must be `false` |
| `winrm-ssm` | WinRM | SSM tunnel only | must be `false` |

SSM is a channel rather than a protocol, so the `-ssm` forms still render the same bootstrap as
their direct counterparts - something has to be listening for the tunnel to carry.

What the `-ssm` forms change inside this framework is run-scoped inbound exposure: those systems
are not given the runner ingress group. Consumer-supplied security groups remain unchanged and
can still contain their own inbound rules. If every system in a region is reached through SSM,
no run-scoped group is created at all.

They also cannot use the readiness gate, and setting `readiness_gate = true` alongside one is
rejected at plan time rather than ignored. Terraform's `connection` block speaks direct SSH and
WinRM only - it has no `ProxyCommand` and does not read `ssh_config` - so it cannot dial through
Session Manager. Reaching one would need the runner to establish a port-forward first and the
gate to target `localhost`, which this framework does not do.

`winrm` is Windows-only and exists for images that cannot install the OpenSSH
Feature-on-Demand. Every stock Windows AMI needs Windows Update egress to install it, so in an
egress-restricted network the SSH gate cannot connect at all. WS-Management is in-box, so it
works there.

Choosing `winrm` changes three things:

- `user_data` configures a WinRM HTTPS listener on 5986 bound to a certificate the instance
  generates for itself, removes the HTTP listener, and disables the stock WinRM firewall group.
  5985 is never opened: Terraform's WinRM client authenticates with NTLM but does not seal
  messages, so an unencrypted listener would be refused by the service anyway.
- `get_password_data` turns on, because WinRM authenticates as Administrator with the launch
  password. A direct gate decrypts it in flight with `readiness_private_key_path`; an SSM form
  has no gate and does not decrypt it in this module.
- The gate connects with `https`, `insecure` and `use_ntlm` set. `insecure` is required because
  the certificate is self-signed and no client can verify it.

Setting `winrm` or `winrm-ssm` on a Linux system fails at plan time. The operating system comes
from the AMI lookup, so the guard is a precondition on the instance rather than a variable
validation - on the instance specifically, because a tunnelled system has no readiness gate for
the check to live on.

This module validates Windows hostnames for NetBIOS compatibility, including
the 15-character limit, but it does not set OS hostnames. Hostname setting
belongs in the Ansible job.

## Open readiness access from the controller

Interfaces reference pre-created, consumer-owned groups by ID through `security_groups`.
Setting non-null `ingress` and `egress` additionally creates a framework-owned
`<hostname>-eni-<index>-sg` group with those rules, attached only to that interface.

Use this network posture:

- For direct SSH, allow inbound TCP 22 from the Terraform apply host in either
  a pre-created group or the interface-owned group's `ingress` list.
- For direct WinRM, allow inbound TCP 5986 from the Terraform apply host. The
  framework opens only HTTPS/5986 in the Windows host firewall; it never opens
  HTTP/5985.
- Ensure private subnet instances are reachable from the Ansible controller
  through routing, VPN, a bastion path, or another consumer-managed path.
- RDP on 3389 is opened by the framework, not the consumer, whenever `debug_ip`
  is non-null: the run-scoped group carries a module-owned tcp/3389 rule so a
  person can sit on a Windows desktop. What stays consumer-owned is the guest
  side - the framework never enables the Windows RDP service or its host
  firewall. WinRM is configured only when the system selects a WinRM connection
  type.
- WinRM over HTTP on 5985 is opened the same way, for the same address and
  nobody else. A domain-joined guest gets its HTTP listener and firewall rule
  from Group Policy, and an operator driving Ansible against it arrives on that
  listener with a client that seals its own messages (pywinrm's NTLM or Kerberos
  message encryption satisfies `AllowUnencrypted = false`). The runner's set
  never includes 5985: the only WinRM client a run drives is the readiness gate
  above, which does not seal. As with RDP, the security group is the whole of
  the framework's part - it never opens 5985 in the guest firewall.
- Systems with `readiness_gate = false` need no inbound access from the apply
  host for readiness. The `-ssm` forms require this posture.

## Hand off inventory

After apply, read the `aws_instances` output. It is keyed by hostname and
contains only neutral, non-secret values:

- `hostname`: the map key repeated as an inventory fact.
- `instance_id`: the EC2 instance ID.
- `region`: the normalized framework region key.
- `private_ip`: the primary private IP from the framework-owned
  `<hostname>-eni-0` network interface. If the interface also sets
  `additional_private_ips`, the pinned `private_ip` remains primary and the
  further addresses are deliberately absent from this inventory.
- `private_dns`: the EC2 private DNS name.
- `function`: supplied by `all_systems[*].tags.Function`.
- `os_family`: `linux` or `windows`, derived from the resolved AMI `platform`.
- `environment`: supplied by `var.environment`.

The `private_ip`, `private_dns`, and `instance_id` values are apply-known. They
are included for hand-off and debugging, not for secret distribution. Refresh
instances use the same primary ENI naming pattern as normal instances, so the
output resolves their `<hostname>-eni-0` address from the shared regional ENI
map.

Because these values are read back from the created interface, `private_ip`
resolves identically whether the consumer pinned the address, left
`private_ip = null` for AWS to assign, or pinned it and added further addresses
beside it. A generated inventory therefore never needs a hand-allocated
address, and AWS gives no guarantee about *which* free address it picks - treat
an auto-assigned address as stable for the life of the interface but never
predictable ahead of apply.

Example:

```sh
terraform -chdir=terraform output -json aws_instances
```

The Ansible pipeline can use the output for readiness checks. Its `aws_ec2`
dynamic inventory can group on these generic AWS tags:

- `Function`: supplied by `all_systems[*].tags.Function`
- `Environment`: supplied by `var.environment`
- `OS`: derived from the selected AMI data source
- `ManagedBy`: set by this framework to `Terraform`

Ansible owns connection variables, login users, shell settings, and grouping.
This module only prepares the EC2 systems and emits infrastructure facts.

## Gate readiness before Ansible

This module gates instance readiness before configuration management. On
`terraform apply`, `terraform_data.readiness_gate` runs a per-instance
`remote-exec` probe for each directly reached system with the gate enabled. It
first waits for the selected direct transport with Terraform's 10-minute
connection timeout, then runs the OS-native launch-agent wait:
`cloud-init status --wait` on Linux and
`"C:\Program Files\Amazon\EC2Launch\EC2Launch.exe" status -b` on Windows.
The Terraform step does not complete, and its duration captures the wait, until
each gated instance is provisioned and reachable. SSM-tunnelled systems must
disable the gate because this module does not establish a tunnel for
`remote-exec`.

SSH authenticates with the instance key pair using each system's
`readiness_private_key_path`; the Windows SSH bootstrap installs its matching
public key for Administrator. WinRM asks AWS for the encrypted Administrator
password and decrypts it with that same private key. Leave the path null for
plan and CI; a real apply must give every gated system a readable path.

## Treat the key pair as the readiness credential

`key_name` is required for every `all_systems` entry. It names the EC2 key pair
whose private key the controller uses directly for SSH readiness or uses to
decrypt the Windows launch password for WinRM. The Windows SSH bootstrap
installs that key pair's public key for Administrator at first boot.

The login user and Ansible inventory variables stay in the separate pipeline
job.

The EC2 resources set `user_data_replace_on_change = true`. Changing a platform
or transport bootstrap later forces instance replacement so the boot payload
actually runs.

## Manage EBS data volumes

`ebs_block_devices` entries become standalone `aws_ebs_volume` resources and
`aws_volume_attachment` attachments. Their lifecycle is independent from an
individual EC2 instance, so a data volume can survive instance replacement.
The volume remains owned by Terraform and deletes when the deployment is
destroyed.

Give every data volume a unique, durable `resource_key` and `device_index`.
Terraform addresses the volume and attachment as
`<hostname>-ebs-<resource_key>`, while `device_index` 0 through 22 selects the
stable `sdd`/`xvdd` through `sdz`/`xvdz` device name. Do not change either value
during the volume's lifetime. List order has no effect on either identity.

When upgrading an existing deployment, set each volume's `resource_key` to its
former zero-based list index as a string (for example, `"0"` or `"1"`) and set
`device_index` to that same integer. This preserves both the existing Terraform
resource address and device name while making later list edits safe.

To adopt a descriptive key instead, move both existing state addresses before
planning. The attachment destination is now always `aws_volume_attachment.us_east_1`:

For `refresh = true`, run the consolidation move below first, then these descriptive-key moves;
the attachment rename source exists only after consolidation. For `refresh = false`, the order
does not matter because attachments do not move between resources.

```console
terraform -chdir=terraform state mv \
  'aws_ebs_volume.us_east_1["HOSTNAME-ebs-0"]' \
  'aws_ebs_volume.us_east_1["HOSTNAME-ebs-data"]'
terraform -chdir=terraform state mv \
  'aws_volume_attachment.us_east_1["HOSTNAME-ebs-0"]' \
  'aws_volume_attachment.us_east_1["HOSTNAME-ebs-data"]'
```

This release consolidates refresh and stable attachments into that one resource. For every
affected state and every attachment on a `refresh = true` system, move its unchanged key before
applying the new configuration:

```console
terraform -chdir=terraform state mv \
  'aws_volume_attachment.us_east_1_refresh["KEY"]' \
  'aws_volume_attachment.us_east_1["KEY"]'
```

Run `terraform plan` after every migration and verify that it plans no EBS volume detach or
reattachment.

AMI-defined non-root devices use a separate path. Add each such mapping to
`ami_block_device_overrides` with the exact `device_name` from the AMI. The
framework then renders an encrypted inline `ebs_block_device` that replaces the
AMI mapping at launch. Do not copy the AMI's `snapshot_id` into the override;
the AMI mapping supplies it. Inline override volumes always delete with their
instance. Use `ami_block_device_overrides = []` only when the AMI defines no
device beyond its root mapping.

`skip_destroy` is module-owned and fixed to `false`, so destroying an attachment
really detaches it before Terraform destroys the external volume.

All data-volume attachments use `stop_instance_before_detaching = true`.
Removing or replacing a data volume on a running instance stops the instance
before detach to avoid `VolumeInUse` failures and force-detach corruption. This
stop is not obvious in the plan. Do not rely on a simultaneous
`set_state = "running"` transition to restart it: this tree has no ordering edge
from external attachment changes to the instance-state resource.

When upgrading a configuration from the older consumer-controlled lifecycle
surface, remove these attributes before planning with this version:

- `root_block_device.delete_on_termination`
- `ami_block_device_overrides[*].delete_on_termination`
- `ebs_block_devices[*].skip_destroy`

## Non-goals

These responsibilities stay outside this repository:

- Long-term Windows or Linux management orchestration.
- Ansible execution.
- Controller IAM for the Ansible job.
- Networking, NAT, VPC endpoints, and general-purpose shared/cross-system
  security groups beyond the optional run-scoped readiness group.
- IAM role, policy, and instance-profile creation.
- OS hostname setting.
