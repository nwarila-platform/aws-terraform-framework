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
- Resource keys used in outputs MUST remain stable across patch versions.
- RDS passwords and other secret inputs MUST NOT be emitted through outputs.
- Security invariants owned by this module MUST be hard-coded directly on
  resources wherever possible and covered by native Terraform test assertions.
- Terraform variable validations MUST be reserved for valid-typeable consumer
  settings that objectively deviate from the established security baseline and
  cannot be hard-coded.
- EBS volumes and RDS storage MUST remain encrypted by default.
- Managed security-group ingress rules MUST NOT accept world-open IPv4
  (`0.0.0.0/0`) or IPv6 (`::/0`) sources; unrestricted egress remains supported.
  This binds the inline `all_systems[*].managed_security_group`. Any new path
  that creates security-group rules MUST extend the ban rather than bypass it.
- Every network interface MUST receive at least one security group, from its own
  `security_groups` list or from its system's inline `managed_security_group`,
  which the framework attaches to EVERY interface of that system. The validation
  and the attachment MUST cover the same set of interfaces; narrowing one without
  the other lets AWS attach the VPC default (allow-all) group.
- Inline security-group names MUST be compared case-insensitively within the
  normalized region. Variable validation cannot resolve the final VPC identity,
  so the guard is intentionally conservative within one region: case-variant
  names in different VPCs are still rejected even though EC2 permits them.
- Inline security-group names MUST be derived as `<hostname>-sg-<index>`, where
  `index` is the raw zero-based position of the group within its system (the
  current singleton attribute therefore yields `0`). This matches the module's
  existing `<hostname>-<type>-<index>` keys for ENIs and EBS volumes. Validation
  MUST apply the 255-character EC2 limit to each rendered name; the current
  `-sg-0` suffix leaves a 250-character hostname budget, while a future index
  `10` would leave 249.
- Security groups that are not specific to one system, including groups shared
  across systems, MUST be defined outside this framework. Cross-system
  reachability within inline groups MUST be expressed with CIDR rules.
- Every RDS database MUST attach at least one explicitly supplied VPC security
  group instead of falling back to the VPC default security group.
- `aws_ec2_instance_state` resources MUST be created only when a system
  explicitly sets `set_state`.
- Generated Terraform docs MUST be produced by the pinned `terraform-docs`
  version and pass `make docs-diff`.
- Local state, `.terraform/`, tfvars containing real values, and credentials
  MUST stay untracked.
