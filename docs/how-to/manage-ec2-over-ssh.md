# Manage EC2 over SSH

Use this guide when adding Linux or Windows EC2 instances that will be managed
by a separate Ansible pipeline over SSH.

## Operating model

SSH on TCP 22 is the only management transport for EC2 instances created by this
framework. Do not use WinRM for normal management. Ansible runs outside this
repository, in a separate pipeline job, using the default `ssh` connection.

This repository stops at creating SSH-reachable instances and emitting a
non-secret inventory hand-off. It does not run Ansible, poll instance readiness,
create IAM roles, create networking, or create security group rules.

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
    ansible_group        = "app"
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

Bake the SSH server into the golden image before this framework launches
instances. Windows images must include OpenSSH Server. That image build happens
outside this repository. The framework's `user_data` only enables and starts the
service at boot:

- Linux: `systemctl enable --now sshd`
- Windows: `Set-Service -Name sshd -StartupType Automatic` and
  `Start-Service -Name sshd`

Runtime verification is also outside this repository. The pipeline should check
that each emitted SSH target is reachable before it runs Ansible.

Windows systems may use `windows_server_2022_base` or
`windows_server_2025_base`. Prefer `windows_server_2025_base` for new
deployments; Windows Server 2022 mainstream support ends on 2026-10-13. Set the
allowed Windows AMI owner accounts with `var.windows_ami_owners`.

The owner must confirm the Windows Server 2025 golden-image `name_regex` matches
the published image names:

```hcl
^TPM-Windows_Server-2025-English-Full-Base-[\d.]+$
```

This module validates Windows hostnames for NetBIOS compatibility, including
the 15-character limit, but it does not set OS hostnames. Hostname setting
belongs in the Ansible job.

## Open SSH from the controller

Attach consumer-supplied security groups through each network interface. The
framework references those security groups and does not create security group
rules.

Use this network posture:

- Allow inbound TCP 22 from the management or controller source.
- Ensure private subnet instances are reachable from the Ansible controller
  through routing, VPN, a bastion path, or another consumer-managed path.
- RDP on 3389 and WinRM on 5985 or 5986 remain consumer opt-in and are not the
  management path for this framework.

## Hand off inventory to Ansible

After apply, read the `aws_instances` output. It is keyed by hostname and
contains only non-secret values:

- `hostname`: the map key repeated as a fact.
- `instance_id`: the EC2 instance ID.
- `region`: the normalized framework region key.
- `private_ip`: the primary private IP from the framework-owned
  `<hostname>-eni-0` network interface.
- `private_dns`: the EC2 private DNS name.
- `function`: supplied by `all_systems[*].tags.Function`.
- `ansible_group`: supplied by `all_systems[*].ansible_group`.
- `environment`: supplied by `var.environment`.
- `transport`: always `ssh`.
- `os_family`: `linux` or `windows`, derived from the selected AMI key.
- `ansible_host`: the primary private IP from the framework-owned
  `<hostname>-eni-0` network interface.
- `ansible_connection`: always `ssh`.
- `ansible_user`: `ec2-user` for Linux and `null` for Windows.
- `ansible_shell_type`: `powershell` for Windows and `null` for Linux.

The `private_ip`, `private_dns`, `instance_id`, and `ansible_host` values are
apply-known. They are included for hand-off and debugging, not for secret
distribution. Refresh instances use the same primary ENI naming pattern as
normal instances, so the output resolves their `<hostname>-eni-0` address from
the shared regional ENI map.

Example:

```sh
terraform -chdir=terraform output -json aws_instances
```

The Ansible pipeline can use the output for readiness checks. Its `aws_ec2`
dynamic inventory should group on these AWS tags:

- `Function`: supplied by `all_systems[*].tags.Function`
- `Environment`: supplied by `var.environment`
- `OS`: derived from the selected AMI data source
- `ManagedBy`: set by this framework to `Terraform`
- `AnsibleTransport`: set by this framework to `ssh`
- `AnsibleGroup`: supplied by `all_systems[*].ansible_group`

Set `ansible_group` on every system to the Ansible inventory group token the
separate pipeline should use. It must contain only letters, numbers, and
underscores, and it cannot start with a number. Hyphens and dots are rejected
because they are significant in Ansible group names.

The controller connects as `ansible_user` to `ansible_host` using the private
key for the EC2 key pair named by `key_name`. That private key stays on the
controller side and is outside this repository.

For Windows, `os_family=windows` and `ansible_shell_type=powershell` can drive
Ansible connection settings. The framework emits `ansible_user = null` for
Windows pending the owner's Windows-over-OpenSSH user decision. Windows
OpenSSH commonly uses `Administrator` with public keys in
`administrators_authorized_keys`, but that is a golden-image and pipeline
concern. Set the Windows user explicitly in the Ansible job.

## Gate readiness before Ansible

The pipeline should check TCP 22 reachability for each `ansible_host` before it
runs configuration management:

```sh
nc -vz "$ansible_host" 22
```

Continue only when every managed instance accepts SSH from the controller. This
repository intentionally does not add Terraform provisioners, `null_resource`
polling, or runtime readiness gates.

## Treat the key pair as the management credential

`key_name` is required for every `all_systems` entry. It names the EC2 key pair
whose private key the controller uses to authenticate as `ec2-user` for Linux
instances.

The EC2 resources set `user_data_replace_on_change = true`. Adopting this SSH
service bootstrap or changing it later forces instance replacement so the boot
payload actually runs.

## Non-goals

These responsibilities stay outside this repository:

- Non-SSH management transports, including WinRM.
- Ansible execution.
- Controller IAM for the Ansible job.
- Networking, NAT, VPC endpoints, and security group rule creation.
- IAM role, policy, and instance-profile creation.
- Runtime readiness polling.
- OS hostname setting.
