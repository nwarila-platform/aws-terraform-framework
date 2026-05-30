# Release Gates

PRs to `main` must pass:

- `CI` (`make ci`: Terraform fmt/init/validate/test, TFLint,
  terraform-docs diff, Diataxis docs layout, and OPA policy tests)
- `Security` (the `NWarila/terraform-framework-template` security caller,
  which delegates to the org CodeQL, IaC/security, and Scorecard reusables)
- `Template Sync` (`NWarila/drift-gate` against
  `NWarila/terraform-framework-template@3b0a832f38e8057d8531e890a666242dc32cab21`)
- `Repo Hygiene` (`NWarila/.github` repo-hygiene policy)

Workflow and action references are 40-character SHA-pinned per the repo-hygiene
contract.
