# Terraform Runner Protocol

Runner repositories call
`.github/workflows/reusable-terraform-deploy.yaml` to plan and (optionally)
apply runner-owned Terraform input against a SHA-pinned framework. The runner
owns scheduling, environment approval, backend secrets, and apply-gating. The
framework owns the reusable deploy contract, policy, overlay validation, state
backend wiring, and release evidence shape.

## Required Inputs

Callers MUST pass `framework_ref` as a lowercase 40-character commit SHA for
`NWarila/terraform-framework-template` or a derived framework repository. The
reusable workflow rejects floating refs before checkout via
`tools/ci/validate_framework_ref.sh`.

`consumer_repo` identifies the repository that supplies runner-owned input
files. When omitted, it defaults to the calling repository
(`github.repository`). `consumer_ref` identifies the commit to read from
`consumer_repo`; it defaults to `github.sha`.

## Pin Management

Runner repositories should let Renovate update `framework_ref` instead of
hand-bumping SHAs. The shared Renovate regex manager reads comments in workflow
YAML using the `git-refs` datasource. Put the annotation directly above the
input it manages:

```yaml
with:
  # renovate: depName=NWarila/terraform-framework-template packageName=NWarila/terraform-framework-template currentValue=main
  framework_ref: 0123456789abcdef0123456789abcdef01234567
```

Keep the reusable workflow `uses:` SHA and the body `framework_ref` under review
together. The exact Renovate policy comes from org ADR-0004 and the template's
`.github/renovate.json5` custom manager.

## Overlay Destinations

`overlay_paths` is a newline-separated list of
`<consumer-src>=><framework-dst>` entries. Sources are relative to the
consumer checkout. Destinations are relative to the framework checkout and are
allowlisted to:

- `terraform/repos/`
- `terraform/fixtures/runtime/`

Those are the only runner-owned landing zones. The allowlist prevents a runner
overlay from replacing framework `.tf` files, policy, or workflow definitions.
`tools/ci/apply_overlay.sh` rejects absolute paths, `..` traversal,
destinations outside the allowlist, missing sources, and symlinks.

## Variable Files

`tfvars_file` accepts an optional path relative to the consumer checkout.
`tools/ci/terraform_tfvars_args.sh` emits the ordered Terraform `-var-file`
argument used by `terraform plan` and `terraform apply`. Absolute paths and
`..` traversal segments are rejected.

## Deployment Identity Tags

The framework stamps deployment identity onto every taggable AWS resource
through provider `default_tags`, and merges the same keys into EC2 root
volume tags (which `default_tags` cannot reach). Stable keys answer who owns
and manages a resource; `commit-sha` and `run-id` trace it to the exact
commit and workflow run. Actor identity and timestamps deliberately stay OUT
of tags (plaintext PII, churn); they live in the workflow-run record that
`run-id` points to.

Deploy workflows pass the identity as INDIVIDUAL `-var` flags on every plan,
apply, and destroy — the highest-precedence variable source, so a consumer
tfvars cannot override who a deployment says it is. Capture the checked-out
commit, not `github.sha` (which can be a synthetic merge commit):

```yaml
- name: Terraform apply
  shell: bash
  env:
    STACK: ${{ vars.TERRAFORM_STACK }}
    OWNER_TEAM: ${{ vars.OWNER_TEAM }}
  run: |
    terraform apply -input=false -auto-approve \
      -var "environment=test" \
      -var "repository=${GITHUB_REPOSITORY}" \
      -var "repository_id=${GITHUB_REPOSITORY_ID}" \
      -var "stack=${STACK}" \
      -var "owner=${OWNER_TEAM}" \
      -var "commit_sha=$(git rev-parse HEAD)" \
      -var "run_id=${GITHUB_RUN_ID}"
```

Resulting tag keys: `nwarila:management:managed-by` / `repository` /
`repository-id` / `stack` / `environment` (from `var.environment`) and
`nwarila:operations:owner`, plus `nwarila:provenance:commit-sha` and
`nwarila:provenance:run-id` when supplied. The `nwarila:` namespace is
reserved; consumer tag maps may not use it (validated). Because `commit-sha`
and `run-id` change per deployment, standing estates see two in-place tag
updates per deploy; ephemeral deploy-and-destroy stacks see none. Leaving
The identity unset emits zero tags and keeps plans byte-identical -
native Terraform tests verify set-completeness on resources that carry the
`managed-by` marker.

## Backend Selection

`backend_mode` is `local` or `s3`. `local` keeps PR validation
credential-free. `s3` generates a partial S3 backend block from the caller's
OIDC + bucket secrets and verifies remote state after apply. Trusted deploy
callers (typically `push` to `main`) set `backend_mode: s3` and pass the
secrets listed in the reusable workflow definition; PR callers should leave
the default.

## Apply Gating

`apply` is `false` by default. The reusable workflow always runs `terraform
plan` against the assembled tree. Callers should gate `apply: true` to
specific branches or events (typically `push` to `main` plus environment
approval). The reusable workflow does not assert who can trigger apply; the
caller's workflow conditions and environment protection rules are the gate.

## Plan Status Output

The reusable deploy exposes `plan_status`:

- `no-changes`: plan succeeded with no drift.
- `has-changes`: plan succeeded and proposed changes.
- `failed`: plan exited non-zero.

Runners use this output to decide whether to upload an artifact, post a
comment, or trigger a follow-on apply job.

## Release Evidence

Runner repositories call
`.github/workflows/reusable-release-evidence.yaml` with `repo_type: runner`.
Runner-shaped release evidence snapshots `terraform/repos/`, records
`terraform/fixtures/runtime/` inventory if present, and captures the pinned
`framework_ref` from the calling workflow. Runner evidence does not run
`terraform plan` or `apply`.

Framework repositories use `repo_type: framework`, which runs Terraform
validation, native framework tests, docs-diff, and reference snapshots.
Runner-template repositories use `repo_type: template` until they are forked
into real runner repositories.

## Example

```yaml
jobs:
  deploy:
    uses: NWarila/terraform-framework-template/.github/workflows/reusable-terraform-deploy.yaml@0123456789abcdef0123456789abcdef01234567
    with:
      # renovate: depName=NWarila/terraform-framework-template packageName=NWarila/terraform-framework-template currentValue=main
      framework_ref: 0123456789abcdef0123456789abcdef01234567
      overlay_paths: |
        repos/public=>terraform/repos/public
        repos/private=>terraform/repos/private
      tfvars_file: terraform/repos/public/prod.tfvars
      terraform_version: "1.15.4"
      backend_mode: s3
      apply: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
    secrets:
      aws_role_arn: ${{ secrets.AWS_DEPLOY_ROLE }}
      aws_region: ${{ secrets.AWS_REGION }}
      backend_bucket: ${{ secrets.TF_STATE_BUCKET }}
      backend_key_prefix: ${{ secrets.TF_STATE_KEY_PREFIX }}
```
