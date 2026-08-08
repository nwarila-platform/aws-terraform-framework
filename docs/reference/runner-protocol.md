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

Every plan requires these four command-line variables. All are mandatory and non-nullable —
there is no unattributed deployment:

- `repository`: the source repository as an `owner/name` slug.
- `repository_id`: the numeric, rename-stable GitHub repository ID.
- `commit_sha`: the lowercase SHA of the checked-out commit.
- `run_id`: the numeric GitHub Actions run ID, or another numeric run identifier for local use.

Pass them as command-line `-var` arguments so they outrank values from all variable files. Capture
the checked-out commit with `git rev-parse HEAD`; on pull requests, `github.sha` may identify a
synthetic merge commit instead.

Deploy workflows pass the identity as INDIVIDUAL `-var` flags on every plan,
apply, and destroy — the highest-precedence variable source, so a consumer
tfvars cannot override who a deployment says it is:

```yaml
- name: Terraform apply
  shell: bash
  run: |
    terraform apply -input=false -auto-approve \
      -var "environment=test" \
      -var "repository=${GITHUB_REPOSITORY}" \
      -var "repository_id=${GITHUB_REPOSITORY_ID}" \
      -var "commit_sha=$(git rev-parse HEAD)" \
      -var "run_id=${GITHUB_RUN_ID}"
```

The framework writes `ManagedBy`, `Repository`, `RepositoryId`, `Environment`, `CommitSha`,
and `RunId` into the tag map of every taggable resource it creates, alongside
`Name` and the per-resource `OS`, `Index`, and `DeviceName` keys where they apply. Tags are
composed per resource rather than through provider `default_tags`, so each resource's own tag
map is the complete record and is directly assertable in tests.

All identity keys are always present, because every identity variable is required. Those key
names are reserved: a consumer-supplied tag map that sets any of them, in any letter case, is
rejected at validation time rather than being silently overwritten. Actor identity, timestamps,
and approvals belong in the runner's evidence rather than in resource tags.

Because `CommitSha` and `RunId` change per deployment, standing estates see two in-place tag
updates per deploy; ephemeral deploy-and-destroy stacks see none.

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
