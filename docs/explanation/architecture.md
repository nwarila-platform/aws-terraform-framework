# Architecture

## Module Boundary

This repository is a Terraform framework module for a pre-existing AWS account
and network. It owns the transformation from typed resource inventory into AWS
resources. It does not own account bootstrap, VPCs, subnets, routes, or
gateways, IAM, OIDC, remote state, key-pair creation, or KMS alias creation.

The module currently declares:

- Compute: stable and refresh `aws_instance` resources, optional
  `aws_ec2_instance_state` resources, and per-system `terraform_data.readiness_gate` resources.
- Network authorization: `aws_security_group`, `aws_vpc_security_group_ingress_rule`, and
  `aws_vpc_security_group_egress_rule` resources.
- Addressing: `aws_network_interface`, `aws_eip`, and `aws_eip_association` resources.
- Storage: one `aws_ebs_volume` resource and one `aws_volume_attachment` resource.
- Data: `aws_db_instance` resources.
- Routing: `aws_lb`, `aws_lb_target_group`, `aws_lb_target_group_attachment`,
  `aws_lb_listener`, `aws_lb_listener_rule`, and `aws_lb_listener_certificate` resources.
- Workflow: `terraform_data.refresh` triggers for replace-driven refresh workflows.

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

Non-root EBS storage has inline and external resource paths.
`ami_block_device_overrides` renders inline `aws_instance.ebs_block_device`
blocks for inherited AMI mappings. Standalone `ebs_block_devices` and
`shared_ebs_volumes` use the external `aws_ebs_volume` plus
`aws_volume_attachment` graph and may be combined with each other. This tree
does not validate the inline and external paths as mutually exclusive.

A standalone volume may start empty or from a supplied snapshot ID. The
authored value passes unchanged through the regional volume map to
`aws_ebs_volume`; the provider and AWS own source validation. It does not change
the volume or attachment identity, which remains derived from the host and
authored `resource_key`.

EC2 root and inline volumes delete with their instance. Standalone and shared
EBS volumes can survive replacement of an attached instance but delete with the
Terraform deployment. External attachments detach on destroy and ask Terraform
to stop the instance first.

## Outputs

Outputs expose `aws_instances`, the non-secret EC2 inventory that the configuration-management
hand-off consumes. Each hostname-keyed entry contains `hostname`, `instance_id`, `region`,
`private_ip`, `private_dns`, `function`, `os_family`, and `environment`. Outputs also expose
`ebs_volumes` and a family of stable load-balancer, target-group, and listener attributes keyed by
`all_load_balancers.resource_key`. Database passwords and EC2 password data are not exposed as
outputs.

Generated input, resource, and output reference material lives in
`docs/reference/terraform.md`.

## External Dependencies

- `registry.terraform.io` supplies the exact-pinned AWS provider.
- AWS APIs supply AMI, KMS alias, and key-pair data sources plus all managed
  resources.
- A consumer-owned S3 backend stores state when this module is used for real
  deployment.
- GitHub Actions supplies the CI runner and read-only validation token.
