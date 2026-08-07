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
- **Terraform to remote state.** The module declares an S3 backend, but the
  bucket, locking, encryption, and access policy are consumer-owned.

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
- **Spoofed SSH readiness target.** Accepted posture: no `host_key` is pinned
  because the instance host key is generated at first boot and is not retrievable
  through the provider. The gate trusts the first host answering at the private
  IP; public-key authentication prevents capture of the launch key, and the
  channel carries only the launch-agent wait command.

## Out Of Scope

What this module does **not** guarantee:

- It does not create VPCs, subnets, shared or cross-system security groups, KMS
  aliases, key pairs, IAM roles, OIDC trust policies, or backend buckets. The
  only groups it creates are per-interface `<hostname>-eni-<index>-sg` groups.
- It does not prove that a live AWS account has the referenced AMIs, KMS aliases,
  key pairs, subnets, or security groups.
- It does not verify that a supplied `device_name` matches the AMI's spelling
  beyond exact string equality.
- It does not harden operating systems, databases, application workloads, or
  network policy beyond the Terraform resources it declares.
- It does not distribute database credentials to applications.
- It does not decide whether publishing environment-specific IaC is acceptable;
  that portfolio decision is tracked separately.

Cross-reference: `SECURITY.md` in the org control plane defines the reporting
channel and org-wide scope boundary.
