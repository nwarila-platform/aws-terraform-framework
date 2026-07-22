# aws-terraform-framework

Terraform framework for modeling AWS infrastructure in the supported
`us_east_1` region. Adding another region requires a code change. The module currently manages EC2
instances, network interfaces, EBS volumes and attachments, EC2 instance state,
RDS database instances, load balancers, and refresh trigger resources.

This repository is an infrastructure framework module, not a complete
deployment root by itself. Consumers still provide backend configuration,
credentials, account-specific network IDs, KMS aliases, key pairs, and resource
inventory through Terraform variables.

## Quickstart

### Contributor check

Run the local quality gate before changing Terraform sources:

```shell
make ci
```

The CI path runs Terraform formatting, init, validation, tests, TFLint,
terraform-docs drift detection, documentation layout checks, and the repo's OPA
policy target.

### Deploy from this framework

From the repository root, create local, ignored deployment files from the
examples, then fill in real account, network, key-pair, KMS, and backend
values:

```shell
cp terraform/backend.hcl.example terraform/backend.hcl
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Initialize the S3 backend with the partial backend config, then review and
apply the plan:

```shell
terraform -chdir=terraform init -backend-config=backend.hcl
terraform -chdir=terraform plan
terraform -chdir=terraform apply
terraform -chdir=terraform output -json aws_instances
```

A real apply must populate `readiness_private_key_paths` in
`terraform.tfvars` for gated systems. The readiness gate uses that map to find
each launch key and connects over SSH on every platform: the Windows OpenSSH
bootstrap installs the launch public key for Administrator, so the same private
key logs in there too (WinRM is decommissioned). Zero-inbound systems reached
only through SSM set `readiness_gate = false` and skip the gate.

## Documentation

- [Getting started](docs/how-to/develop-this-module.md)
- [Architecture](docs/explanation/architecture.md)
- [Threat model](docs/explanation/threat-model.md)
- [Terraform reference](docs/reference/terraform.md)
- [Release gates](docs/reference/release-gates.md)
