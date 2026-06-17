# Manage EC2 over SSM

Use this guide when adding Linux or Windows EC2 instances that will be managed
by a separate Ansible pipeline over AWS Systems Manager Session Manager.

## Operating model

SSM Session Manager is the only management transport for EC2 instances created
by this framework. Do not open SSH on port 22 or WinRM on ports 5985 or 5986 for
normal management. Ansible runs outside this repository, in a separate pipeline
job, using the `amazon.aws.aws_ssm` connection plugin.

This repository stops at creating SSM-manageable instances and emitting a
non-secret inventory hand-off. It does not run Ansible, poll instance readiness,
create IAM roles, create networking, or create the S3 transfer bucket used by
the Ansible connection plugin.

## Configure the instance profile

Set `iam_instance_profile` on every `all_systems` entry. The framework validates
that the named profile exists and attaches it to the EC2 instance, but it does
not create IAM roles, instance profiles, or policies.

The profile must include AWS managed policy `AmazonSSMManagedInstanceCore`. Add
KMS permissions only when the separate Ansible job's S3 transfer bucket uses
SSE-KMS. The instance does not need S3 IAM permissions for Ansible transfer
objects because the controller uses presigned URLs.

```hcl
all_systems = [
  {
    region               = "us_west_2"
    hostname             = "app01"
    availability_zone    = "us-west-2a"
    subnet_id            = "subnet-0123456789abcdef0"
    key_name             = "break-glass-key"
    iam_instance_profile = "ec2-ssm-core"
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

## Use SSM-ready images

Bake SSM Agent into the golden image before this framework launches instances.
That image build happens outside this repository. The framework's `user_data`
only enables and starts the service at boot:

- Linux: `systemctl enable --now amazon-ssm-agent`
- Windows: `Set-Service -Name AmazonSSMAgent -StartupType Automatic` and
  `Start-Service -Name AmazonSSMAgent`

Runtime verification is also outside this repository. The pipeline should wait
until SSM reports the emitted instance IDs online before it runs Ansible.

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

## Keep security groups SSM-only

Attach consumer-supplied security groups through each network interface. The
framework references those security groups and does not create security group
rules.

Use this network posture:

- No inbound management ports for SSH or WinRM.
- Egress TCP 443 to SSM service endpoints: `ssm`, `ssmmessages`,
  `ec2messages`, and `s3`.
- Private subnet instances must reach those services through NAT or VPC
  endpoints.
- Break-glass SSH on 22 or RDP on 3389 is a consumer opt-in only, outside the
  SSM-only management path.

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
- `transport`: always `ssm`.
- `os_family`: `linux` or `windows`, derived from the selected AMI key.
- `ansible_host`: the EC2 instance ID, which `amazon.aws.aws_ssm` targets.
- `ansible_connection`: always `amazon.aws.aws_ssm`.
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

The Ansible pipeline can use the output for readiness polling. Its `aws_ec2`
dynamic inventory should group on these AWS tags:

- `Function`: supplied by `all_systems[*].tags.Function`
- `Environment`: supplied by `var.environment`
- `OS`: derived from the selected AMI data source
- `ManagedBy`: set by this framework to `Terraform`
- `AnsibleTransport`: set by this framework to `ssm`
- `AnsibleGroup`: supplied by `all_systems[*].ansible_group`

Set `ansible_group` on every system to the Ansible inventory group token the
separate pipeline should use. It must contain only letters, numbers, and
underscores, and it cannot start with a number. Hyphens and dots are rejected
because they are significant in Ansible group names.

For Windows, `os_family=windows` and `ansible_shell_type=powershell` can drive
Ansible connection settings. Connection details for
`amazon.aws.aws_ssm`, including `bucket_name`, controller region, shell type,
and any transfer-bucket settings, live in the Ansible pipeline job.

## Gate readiness before Ansible

The pipeline should poll SSM for the emitted instance IDs before it runs
configuration management:

```sh
aws ssm describe-instance-information
```

Filter the result to the `instance_id` values from `aws_instances` and continue
only when each managed instance appears online. This repository intentionally
does not add Terraform provisioners, `null_resource` polling, or runtime
readiness gates.

## Keep the key pair in context

`key_name` remains required for every `all_systems` entry, but it has no
management function in the SSM-only model. Treat it as a latent break-glass
artifact.

The EC2 resources set `user_data_replace_on_change = true`. Adopting this SSM
service bootstrap or changing it later forces instance replacement so the boot
payload actually runs.

## Non-goals

These responsibilities stay outside this repository:

- SSH and WinRM management transports.
- Ansible execution.
- The `amazon.aws.aws_ssm` S3 transfer bucket.
- Controller IAM for the Ansible job.
- Networking, NAT, VPC endpoints, and security group rule creation.
- IAM role, policy, and instance-profile creation.
- Runtime readiness polling.
- OS hostname setting.
- Session Manager account preferences, including KMS session encryption and
  S3 or CloudWatch session logging.
