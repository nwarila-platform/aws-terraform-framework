# Terraform Runner Protocol

This repository supplies a Terraform root module under `terraform/`. It does not publish a
reusable deployment workflow, an overlay utility, or a release-evidence workflow. A deployment
runner integrates with the framework through the Terraform CLI and owns checkout, authentication,
deployment inputs, approval gates, and evidence collection.

The workflows under `.github/workflows/` maintain this repository. They are not deployment
interfaces for consumers.

## Framework Checkout

Production runners should check out this repository at a reviewed, immutable commit SHA. Updating
that pin is a consumer change and should pass the consumer's normal dependency-review process.

The framework has no second `framework_ref` input to validate after checkout. The checked-out
commit is the framework version that Terraform evaluates.

## Backend Configuration

The framework declares a partial S3 backend in `terraform/backend.tf`. The runner supplies the
deployment-specific bucket, key, and region through a backend configuration file. Start from
`terraform/backend.hcl.example`; `terraform/backend.hcl` is ignored so credentials and deployment
state settings do not enter source control.

```shell
cp terraform/backend.hcl.example terraform/backend.hcl
terraform -chdir=terraform init -backend-config=backend.hcl
```

The runner owns AWS authentication and access to the selected state bucket. Backend encryption and
S3-native locking are framework invariants declared in `terraform/backend.tf`.

## Terraform Inputs

Start deployment values from `terraform/terraform.tfvars.example`. The resulting
`terraform/terraform.tfvars` is ignored and is loaded automatically by Terraform. A runner may
instead generate another value file and pass its path with `-var-file`.

There is no framework overlay format or allowlisted landing-zone contract. If a runner copies or
generates files in the checkout, it owns path validation and must place the final backend and
variable data where the Terraform CLI invocation expects them.

## Deployment Identity

Every plan requires these four command-line variables:

- `repository`: the source repository as an `owner/name` slug.
- `repository_id`: the numeric, rename-stable GitHub repository ID.
- `commit_sha`: the lowercase SHA of the checked-out commit.
- `run_id`: the numeric GitHub Actions run ID, or another numeric run identifier for local use.

Pass them as command-line `-var` arguments so they outrank values from all variable files. Capture
the checked-out commit with `git rev-parse HEAD`; on pull requests, `github.sha` may identify a
synthetic merge commit instead.

```shell
identity=(
  -var="repository=<owner>/<repo>"
  -var="repository_id=<numeric repository id>"
  -var="commit_sha=$(git rev-parse HEAD)"
  -var="run_id=<numeric run id>"
)

terraform -chdir=terraform plan "${identity[@]}"
terraform -chdir=terraform apply "${identity[@]}"
```

The framework adds `ManagedBy`, `Repository`, `RepositoryId`, `Environment`, `CommitSha`, and
`RunId` to every taggable resource it creates. Actor identity, timestamps, and approvals belong in
the runner's evidence rather than in resource tags.

## Runner Responsibilities

A deployment runner is responsible for:

- checking out a reviewed framework commit;
- providing AWS credentials and partial S3 backend values;
- supplying deployment variables and the four identity arguments;
- running Terraform initialization, planning, and any approved apply;
- protecting apply environments and restricting which events may deploy; and
- retaining plans, workflow records, approvals, and any other required release evidence.

This framework does not expose a `plan_status` workflow output. A runner that needs structured
plan status can use Terraform's `-detailed-exitcode` option and map its documented exit codes in
the consumer workflow.
