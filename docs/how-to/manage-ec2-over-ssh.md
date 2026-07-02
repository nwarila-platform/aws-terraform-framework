# Manage EC2 with SSH and WinRM readiness

Use this guide when adding Linux EC2 instances that are reached over SSH, or
Windows EC2 instances whose Terraform readiness gate uses WinRM HTTPS before
hand-off to a separate configuration-management pipeline.

## Operating model

Linux readiness and management use SSH on TCP 22. Windows readiness uses an
in-box WinRM HTTPS listener on TCP 5986, configured at first boot by this
framework's Windows `user_data`. The repository does not configure a long-term
Windows management transport. Ansible runs outside this repository, in a
separate pipeline job, using its own connection settings.

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
    ami                  = "app-linux"

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

## Use readiness-ready images

Linux images must include an SSH server before this framework launches
instances. The framework's Linux `user_data` only enables and starts the service
at boot:

```sh
systemctl enable --now sshd
```

Self-built AMIs can be selected by family name, such as `app-linux`, or by a
version pin, such as `app-linux:8.10`. The framework resolves non-versioned
families against self-owned AMI names shaped `<family>_v<number>...`; version
pins resolve `<family>_v<version>_...`. In both cases `most_recent = true`;
latest means most recently built, not highest semantic version. A direct
`ami-...` ID remains an exact pin.

Windows systems may use `windows_server_2022_base` or
`windows_server_2025_base`. The framework resolves those keys to the public
Amazon Windows Server 2022/2025 Base AMIs. Windows `user_data` enables the
in-box WS-Management service, creates a self-signed HTTPS listener on TCP 5986,
enables NTLM authentication, disables Basic authentication, and disables
unencrypted WinRM traffic. It installs no SSH server, uses no
Feature-on-Demand payload, and requires no outbound egress for readiness.

Runtime verification beyond the Terraform readiness gate is outside this
repository. The pipeline should check that each emitted target is reachable
before it runs configuration management.

Prefer `windows_server_2025_base` for new deployments; Windows Server 2022
mainstream support ends on 2026-10-13. Set `var.windows_ami_owners` only when
mirroring the public Amazon Windows Server Base AMIs into another account.

This module validates Windows hostnames for NetBIOS compatibility, including
the 15-character limit, but it does not set OS hostnames. Hostname setting
belongs in the Ansible job.

## Open readiness access from the controller

Attach consumer-supplied security groups through each network interface. The
framework references those security groups and does not create security group
rules.

Use this network posture:

- Allow inbound TCP 22 from the Terraform apply host and management or
  controller source for Linux readiness and SSH management.
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

Linux readiness authenticates with the instance key pair using
`var.readiness_private_key_paths`. Windows readiness uses the same map to
decrypt the launch Administrator password with
`rsadecrypt(password_data, readiness_private_key_paths[key_name])`, then
connects to WinRM over HTTPS with NTLM. Leave the map empty for plan and CI; a
real apply must populate a filesystem path for every `key_name` in use.

## Treat the key pair as the readiness credential

`key_name` is required for every `all_systems` entry. On Linux, it names the EC2
key pair whose private key the controller uses for SSH readiness and later SSH
management. On Windows, the launch key decrypts the generated Administrator
password that EC2 returns as `password_data`; the active Windows `user_data`
does not install an SSH login key.

The login user and Ansible inventory variables stay in the separate pipeline
job.

The EC2 resources set `user_data_replace_on_change = true`. Changing the Linux
SSH bootstrap or the Windows WinRM bootstrap later forces instance replacement
so the boot payload actually runs.

## Manage EBS data volumes

`ebs_block_devices` entries become standalone `aws_ebs_volume` resources and
`aws_volume_attachment` attachments. Their lifecycle is independent from the
EC2 instance, so data volumes do not delete automatically when an instance is
terminated. That is why data-volume entries do not have
`delete_on_termination`; use `skip_destroy` instead.

`skip_destroy` defaults to `false`. With the default, Terraform detaches the
volume when destroying the attachment. When `skip_destroy = true`, Terraform
leaves the attachment in place while removing it from state.

All data-volume attachments use `stop_instance_before_detaching = true`.
Removing or replacing a data volume on a running instance stops the instance
before detach to avoid `VolumeInUse` failures and force-detach corruption. This
stop is not obvious in the plan, and the instance stays stopped unless the
system sets `set_state = "running"`.

If you are upgrading from an older configuration that set
`ebs_block_devices[*].delete_on_termination`, switch that setting to
`skip_destroy`; the old data-volume field is no longer part of the schema.

## Non-goals

These responsibilities stay outside this repository:

- Windows management methods beyond the WinRM readiness shim.
- Ansible execution.
- Controller IAM for the Ansible job.
- Networking, NAT, VPC endpoints, and security group rule creation.
- IAM role, policy, and instance-profile creation.
- OS hostname setting.
