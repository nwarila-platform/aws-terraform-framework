# Threat Model

This threat model covers the Terraform module in this repository. It focuses on
the code path from tracked Terraform source, through local or CI validation, to a
consumer-owned AWS account.

## Scope

What this module guarantees:

- Terraform and the AWS provider are exact-pinned in `terraform/versions.tf`,
  with provider checksums recorded in `terraform/.terraform.lock.hcl`.
- EC2 instances, network interfaces, EBS volumes and attachments, Elastic IPs
  and their associations, EC2 instance state resources, RDS database instances,
  load balancers, and refresh trigger resources are derived from typed variables
  under `terraform/variables.tf`.
- Interface-owned security groups and their ingress and egress rules are created
  only when an interface sets both `ingress` and `egress` to non-null values.
- Region input accepts the supported commercial region in either hyphenated
  (`us-east-1`) or underscored (`us_east_1`) form and normalizes it before
  resources are bucketed. `aws_config` rejects every non-singleton region set.
- EC2 root volumes, standalone EBS volumes, and RDS storage are always encrypted;
  callers provide the KMS alias used to resolve the final key ARN. Callers must
  explicitly list every non-root AMI-defined mapping in
  `ami_block_device_overrides`; the module renders those mappings as encrypted
  inline blocks, and a plan-time precondition rejects any non-root mapping the
  AMI declares that `ami_block_device_overrides` does not cover.
- RDS master passwords are generated and managed by AWS. The module does not
  accept plaintext master passwords, and RDS encrypts its Secrets Manager secret
  with the consumer-selected KMS key.
- EC2 root and inline AMI-override volumes delete with their instance.
  Standalone and shared external EBS volumes can survive replacement of an
  attached instance, but their attachments detach and their volumes delete when
  the Terraform deployment is destroyed.
- Local and CI validation run without live AWS credentials by using Terraform's
  mock-provider test support.

## Trust Boundaries

- **Repository to CI runner.** GitHub Actions checks out this repository and runs
  `make ci` with pinned tooling. The workflow token is read-only for validation.
- **Terraform to AWS provider registry.** `terraform init` downloads
  `hashicorp/aws` and verifies the selected artifact against the committed lock
  file.
- **Consumer inputs to module locals.** Resource inventory enters through
  Terraform variables. The module validates types and selected invariants, then
  builds region-keyed local maps before creating resources.
- **Consumer runner to AWS APIs.** A deployment runner supplies AWS credentials,
  backend configuration, network IDs, key pairs, and KMS aliases. Those
  operational controls live outside this module.
- **RDS to Secrets Manager.** When RDS manages the master password, AWS creates a
  Secrets Manager secret encrypted with the consumer-selected KMS key.
- **Terraform to remote state.** The framework enables request-side S3 encryption and
  S3-native lockfiles. Consumers own the bucket identity, KMS and bucket encryption
  policies, access policy, versioning, and recovery controls.

## Threats And Mitigations

- **Provider substitution or checksum drift.** Mitigation: exact provider pins
  plus the committed multi-platform lock file make provider changes reviewable.
- **Credential or state disclosure.** Mitigation: deny-all `.gitignore` keeps
  state, local `.terraform/`, and unallowlisted tfvars out of version control.
  Every RDS instance uses an AWS-managed master password. The module defines no
  plaintext password input or resource argument, so plans and state do not
  persist a master password.
- **Unexpected EC2 power-state changes.** Mitigation: `aws_ec2_instance_state`
  resources are created only when an instance explicitly sets `set_state`.
- **Unencrypted block or database storage.** Mitigation: root volumes,
  standalone EBS volumes, AMI block-device overrides, and RDS resources set
  encryption in the module and resolve KMS aliases per region. An AMI-defined
  non-root mapping omitted from `ami_block_device_overrides` fails the instance
  precondition at plan time rather than reaching `RunInstances`.
- **Over-broad ingress.** Mitigation:
  `all_systems[*].network_interfaces[*].ingress` rejects any `cidr_ipv4` with a
  `/0` prefix. Each interface-owned group attaches only to its declaring
  interface; unrestricted egress remains supported.
- **Region mis-bucketing.** Mitigation: tests cover hyphenated and underscored
  region inputs, and locals normalize keys before building regional maps.
- **Spoofed direct-readiness target.** Accepted posture: SSH pins no `host_key`
  because the instance host key is generated at first boot and is not
  retrievable through the provider; WinRM accepts the instance-generated
  self-signed TLS certificate. The gate trusts the first host answering at the
  private IP. SSH uses public-key authentication, and WinRM uses NTLM over
  HTTPS. The framework's default command waits for the launch agent; consumers
  may replace it through `readiness_command`. SSM-tunnelled systems cannot run
  this direct readiness gate.

## Out Of Scope

What this module does **not** guarantee:

- It does not create VPCs, subnets, general-purpose shared or cross-system
  security groups, KMS aliases, key pairs, IAM roles, OIDC trust policies, or
  backend buckets. It creates per-interface `<hostname>-eni-<index>-sg` groups
  and may create one narrowly scoped run ingress group when a runner or debug
  address and at least one directly reached system are present.
- It does not prove that a live AWS account has usable referenced AMIs, EBS
  snapshots, KMS aliases, key pairs, subnets, or security groups. The provider
  and AWS validate those references during live operations.
- It does not verify that a supplied `device_name` matches the AMI's spelling
  beyond exact string equality.
- It does not harden operating systems, databases, application workloads, or
  network policy beyond the Terraform resources it declares.
- It does not distribute database credentials to applications.
- It provides no general retention, backup, restore, or disaster-recovery
  guarantee. `Backup` tags can drive external automation while a resource
  exists, but do not themselves retain anything.
- It does not decide whether publishing environment-specific IaC is acceptable;
  that portfolio decision is tracked separately.

Cross-reference: `SECURITY.md` in the org control plane defines the reporting
channel and org-wide scope boundary.
