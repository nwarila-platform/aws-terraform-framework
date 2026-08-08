# Testing Strategy

## What The Tests Cover

`terraform test` runs with mocked AWS providers, so the tests exercise Terraform
configuration behavior without making AWS API calls.

- `terraform/tests/load_balancers.tftest.hcl` verifies that load balancers are
  bucketed into the supported region, inherit the environment tag, preserve
  subnet or subnet-mapping shape, and plan with the expected load-balancer type.
- `terraform/tests/inline_security_groups.tftest.hcl` verifies interface-owned
  group creation and attachment, null-versus-empty-list semantics, positional
  ENI re-keying, and rejection of unsafe ingress, all-protocol port ranges, and
  invalid group inputs.
- `terraform/tests/firewall_rules.tftest.hcl` verifies content-derived rule
  identity keys, key stability after front insertion, collision-free scaling,
  and authored ordering for derived and pre-created groups.
- `terraform/tests/systems.tftest.hcl` verifies that EC2 instance-state
  resources are created only for systems that explicitly set `set_state`, and
  that hyphenated and underscored east-region inputs normalize to the same regional
  bucket. It also asserts the module-owned encryption and IMDSv2 hardcodes.
- `terraform/tests/managed.tftest.hcl` verifies that a system referencing only
  pre-existing infrastructure creates nothing extra, that a zero-inbound interface
  still reaches SSM over egress, and that a literal subnet plans its Elastic IP and
  association.
- `terraform/tests/ami_mapping_coverage.tftest.hcl` verifies that an AMI-defined
  non-root block-device mapping left out of `ami_block_device_overrides` fails the
  instance precondition rather than launching unencrypted.
- `terraform/tests/ami_block_device_overrides.tftest.hcl` verifies empty, normal,
  and refresh override rendering and rejects standalone-volume collisions and
  duplicate device names.
- `terraform/tests/tagging.tftest.hcl` verifies framework tag-set completeness,
  deployment metadata validation, and reserved-key rejection across supported tag maps.
- `terraform/tests/outputs.tftest.hcl` verifies the `ebs_volumes` output keys and
  metadata shape, including volumes without a `Function` tag.
- `terraform/tests/validation_coverage.tftest.hcl` provides 15 negative runs for
  previously uncovered repository metadata and load-balancer variable validations.
- `make ci` also runs formatting, `terraform init`, validation, TFLint,
  terraform-docs drift detection, documentation layout checks, and the
  bidirectional deny-all `.gitignore` allowlist guard.

## What The Tests Do Not Cover

- They do not apply resources to a live AWS account.
- They do not prove the referenced AMIs, KMS aliases, key pairs, subnets, or
  security groups exist in a consumer account.
- They do not yet cover every validation block in `terraform/variables.tf`.
- They do not test remote state locking, OIDC role assumption, or backend
  encryption because those are consumer-owned deployment concerns.

## Required Expansion

New resource families should add at least one mocked positive plan test and one
negative validation test for the public variables they introduce. The framework
ships mocked `terraform test` gates only; live plan/apply/destroy verification is
owned by each consumer repo. Module-owned security
invariants should be hard-coded and asserted in those native tests; consumer
policy evaluation remains outside this repository.
