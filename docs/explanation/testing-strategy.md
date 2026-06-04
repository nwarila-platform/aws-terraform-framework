# Testing Strategy

## What The Tests Cover

`terraform test` runs with mocked AWS providers, so the tests exercise Terraform
configuration behavior without making AWS API calls.

- `terraform/tests/load_balancers.tftest.hcl` verifies that load balancers are
  bucketed into the correct region, inherit the environment tag, preserve
  subnet or subnet-mapping shape, and plan with the expected load-balancer type.
- `terraform/tests/systems.tftest.hcl` verifies that EC2 instance-state
  resources are created only for systems that explicitly set `set_state`, and
  that hyphenated and underscored region inputs normalize to the same regional
  bucket.
- `make ci` also runs formatting, `terraform init`, validation, TFLint,
  terraform-docs drift detection, documentation layout checks, and the OPA
  target.

## What The Tests Do Not Cover

- They do not apply resources to a live AWS account.
- They do not prove the referenced AMIs, KMS aliases, key pairs, subnets, or
  security groups exist in a consumer account.
- They do not yet cover every validation block in `12-variables-aws.tf`.
- They do not test remote state locking, OIDC role assumption, or backend
  encryption because those are consumer-owned deployment concerns.

## Required Expansion

New resource families should add at least one mocked positive plan test and one
negative validation test for the public variables they introduce. A future live
integration stage, if added, must run in a non-production AWS account with
short-lived credentials and a disposable backend.
