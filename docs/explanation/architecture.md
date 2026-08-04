# Architecture

## Module Boundary

This repository is a Terraform framework module for a pre-existing AWS account
and network. It owns the transformation from typed resource inventory into AWS
resources. It does not own account bootstrap, networking, IAM, OIDC, remote
state, or KMS alias creation. Key pairs and interface-owned security groups stay
inside the framework because they support instances directly. Subnets arrive as
literal references or through `network_aliases`.

The module currently declares:

- EC2 instances and optional EC2 instance-state resources.
- Elastic network interfaces attached to those instances.
- Interface-owned security groups and their granular rules.
- Optional managed EC2 key pairs.
- Elastic IPs and their associations.
- EBS volumes and volume attachments.
- RDS database instances.
- Application or network load balancers.
- `terraform_data.refresh` triggers for replace-driven refresh workflows.

## Two Root Modules

`terraform/` is the framework root. `overlays/` is a companion root for one
throwaway public network per map entry. They have exact-matching tool and
provider pins but separate backends, lock lifecycles, and state files.

The seam is the overlays root's `network_aliases` output and the framework
root's input of the same name. Apply the overlay first, export and validate the
alias map, and then apply the framework. Destroy in reverse: framework first,
overlay second. Because the framework no longer owns gateways or routes, it
cannot prove at plan time that a caller-supplied subnet is internet-routable.

## Inputs And Locals

Consumers provide inventory through `all_systems`, `all_databases`, and
`all_load_balancers`. The module supports only `us_east_1` and normalizes its
hyphenated AWS name and underscored Terraform map key before building local maps
under `elastic_compute_cloud`, `elastic_network_interfaces`,
`ebs_block_devices`, `relational_database_service`, and
`elastic_load_balancers`.

Provider aliases are static, so adding another region is a code change across
providers, data lookups, locals, resources, outputs, and tests rather than an
`aws_config` variable-only change.

That local-map layer is the module's contract boundary: resources should read
from normalized locals rather than reimplementing input parsing in each
resource block.

## Outputs

Outputs expose stable, non-secret load-balancer attributes keyed by
`all_load_balancers.resource_key`. Database passwords and EC2 password data are
not exposed as outputs.

Generated input, resource, and output reference material lives in
`docs/reference/terraform.md` and `docs/reference/overlays.md`.

## External Dependencies

- `registry.terraform.io` supplies the exact-pinned AWS provider.
- AWS APIs supply AMI, KMS alias, and key-pair data sources plus all managed
  resources.
- A consumer-owned S3 backend stores state when this module is used for real
  deployment.
- GitHub Actions supplies the CI runner and read-only validation token.
