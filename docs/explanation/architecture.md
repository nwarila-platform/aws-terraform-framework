# Architecture

## Module Boundary

This repository is a Terraform framework module for a pre-existing AWS account
and network. It owns the transformation from typed resource inventory into AWS
resources. It does not own account bootstrap, networking, IAM, OIDC, remote
state, key-pair creation, or KMS alias creation.

The module currently declares:

- EC2 instances and optional EC2 instance-state resources.
- Elastic network interfaces attached to those instances.
- EBS volumes and volume attachments.
- RDS database instances.
- Application or network load balancers.
- `terraform_data.refresh` triggers for replace-driven refresh workflows.

## Inputs And Locals

Consumers provide inventory through `all_systems`, `all_databases`, and
`all_load_balancers`. The module normalizes region strings by accepting both
hyphenated AWS names and underscored Terraform map keys, then builds local maps
under `elastic_compute_cloud`, `elastic_network_interfaces`,
`ebs_block_devices`, `relational_database_service`, and
`elastic_load_balancers`.

That local-map layer is the module's contract boundary: resources should read
from normalized locals rather than reimplementing input parsing in each
resource block.

## Outputs

Outputs expose stable, non-secret load-balancer attributes keyed by
`all_load_balancers.resource_key`. Database passwords and EC2 password data are
not exposed as outputs.

Generated input, resource, and output reference material lives in
`docs/reference/terraform.md`.

## External Dependencies

- `registry.terraform.io` supplies the exact-pinned AWS provider.
- AWS APIs supply AMI, KMS alias, and key-pair data sources plus all managed
  resources.
- A consumer-owned S3 backend stores state when this module is used for real
  deployment.
- GitHub Actions supplies the CI runner and read-only validation token.
