# Release Gates

PRs to `main` must pass:

- `CI` (`make ci`: Terraform fmt/init/validate/test, TFLint,
  terraform-docs diff, and Diataxis docs layout)
- `Security` (the local `security.yaml` caller, which delegates to the
  namespace-local `nwarila-platform/.github` CodeQL, IaC/security, and
  Scorecard reusables per org ADR-0005)
- `Template Sync` (`NWarila/drift-gate` against
  `NWarila/terraform-framework-template@2114aec93668cde41003beb6445b85a68cf12ec5`)
- `Repo Hygiene` (`nwarila-platform/.github` repo-hygiene policy)

Workflow and action references are 40-character SHA-pinned per the repo-hygiene
contract.
