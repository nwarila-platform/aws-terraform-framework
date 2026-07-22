# Develop this module

## Local setup

Install the same pinned tools that the `CI` workflow installs before running
`make ci`:

- Terraform 1.15.1
- TFLint 0.62.0
- terraform-docs 0.23.0
- Python 3.12 with `pyyaml`, `ruff`, `yamllint`, `zizmor`

## The development loop

```sh
make fmt        # format Terraform
make ci         # run every gate
make docs       # regenerate docs/reference/terraform.md
```

## Before opening a PR

```sh
make ci
```

If `make ci` is green locally, the `CI` workflow should be green in GitHub
Actions.

## Merge titles are the release pipeline

Releases are cut by release-please, which classifies **squash-merge commit
titles** on `main`. A title that does not follow Conventional Commits
(`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, with `!` or a
`BREAKING CHANGE:` footer for breaking changes) is invisible to the release
pipeline: it lands on `main` but can never be released or listed in the
CHANGELOG.

Rules:

- The PR title (which becomes the squash commit title) MUST be a
  Conventional Commit. Review it like code.
- Automation prefixes such as `[bot]` never belong in the title; put them in
  the PR body.
- Consumer repos pin this framework by release, so an unreleasable `main`
  blocks every downstream pin bump.
