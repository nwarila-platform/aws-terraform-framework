# Threat Model

This threat model covers the Terraform module in this repository. It focuses on
the code path from tracked Terraform source, through local or CI validation, to a
consumer-owned AWS account.

## Scope

What this module guarantees:

- Terraform and the AWS provider are exact-pinned in `terraform/00-providers.tf`,
  with provider checksums recorded in `terraform/.terraform.lock.hcl`.
- EC2 instances, network interfaces, EBS volumes and attachments, EC2 instance
  state resources, RDS database instances, load balancers, and refresh trigger
  resources are derived from typed variables under `terraform/10-variables.tf`
  and `terraform/12-variables-aws.tf`.
- Region input accepts the configured commercial region keys (`us-east-1` and
  `us-west-2`) in either hyphenated or underscored form and normalizes them
  before resources are bucketed.
- EBS volumes and RDS storage are always encrypted; callers provide the KMS alias
  used to resolve the final key ARN.
- RDS passwords are normalized through `sensitive()` before they flow into
  `aws_db_instance` resources. Callers are still responsible for supplying those
  values through a sensitive variable source, not checked-in tfvars.
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
  backend configuration, network IDs, key pairs, KMS aliases, and database
  passwords. Those operational controls live outside this module.
- **Terraform to remote state.** The module declares an S3 backend, but the
  bucket, locking, encryption, and access policy are consumer-owned.

## Threats And Mitigations

- **Provider substitution or checksum drift.** Mitigation: exact provider pins
  plus the committed multi-platform lock file make provider changes reviewable.
- **Credential or state disclosure.** Mitigation: deny-all `.gitignore` keeps
  state, local `.terraform/`, and unallowlisted tfvars out of version control.
  RDS passwords are marked sensitive at the local/resource boundary.
- **Unexpected EC2 power-state changes.** Mitigation: `aws_ec2_instance_state`
  resources are created only when an instance explicitly sets `set_state`.
- **Unencrypted block or database storage.** Mitigation: EBS and RDS resources
  set encryption in the module and resolve KMS aliases per region.
- **Region mis-bucketing.** Mitigation: tests cover hyphenated and underscored
  region inputs, and locals normalize keys before building regional maps.

## Out Of Scope

What this module does **not** guarantee:

- It does not create VPCs, subnets, security groups, KMS aliases, key pairs,
  IAM roles, OIDC trust policies, or backend buckets.
- It does not prove that a live AWS account has the referenced AMIs, KMS aliases,
  key pairs, subnets, or security groups.
- It does not harden operating systems, databases, application workloads, or
  network policy beyond the Terraform resources it declares.
- It does not rotate database passwords or own secret distribution.
- It does not decide whether publishing environment-specific IaC is acceptable;
  that portfolio decision is tracked separately.

Cross-reference: `SECURITY.md` in the org control plane defines the reporting
channel and org-wide scope boundary.
