# Terraform coding and style guide

Formal style for `nwarila-platform` Terraform framework repositories. Reconciles the
conventions of `aws-terraform-framework`, `proxmox-terraform-framework`, and
`terraform-proxmox-iso-manager-framework` into one dialect. Canonical home for this
guide is the framework type-template; this copy governs this repository until the
template mirror lands. Where this guide contradicts older code, this guide wins and
the code migrates.

## File layout

Canonical filenames only — no numeric prefixes:

| File | Owns |
| --- | --- |
| `versions.tf` | `terraform { required_version, required_providers }` — exact `=` pins |
| `backend.tf` | `terraform { backend "..." {} }` (partial config; secrets never in-repo) |
| `providers.tf` | provider blocks (the supported AWS region uses alias `us_east_1`), `default_tags` |
| `variables.tf` | every `variable` block |
| `data.tf` | every `data` block |
| `locals.tf` | every `locals` block — the "brain": all shaping happens here |
| `resources.tf` | every managed resource; consumes locals, never raw variables |
| `outputs.tf` | every `output` block |

Rationale: matches community convention and the org repo-hygiene pin gate, which
keys on `terraform/versions.tf`. Numeric prefixes (`00-`, `10-`, …) are retired;
they disabled that gate and encoded ordering the filenames now carry semantically.
Tests live in `terraform/tests/*.tftest.hcl`, named by subject
(`systems`, `managed`, `tagging`, `outputs`, …).

## Variable declarations — Packer-compatible syntax

Variable declarations MUST restrict themselves to syntax Packer HCL2 also accepts,
so inventory files can be shared across Terraform and Packer consumers:

- **No `optional()` type modifiers, anywhere.** Every object attribute is required;
  consumers write every value explicitly. Optionality is expressed by the value
  (`null`, `[]`, `{}`), never by the type.
- **No `nullable = true` defaults by omission**: declare `nullable = false` on every
  variable except those whose documented "off switch" is the value `null`.
- Variables carrying a genuine feature switch default to their empty value
  (`{}` / `[]` / `null`) so unconfigured consumers get zero resources and
  byte-identical plans.
- `description` is a `<<-EOT` heredoc: first sentence says what it is; following
  sentences say how consumers use it, what validates it, and what happens when it
  is empty. Descriptions are contracts, not captions.
- Every externally supplied scalar gets a `validation` block with a `can(regex(...))`
  or structural condition and an error message that states the exact accepted form.
  Cross-variable validations are allowed and preferred over runtime surprises.
- Defaults that `optional()` used to inject move into the documented example
  (`terraform.tfvars.example`) and the how-to docs — visible in every consumer's
  tfvars, not hidden in type constraints.

## Resources

- Resources iterate maps via `for_each` with stable, human-readable keys; keys are
  part of the public contract and never re-derived incidentally.
- AWS support is currently single-region: `us_east_1`. The historical twin
  pattern remains the expansion mechanism because `provider` and `lifecycle`
  are static meta-arguments; adding a region requires provider, data, local,
  resource, output, and test changes. Global resources (IAM) remain single
  un-aliased blocks.
- Attribute access on shaped locals uses bracket notation
  (`each.value["name"]`), matching the Proxmox frameworks.
- Resource blocks consume locals, not `var.*` directly (except trivially scalar
  wiring); `locals.tf` is the only place shaping logic lives.
- Every taggable resource merges consumer tags under the non-overwritable
  framework tags (`Name`, `Environment`, `Terraform`) and inherits the
  `nwarila:*` identity set via provider `default_tags` (root volumes get the
  explicit merge `default_tags` cannot deliver).

## Comments

- `#` only; no `//` and no `%#` banner boxes.
- `#region ------ [ Title ] ---- #` / matching `#endregion` markers group long
  resource files; titles name the AWS/Proxmox object family.
- A comment states a constraint the code cannot show (why a value is forced, what
  breaks without it) — never what the next line does. The `?Note:` prefix is
  retired; write plain prose.

## Validation and testing

- `terraform test` with `mock_provider` per alias is the unit layer: every
  capability ships a default-off zero-diff anchor run, at least one opt-in run
  asserting concrete planned values, and `expect_failures` runs for each
  validation rule.
- Mock data sources whose values must satisfy provider-side validation (ARNs)
  set `mock_data` defaults rather than letting random strings fail.
- OPA plan policy asserts security invariants resource-by-resource; policy rules
  that depend on opt-in features key on a marker the feature stamps, so
  non-opted-in plans stay silent.
- `make ci` is the single local gate and CI runs exactly it.

## Releases and history

- Squash-merge titles are Conventional Commits; breaking changes use `!` and a
  `BREAKING CHANGE:` footer. Automation prefixes stay in PR bodies.
- Consumer-affecting behavior changes ship with a zero-diff proof (or an explicit
  migration note) against each pinned consumer's tfvars.
