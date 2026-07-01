# Manage EC2 over SSH

Use this guide when adding Linux or Windows EC2 instances that will be managed
by a separate Ansible pipeline over SSH.

## Operating model

SSH on TCP 22 is the supported management path for EC2 instances created by this
framework. Windows readiness uses an in-box WinRM HTTPS shim on TCP 5986 before
configuration management, but normal management still belongs to SSH. Ansible
runs outside this repository, in a separate pipeline job, using its own SSH
configuration.

This repository stops at creating reachable instances, gating initial readiness,
and emitting a non-secret inventory hand-off. It does not run Ansible, create IAM
roles, create networking, or create security group rules.

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
    region               = "us_west_2"
    hostname             = "app01"
    availability_zone    = "us-west-2a"
    subnet_id            = "subnet-0123456789abcdef0"
    key_name             = "app-ssh-key"
    iam_instance_profile = "ec2-base-profile"
    aws_kms_alias        = "ebs-default"

    tags = {
      Function = "app"
    }

    network_interfaces = [
      {
        private_ip      = "10.0.1.10"
        security_groups = ["sg-0123456789abcdef0"]
      }
    ]
  }
]
```

## Use SSH-ready images

Linux images must include an SSH server before this framework launches
instances. The framework's Linux `user_data` only enables and starts the service
at boot:

```sh
systemctl enable --now sshd
```

Self-built AMIs can be selected by family name, such as `ttc-rhel8`, or by a
version pin, such as `ttc-rhel8:8.10`. The framework resolves those against
self-owned AMI names matching `<family>_v*` or `<family>_v<version>_*` with
`most_recent = true`; latest means most recently built, not highest semantic
version. A direct `ami-...` ID remains an exact pin.

Windows systems may use `windows_server_2022_base` or
`windows_server_2025_base`. The framework resolves those keys to the public
Amazon Windows Server 2022/2025 Base AMIs. Windows `user_data` installs the
OpenSSH Server capability, sets `sshd` to start automatically, starts the
service, bootstraps the launch key into
`C:\ProgramData\ssh\administrators_authorized_keys`, locks down that file's
ACLs, and leaves the OpenSSH default shell as cmd.

Runtime verification is also outside this repository. The pipeline should check
that each emitted SSH target is reachable before it runs Ansible.

Prefer `windows_server_2025_base` for new deployments; Windows Server 2022
mainstream support ends on 2026-10-13. Set `var.windows_ami_owners` only when
mirroring the public Amazon Windows Server Base AMIs into another account.

Windows OpenSSH capability installation pulls from Windows Update at first boot.
Windows instances therefore need egress, such as a public subnet or NAT path,
for their initial boot. Air-gapped or NAT-less private subnets need a pre-baked
Windows image with OpenSSH Server already installed.

This module validates Windows hostnames for NetBIOS compatibility, including
the 15-character limit, but it does not set OS hostnames. Hostname setting
belongs in the Ansible job.

## Open SSH from the controller

Attach consumer-supplied security groups through each network interface. The
framework references those security groups and does not create security group
rules.

Use this network posture:

- Allow inbound TCP 22 from the management or controller source.
- Allow inbound TCP 5986 from the Terraform apply host for Windows readiness.
- Ensure private subnet instances are reachable from the Ansible controller
  through routing, VPN, a bastion path, or another consumer-managed path.
- RDP on 3389 and WinRM on 5985 remain consumer opt-in and are not the
  management path for this framework.

## Hand off inventory

After apply, read the `aws_instances` output. It is keyed by hostname and
contains only neutral, non-secret values:

- `hostname`: the map key repeated as an inventory fact.
- `instance_id`: the EC2 instance ID.
- `region`: the normalized framework region key.
- `private_ip`: the primary private IP from the framework-owned
  `<hostname>-eni-0` network interface.
- `private_dns`: the EC2 private DNS name.
- `function`: supplied by `all_systems[*].tags.Function`.
- `os_family`: `linux` or `windows`, derived from the resolved AMI `platform`.
- `environment`: supplied by `var.environment`.

The `private_ip`, `private_dns`, and `instance_id` values are apply-known. They
are included for hand-off and debugging, not for secret distribution. Refresh
instances use the same primary ENI naming pattern as normal instances, so the
output resolves their `<hostname>-eni-0` address from the shared regional ENI
map.

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
`remote-exec` probe that first waits for the readiness transport (SSH on Linux,
WinRM on Windows) with Terraform's 10-minute connection timeout, then runs the
OS-native launch-agent wait:
`cloud-init status --wait` on Linux and
`"C:\Program Files\Amazon\EC2Launch\EC2Launch.exe" status -b` on Windows.
The Terraform step does not complete, and its duration captures the wait, until
each instance is provisioned and reachable.

The dormant Windows OpenSSH bootstrap intentionally uses its built-in cmd
default shell so Terraform's `remote-exec` SCP upload will work if that SSH path
is reactivated. Ansible sets its own shell in the separate
configuration-management pipeline.

Linux readiness authenticates with the instance key pair using
`var.ssh_readiness_private_key_paths`. Windows readiness uses the same map to
decrypt the launch Administrator password for WinRM. Leave the map empty for
plan and CI; a real apply must populate a filesystem path for every `key_name`
in use.

## Treat the key pair as the management credential

`key_name` is required for every `all_systems` entry. It names the EC2 key pair
whose private key the controller uses for SSH authentication. On Windows, the
same launch key is installed for administrator SSH access through the
`user_data` IMDS bootstrap:

```sh
ssh -i <key_name>.pem administrator@<private_ip>
```

The login user and Ansible inventory variables stay in the separate pipeline
job.

The EC2 resources set `user_data_replace_on_change = true`. Adopting this SSH
service bootstrap or changing it later forces instance replacement so the boot
payload actually runs.

## Non-goals

These responsibilities stay outside this repository:

- Non-SSH management methods, including WinRM beyond the Windows readiness shim.
- Ansible execution.
- Controller IAM for the Ansible job.
- Networking, NAT, VPC endpoints, and security group rule creation.
- IAM role, policy, and instance-profile creation.
- OS hostname setting.
