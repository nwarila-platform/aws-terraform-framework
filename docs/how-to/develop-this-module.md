# Develop this module

## Local setup

Install the same pinned tools that the `CI` workflow installs before running
`make ci`:

- Terraform 1.15.1
- TFLint 0.62.0
- terraform-docs 0.23.0
- OPA 1.10.0
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
