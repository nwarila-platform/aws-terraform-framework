# Release Gates

PRs to `main` must pass:

- `CI` (`make ci`: Terraform fmt/init/validate/test and TFLint for both roots,
  the credential-free overlays plan and exact provider-tag gate, the alias-file
  contract self-test, terraform-docs diff for both reference pages, Diataxis
  docs layout, and the bidirectional deny-all `.gitignore` allowlist guard)
- `Security` (the local `security.yaml` caller, which delegates to the
  namespace-local `nwarila-platform/.github` CodeQL, IaC/security, and
  Scorecard reusables per org ADR-0005)
- `Template Sync` (`NWarila/drift-gate` against
  `NWarila/terraform-framework-template` current `main` pin
  `ba73041b808ceae584f482e6bec2970c1bdc019b`)
- `Repo Hygiene` (`nwarila-platform/.github` repo-hygiene policy)

Workflow and action references are 40-character SHA-pinned per the repo-hygiene
contract.

Before the networking-extraction release is cut, a state-backed zero-diff proof
against the live consumer's unchanged tfvars is a blocking release-layer gate.
It must compare normalized saved-plan JSON from the baseline and candidate with
identical provider lockfiles; count anchors and structural greps are not
substitutes.
