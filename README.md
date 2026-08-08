# aws-terraform-framework

Terraform framework for modeling AWS infrastructure in the supported
`us_east_1` region. Adding another region requires a code change. The module currently manages EC2
instances, network interfaces, interface-owned security groups and rules, Elastic IPs and
associations, EBS volumes and attachments, EC2 instance state, SSH readiness gates, RDS database
instances, load balancers, and refresh trigger resources.

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
terraform-docs drift detection, documentation layout checks, and the
bidirectional deny-all `.gitignore` allowlist guard.

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

identity=(
  -var="repository=<owner>/<repo>"
  -var="repository_id=<numeric repository id>"
  -var="commit_sha=$(git rev-parse HEAD)"
  -var="run_id=0"
)

terraform -chdir=terraform plan "${identity[@]}"
terraform -chdir=terraform apply "${identity[@]}"
terraform -chdir=terraform output -json aws_instances
```

`repository`, `repository_id`, `commit_sha`, and `run_id` are required and are
deliberately absent from `terraform.tfvars.example`. They become the
`Repository`, `RepositoryId`, `CommitSha`, and `RunId` provenance tags on every
resource, so a value file must not be able to restate them — command-line
`-var` outranks every tfvars source, and CI supplies all four from the workflow
context (see [runner protocol](docs/reference/runner-protocol.md)). Omitting
them fails the plan, which is the intended behavior: it is better than an apply
that succeeds with untraceable provenance.

A real apply must set `readiness_private_key_path` on every gated system. The
readiness gate connects over SSH on every platform: the Windows OpenSSH bootstrap
installs the launch public key for Administrator, so the same private key logs in
there too (WinRM is decommissioned). A path that does not exist is rejected at plan
rather than after the gate's ten-minute timeout. Zero-inbound systems reached only
through SSM set `readiness_gate = false` and skip the gate entirely.

## Documentation

- [Getting started](docs/how-to/develop-this-module.md)
- [Architecture](docs/explanation/architecture.md)
- [Threat model](docs/explanation/threat-model.md)
- [Terraform reference](docs/reference/terraform.md)
- [Release gates](docs/reference/release-gates.md)
