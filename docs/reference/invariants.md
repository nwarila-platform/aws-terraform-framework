# Invariants

Non-negotiable rules for this module. Violating one of these is a breaking
change at minimum.

- Terraform Core and provider versions MUST remain exact-pinned.
- `terraform/.terraform.lock.hcl` MUST be committed with checksums for the
  supported contributor and CI platforms.
- `aws_config.regions` MUST remain exactly `["us_east_1"]`; adding a region is
  a code change, not a consumer configuration change.
- Region bucketing MUST continue to accept both hyphenated (`us-east-1`) and
  underscored (`us_east_1`) spellings for the supported commercial region.
- Every EC2, shared-EBS, and RDS `aws_kms_alias` is authored as a suffix. The
  framework MUST add the `alias/` prefix exactly once, so an authored prefix
  MUST fail. AWS and the provider own the resulting alias grammar.
- Resource keys used in outputs MUST remain stable across patch versions.
- Tag-count quotas for EC2-family, shared-EBS, RDS, and ELBv2 resources MUST
  remain owned by the provider and AWS. The framework MUST pass rendered tag
  maps through without raw or rendered count validation.
- `run_id` MUST remain the numeric GitHub Actions run identity. Its verbatim
  value is merged into the framework-owned `RunId` tag.
- Framework-generated ELBv2 `Name` and identity/provenance tags MUST preserve
  their deterministic composition unchanged. Their tag spelling, length, and
  service validity belong to the provider and AWS.
- Authored `access_logs.bucket`, `connection_logs.bucket`, and
  `health_check_logs.bucket` values, along with
  `minimum_load_balancer_capacity.capacity_units` and
  `subnet_mapping.subnet_id`, are passed through unchanged; the pinned AWS
  provider owns their requiredness when the corresponding block exists.
- Authored target-group `port`, `protocol`, `vpc_id`, and `stickiness.type`
  values are passed through unchanged; the pinned AWS provider owns their
  requiredness for instance targets and non-null stickiness blocks.
- RDS master passwords MUST remain AWS-managed and MUST NOT flow through Terraform.
- Every RDS `region` and `aws_kms_alias` MUST be non-null because they feed
  regional bucketing and the exact KMS alias lookup set. Explicit null MUST
  fail at the variable boundary.
- Security invariants owned by this module MUST be hard-coded directly on
  resources wherever possible and covered by native Terraform test assertions.
- Terraform variable validations MUST be reserved for valid-typeable consumer
  settings that objectively deviate from the established security baseline and
  cannot be hard-coded.
- EC2 root and inline AMI-override volumes MUST delete with their instance.
  Standalone and shared external volumes MAY survive replacement of an attached
  instance, but their attachments MUST detach on destroy and the volumes MUST
  delete with the Terraform deployment. External detach MUST stop the instance
  first to reduce `VolumeInUse` and filesystem-corruption risk.
- Every EBS volume attached at EC2 launch MUST be encrypted. Root devices and
  standalone `ebs_block_devices` are module-encrypted; every non-root mapping
  inherited from an AMI MUST also appear in `ami_block_device_overrides` with
  the exact AMI device name so Terraform replaces the inherited mapping with an
  encrypted inline block. This explicit collision is necessary because an AMI
  mapping otherwise passes through `RunInstances` unchanged: the CIS RHEL 8
  STIG AMI (`ami-0ca8a2e788e4c5869`) launched its 40 GB `/dev/sdf` snapshot
  unencrypted even while `root_block_device.encrypted = true` encrypted
  `/dev/sda1`.
- Every standalone EBS `snapshot_id` MUST pass unchanged into the regional
  `aws_ebs_volume` and MUST NOT participate in its resource identity; source
  validity belongs to the provider and AWS.
- RDS storage MUST remain encrypted by default.
- Every RDS instance MUST be private (`publicly_accessible = false`); it is
  module-owned, not a consumer input.
- Managed security-group ingress rules MUST NOT accept world-open IPv4
  (`0.0.0.0/0`) sources; unrestricted egress remains supported. This framework
  is IPv4-only: a rule's source is one of `cidr_ipv4`, `prefix_list_id`, or
  `referenced_security_group_id`, and there is no `cidr_ipv6`.
  This binds `all_systems[*].network_interfaces[*].ingress`. Any new path that
  creates security-group rules MUST extend the ban rather than bypass it.
