# Invariants

Non-negotiable rules for this module. Violating one of these is a breaking
change at minimum.

- Terraform Core and provider versions MUST remain exact-pinned.
- `terraform/.terraform.lock.hcl` MUST be committed with checksums for the
  supported contributor and CI platforms.
- Region bucketing MUST continue to accept both hyphenated (`us-west-2`) and
  underscored (`us_west_2`) spellings for the supported commercial regions.
- Resource keys used in outputs MUST remain stable across patch versions.
- RDS passwords and other secret inputs MUST NOT be emitted through outputs.
- EBS volumes and RDS storage MUST remain encrypted by default.
- `aws_ec2_instance_state` resources MUST be created only when a system
  explicitly sets `set_state`.
- Generated Terraform docs MUST be produced by the pinned `terraform-docs`
  version and pass `make docs-diff`.
- Local state, `.terraform/`, tfvars containing real values, and credentials
  MUST stay untracked.
