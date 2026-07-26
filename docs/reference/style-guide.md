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

## Value-file-compatible variable surfaces

The shared artifact is the value file, not the declaration blocks. Packer reads
explicitly supplied `*.pkrvars.hcl` or `*.pkrvars.json` files and automatically loads
`*.auto.pkrvars.hcl` and `*.auto.pkrvars.json` files, but never raw `*.tfvars` files.
Each shared Terraform value file MUST therefore have a byte-identical copy or symlink
whose suffix preserves its format: `*.pkrvars.hcl` for HCL or `*.pkrvars.json` for
JSON. Supply it explicitly to Packer unless it uses an auto-loaded name, and provide
matching Packer variable declarations for every top-level variable it assigns.

- **No `optional()` type modifiers**, with one bounded exception. This explicitness
  policy makes one fully explicit value file satisfiable by both parsers: every object
  attribute is required, and consumers express optionality with a value (`null`, `[]`,
  or `{}`), never with a type modifier. The exception, recorded in
  [repository ADR-0002](../decision-records/repo/0002-allow-optional-for-additive-object-attributes.md),
  covers only an attribute *added* to an object type that pinned consumers already
  populate, where requiring it would break their value files: it takes bare
  `optional(T)` with no second argument, so Terraform supplies a typed `null` when an
  existing value file omits the attribute and no value-file edit is required. `null`
  reproduces the pre-existing behavior; new and updated value files still write it
  explicitly. `optional(T, <non-null default>)`, a behavioral default hidden in a type
  constraint, remains banned outright.
- In Terraform declarations, declare `nullable = false` on every variable except
  those whose documented "off switch" is the value `null`.
- Terraform variables carrying a genuine feature switch default to their empty value
  (`{}` / `[]` / `null`) so unconfigured consumers get zero resources and the
  release proof retains an empty normalized resource delta.
- In Terraform declarations, `description` is a `<<-EOT` heredoc: the first sentence
  says what the variable is; following sentences say how consumers use it, what
  validates it, and what happens when it is empty. Descriptions are contracts, not
  captions.
- Every externally supplied scalar in a Terraform declaration gets a `validation`
  block with a `can(regex(...))` or structural condition and an error message that
  states the exact accepted form. Cross-variable validations are allowed and
  preferred over runtime surprises.
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
  capability ships a default-off zero-resource anchor run, at least one opt-in run
  asserting concrete planned values, and `expect_failures` runs for each
  validation rule.
- Mock data sources whose values must satisfy provider-side validation (ARNs)
  set `mock_data` defaults rather than letting random strings fail.
- Security invariants owned by the framework are hard-coded directly on resources
  whenever possible and covered by native Terraform test assertions. Variable
  validations are reserved for valid-typeable consumer settings that objectively
  deviate from the established security baseline and cannot be hard-coded. Any
  additional policy evaluation belongs to consumers.
- The release layer supplies the zero-diff proof for each pinned consumer. In
  isolated baseline (the consumer's current pin) and candidate checkouts, it uses
  identical lockfiles and the consumer's real tfvars, runs `terraform plan -out`,
  then renders the saved plans with `terraform show -json`. The streamed JSONL UI
  from `terraform plan -json` is not a proof artifact.
- The proof canonically projects `resource_changes` and `output_changes` from both
  saved-plan JSON documents, normalizes ordering and non-semantic metadata, and
  compares the projections. Acceptance requires an empty normalized resource delta;
  output-only differences MUST be explicitly enumerated.
- Proof runs require backend and state access and credentials. Run the baseline and
  candidate plans back-to-back; any drift detected during either plan's in-memory
  refresh invalidates the comparison and requires a rerun after the drift is resolved.
  T14 is the harness that produces these artifacts; count-based anchor runs and grep
  proxies do not substitute for reviewer verification of the proof semantics.
- `make ci` is the single local gate and CI runs exactly it.

## Releases and history

- Squash-merge titles are Conventional Commits; breaking changes use `!` and a
  `BREAKING CHANGE:` footer. Automation prefixes stay in PR bodies.
- Consumer-affecting behavior changes ship with the release-layer zero-diff proof
  against each pinned consumer's real tfvars.
- A breaking variable-shape change also ships with a ready-to-apply migration tfvars
  patch for each pinned consumer. Its proof pairs the baseline ref with the
  consumer's original tfvars and the candidate ref with the migrated tfvars.
- The framework attaches each migration patch but never commits or applies it to a
  consumer repository; the consumer's owners apply it.
