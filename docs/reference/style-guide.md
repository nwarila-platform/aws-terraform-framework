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
| `providers.tf` | provider blocks (the supported AWS region uses alias `us_east_1`) |
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

## Packer parity, and its accepted limits

The goal is that a Packer author reads this Terraform without re-learning: the same region
scaffolding, the same `provider` / `for_each` header, alphabetized properties, and the same
98-column rule. Function-set parity is a weaker commitment, and the exceptions below are
deliberate rather than accidental.

Verified against Packer's own registry (`hcl2template/functions.go`), NOT from memory. These
are present in Packer and carry no restriction here: `alltrue`, `anytrue`, `sum`, `startswith`,
`endswith`, `strcontains`, `trimspace`, `try`, `can`, and the collection, encoding, filesystem,
hash and IP-network families. `dynamic`, `validation`, and `provisioner` blocks all exist in
Packer too.

Absent from Packer and accepted here:

| Construct | Sites | Why it stays |
|---|---|---|
| `sensitive` / `nonsensitive` | 1 | No Packer analogue exists at all - Packer has a `sensitive` variable *attribute*, not functions. Structural to the RDS credential path. |
| `toset` / `tolist` / `tostring` / `tonumber` | 16 | Packer exposes a single `convert` function instead of the `to*` family. Several feed `for_each`, which requires a set. |
| `lifecycle` / `precondition` / `postcondition` | 7 / 11 / 4 | Packer has none. These carry plan-time guards and provider-result checks, including AMI block-device encryption and ordered ENI-address verification. |

`one()` is also absent from Packer and is NOT used: where a value is null-or-single, carry the
provider-shaped value directly rather than indexing or unwrapping a list.
`local.elastic_network_interfaces` renders an interface's authored addresses in whichever
provider-shaped collection that interface needs: null or the singleton `private_ips` set when it
carries at most one address, and the ordered `private_ip_list` when `additional_private_ips` gives
it more.

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
  [repository
  ADR-0002](../decision-records/repo/0002-allow-optional-for-additive-object-attributes.md),
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
- Attribute access on shaped locals uses dot notation (`each.value.name`); brackets are
  reserved for dynamic map lookups.
- Resource blocks consume locals, not `var.*` directly (except trivially scalar
  wiring); `locals.tf` is the only place shaping logic lives.
- Every taggable resource merges consumer tags under a non-overwritable PascalCase
  framework set (`Name`, `Environment`, `ManagedBy`, `Repository`, `RepositoryId`,
  `CommitSha`, `RunId`), composed in `locals.tf`.
- The six keys whose value never varies are *additionally* set as provider
  `default_tags`, and that is not redundant. `default_tags` is the only mechanism that
  puts tags inside the create API call: `RunInstances` carries them in its
  `TagSpecifications`, so the volumes it creates are tagged as they are born. A tag
  written in a resource's own `tags` block is applied afterwards by a separate
  `CreateTags` call, so the create request carries no `aws:RequestTag` key and a launch
  policy conditioning on one cannot match. Removing `default_tags` therefore breaks any
  consumer whose `ec2:RunInstances` grant is scoped that way — with no signal from
  `plan`, `validate`, or `terraform test`, none of which inspects an API request.
- Explicit per-resource maps stay for the keys whose value varies (`Name`, `Index`,
  `DeviceName`, `OS`, `Backup`, `Function`, `Connection`). `RunInstances` applies one tag set to every
  volume in the request, so per-device values could not live in `default_tags` even in
  principle. The two mechanisms are complementary, never alternatives.
- PascalCase holds without exception because AWS recognises `Name` only in that exact
  casing — it is what the console shows as a resource's display name — so PascalCase is
  the one convention needing no carve-out. AWS tag keys are case-sensitive, so
  `Environment` and `environment` would be two separate tags; that is why the
  reserved-key validation rejects a consumer tag map setting any casing of a
  framework-owned key rather than only the exact spelling.

## Comments

- `#` only; no `//` and no `%#` banner boxes.
- `#region ------ [ Title ] ---- #` / matching `#endregion` markers group long
  resource files; titles name the AWS/Proxmox object family.
- A comment states a constraint the code cannot show (why a value is forced, what
  breaks without it) — never what the next line does. The `?Note:` prefix is
  retired; write plain prose.

## The 98-column rule

The budget binds comments and hand-written Markdown prose. Expression lines are formatted by
`terraform fmt` and are not rewrapped by hand, because breaking one to fit costs more clarity
than the long line does.

Four things sit outside the rule, and none of them is an oversight:

- Generated files. `docs/reference/terraform.md` is written by `terraform-docs` and `CHANGELOG.md`
  by release-please; both are regenerated, so a hand-wrap is reverted on the next run.
- Mirrored files. `docs/decision-records/org/` and `docs/decision-records/template/` are
  byte-identity mirrors (see [mirroring](mirroring.md)). Rewrapping them is drift and fails the
  drift-gate detector.
- Markdown tables and fenced code blocks, which cannot be wrapped without changing what they mean,
  and link URLs, which are single unbreakable atoms. Break the line before the link rather than
  splitting its text.
- Attribute lines whose provider-defined name alone exhausts the budget, as with
  `aws_lb.enforce_security_group_inbound_rules_on_private_link_traffic`.

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
