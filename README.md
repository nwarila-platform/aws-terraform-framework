# aws-terraform-framework

Terraform framework for modeling AWS infrastructure in the configured
`us_east_1` and `us_west_2` regions. The module currently manages EC2
instances, network interfaces, EBS volumes and attachments, EC2 instance state,
RDS database instances, load balancers, and refresh trigger resources.

This repository is an infrastructure framework module, not a complete
deployment root by itself. Consumers still provide backend configuration,
credentials, account-specific network IDs, KMS aliases, key pairs, and resource
inventory through Terraform variables.

## Quickstart

Run the local quality gate before changing Terraform sources:

```shell
make ci
```

The CI path runs Terraform formatting, init, validation, tests, TFLint,
terraform-docs drift detection, documentation layout checks, and the repo's OPA
policy target.

## Documentation

- [Getting started](docs/how-to/develop-this-module.md)
- [Architecture](docs/explanation/architecture.md)
- [Threat model](docs/explanation/threat-model.md)
- [Terraform reference](docs/reference/terraform.md)
- [Release gates](docs/reference/release-gates.md)