- Every network interface MUST receive at least one security group, from its own
  `security_groups` list or from its own non-null `ingress` and `egress`
  declarations. The validation and attachment MUST use the same per-interface
  predicate; diverging them lets AWS attach the VPC default (allow-all) group.
- Interface-owned security-group names MUST be compared case-insensitively
  within the normalized region. Variable validation cannot resolve the final
  VPC identity, so the guard is intentionally conservative within one region:
  case-variant names in different VPCs are still rejected even though EC2
  permits them.
- Interface-owned security-group names MUST be derived as
  `<hostname>-eni-<interface index>-sg`, using the network interface's raw
  zero-based position. Validation MUST apply the 255-character EC2 limit to each
  rendered name; index `0` leaves a 246-character hostname budget, while index
  `10` leaves 245.
- A run-scoped ingress rule's identity MUST include both its transport and its
  source address, so an identical runner and operator grant collapses to one AWS
  rule while distinct transports or addresses stay distinct. The operator grant
  keeps the wider transport set, which is what adds tcp/3389 when `debug_ip` is
  set.

- An interface-owned security group MUST attach only to its declaring interface.
  Its consumer tags MUST be the interface's `tags`. At creation, its description
  MUST be the interface's non-null `description` or the fixed
  `Managed by aws-terraform-framework.` fallback. Later interface-description
  edits MUST NOT update the group because its description forces replacement.
- Interface-owned security-group rule resource keys MUST be derived from
  direction, lowercased protocol spelling, port range, destination kind, and
  destination value, never list position. Descriptions MUST NOT affect rule
  identity. Exact duplicate keys fail during Terraform map construction without
  a variable validation that duplicates AWS permission checks.
- Standalone EBS volume resource keys MUST be derived from each volume's explicit
  `resource_key`, never list position. The key MUST be unique within its system
  and MUST remain unchanged for the life of the volume. List position controls
  only the calculated attachment `device_name`.
- An interface's own group MUST be appended after its explicit
  `security_groups` entries.
- Security groups that are not specific to one system, including groups shared
  across systems or interfaces, MUST be defined outside this framework.
  Cross-system reachability within interface-owned groups MUST be expressed with
  CIDR rules.
- This framework creates no networking. Every `all_systems[*].subnet_id` MUST be
  a literal `subnet-<identifier>` naming a subnet that already exists; it is read
  with `data.aws_subnet` and passed through unchanged. That lookup is the single
  source for the subnet's VPC, CIDR, and availability zone - none of which the
  consumer restates.
- A system's `availability_zone` MUST equal its subnet's real zone, and a pinned
  `private_ip` and every `additional_private_ips` entry MUST fall inside the
  subnet's real CIDR and clear the five addresses AWS reserves in every subnet.
  These data-dependent checks are network-interface preconditions rather than
  variable validations, because a variable validation runs before any data
  source is read.
- Exact authored `[subnet_id, address]` pairs, drawn from `private_ip` and every
  `additional_private_ips` entry together, MUST be unique. Neither two
  interfaces nor one interface can claim the same explicit address twice.
- An interface MAY carry further private IPv4 addresses through
  `additional_private_ips`. Null and `[]` are both its off switch and MUST leave
  the pre-existing single-address provider shape unchanged. A non-empty list
  MUST also pin `private_ip`; the framework MUST send the primary followed by
  every further address through ordered `private_ip_list`, with
  `private_ip_list_enabled = true`, and MUST verify after apply that the authored
  primary and complete address set reached the interface.
- Key pairs are consumed, never created: every `key_name` MUST name a key pair
  that already exists in the account.
- Every RDS database MUST attach at least one explicitly supplied VPC security
  group instead of falling back to the VPC default security group.
- `aws_ec2_instance_state` resources MUST be created only when a system
  explicitly sets `set_state`.
- Generated Terraform docs MUST be produced by the pinned `terraform-docs`
  version and pass `make docs-diff`.
- Local state, `.terraform/`, tfvars containing real values, and credentials
  MUST stay untracked.
