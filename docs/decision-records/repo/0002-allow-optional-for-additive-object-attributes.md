# ADR-0002: Allow `optional()` Solely for Additive Object Attributes

| Field            | Value                                                                          |
| ---------------- | ------------------------------------------------------------------------------ |
| ID               | ADR-0002                                                                       |
| Scope            | Repository-specific                                                            |
| Status           | Accepted                                                                       |
| Decision-subject | A bounded exception to the no-`optional()` style rule for backward-compatible attribute additions. |
| Date accepted    | 2026-07-25                                                                     |
| Date             | 2026-07-25                                                                     |
| Last reviewed    | 2026-07-26                                                                     |
| Authors          | Nick Warila (@NWarila)                                                         |
| Decision-makers  | Nick Warila (sole portfolio maintainer)                                        |
| Consulted        | Independent design and wiring reviews of the inline per-system security group. |
| Informed         | Framework maintainers and consumer owners.                                     |
| Reversibility    | High                                                                           |
| Review-by        | 2027-01-25                                                                     |

## TL;DR

`optional()` remains banned as a way to express an ergonomic default. It is
permitted in exactly one circumstance: adding a **new** attribute to an object
type that pinned consumers already supply, where the attribute's `null` value is
the pre-existing behavior. Such an attribute takes bare `optional(T)` with no
second argument. Terraform supplies a typed `null` when an existing value file
omits it, so no consumer value-file change is required; new and updated examples
still write the `null` off switch explicitly. The first and currently only use
is `all_systems[*].managed_security_group`.

## Context and Problem Statement

`docs/reference/style-guide.md` bans `optional()` "anywhere". The rationale is
real and unchanged: the shared artifact between Terraform and Packer is the
**value file**, and one fully explicit value file is satisfiable by both parsers
only when every object attribute is required and consumers express optionality
with a value (`null`, `[]`, `{}`) rather than a type modifier.

The inline per-system security group had to add one attribute,
`managed_security_group`, to the `all_systems` object type. Terraform object
attributes are required unless wrapped in `optional()`. Without the modifier,
every pinned consumer's existing `all_systems` value becomes type-invalid the
moment the framework is upgraded, and each one needs a migration patch adding
`managed_security_group = null` to every system before it can plan. That is a
breaking variable-shape change, which this repository's release rules require to
ship with a per-consumer migration patch and a paired zero-diff proof.

The feature's hard requirement was the opposite: 100% backward compatibility,
with every consumer that sets no inline group planning byte-identically.

Once co-location inside `all_systems` was chosen, that shape and backward
compatibility could not both hold without the modifier. Bare `optional(T)` does
have default semantics: Terraform supplies a `null` of type `T` when the
attribute is omitted. That typed `null` is the documented off switch and produces
the same behavior as writing `managed_security_group = null`, so existing value
files need no edits.

A guide-compliant design was also viable: a new, validated, default-empty
top-level `system_security_groups` map keyed by hostname could auto-attach groups
without changing existing `all_systems` values or using `optional()`. The choice
between that design and the inline attribute is therefore a real trade-off, not
a question of feasibility. Inline won because it keeps a system-owned firewall
beside the system and avoids repeating the hostname as a separate map key.

The initial inline implementation derived the AWS name as `<hostname>-sg`. A
verified consumer incident showed why that convention was unsafe:
`secure-wazuh-poc` shared a VPC with a permanent, hand-stamped standing group
named `secure-wazuh-poc-sg`. The standing group was attached by ID, so the module
had no group name available for collision validation. EC2 compares
security-group names case-insensitively within a VPC, and the attempted inline
group creation would therefore have failed as a duplicate.

Inline names now use `<hostname>-eni-<index>-sg`, with the raw zero-based index
derived from the group's position. The current nullable object normalizes to a
zero-or-one-element sequence and therefore produces `0`; retaining the position
in the derivation lets a future list produce additional stable names without
replacing the naming rule. This follows the module's deliberate ENI convention;
standalone EBS volumes and security-group rules instead use stable keys that do
not depend on list position. This change is deliberately confined to inline
groups. Keys supplied through the now-removed top-level
`managed_security_groups` map were explicit consumer names and were not
rewritten.

## Decision Drivers

1. **Backward compatibility outranks declaration aesthetics.** A pinned consumer
   must not be forced into a migration patch to receive an additive capability
   it does not use.
2. **The style rule's actual rationale is value-file parity, not the keyword.**
   Parity is a property of the value file. New and updated shared files should
   keep writing the attribute explicitly even though compatibility requires
   Terraform to accept existing files that omit it.
3. **Bare `optional()` has narrow, explicit semantics.** Without a second
   argument Terraform supplies a typed `null`. Here that is intentionally the
   feature's off switch, not an ergonomic non-null default.
4. **The guide-compliant alternative is viable but less cohesive.** A validated,
   default-empty top-level hostname-keyed map preserves backward compatibility
   without `optional()`. It separates a system-owned firewall from its system
   and repeats the hostname as a key; the inline form keeps those facts together.
5. **Divergence must be recorded, not silent.** The style guide states that it
   wins over older code; a deliberate deviation therefore needs a superseding
   record rather than an undocumented exception.
6. **Generated names must not occupy the standing-group convention.** The bare
   `<hostname>-sg` form is common for externally managed groups and cannot be
   discovered when a consumer attaches one by ID. A position suffix avoids the
   observed collision and reserves a stable namespace for multiple inline
   groups later.
7. **Generated names must follow the module's native key style.** Every other
   position-derived key in `locals.tf` uses a raw zero-based index. Security
   groups use the same `<hostname>-<type>-<index>` convention instead of
   introducing a one-based, zero-padded variant.

## Considered Options

1. **Bounded `optional()` exception for additive attributes (chosen).**
2. **Make the attribute required.** Keeps the style rule literally intact.
3. **Top-level `system_security_groups` map keyed by hostname.** Zero
   `optional()`, zero back-compat impact, auto-attach by hostname.
4. **Abandon the inline mechanism.** Keep only `managed_security_groups`.

## Decision Outcome

Chosen option: **Option 1, a bounded exception for additive object attributes.**

`optional()` MAY be used only when all of the following hold:

- The attribute is being **added** to an object type that pinned consumers
  already populate, and omitting it must not change any existing plan.
- It is written as bare `optional(T)`, never `optional(T, <default>)`; its only
  supplied default is a typed `null`.
- `null` is the documented off switch and reproduces the pre-existing behavior
  exactly.
- `terraform.tfvars.example` and the how-to documentation show the attribute
  explicitly, including an example that writes it as `null`.
- The variable's own validations treat `null` as "feature not requested" and
  gate every companion rule on it, so no existing consumer can be newly rejected.

`optional()` MUST NOT be used to supply a non-null behavioral default, to make a
required field convenient to omit, or in any newly introduced object type, where
every attribute can simply be required from the start.

The inline security-group name MUST be rendered as `<hostname>-eni-<index>-sg`,
where `index` is the raw zero-based position in the normalized per-system
sequence. The 255-character EC2 group-name limit is checked against each
rendered name. The current `-eni-0-sg` suffix leaves 246 characters for the hostname;
a future `-eni-10-sg` suffix would leave 245, and the rendered-name validation
adjusts with the index rather than enforcing a permanently conservative bound.
Top-level `managed_security_groups` map keys are outside this derivation and
MUST retain their consumer-supplied bytes.

## Pros and Cons of the Options

### Option 1: Bounded `optional()` exception

- **Good, because** existing consumers upgrade with no tfvars edit and no plan
  churn.
- **Good, because** its typed `null` default is the same off value documented for
  an explicit `managed_security_group = null`.
- **Good, because** the exception is narrow enough to audit: any
  `optional(T, ...)` with a second argument is still a violation.
- **Bad, because** the codebase no longer has a single mechanically greppable
  rule (`optional(` is not by itself a defect).
- **Bad, because** a consumer that omits the attribute yields a value file that
  is no longer fully explicit, weakening Packer parity for that file unless the
  documented convention is followed.

### Option 2: Make the attribute required

- **Good, because** the style rule stays literally intact.
- **Bad, because** it breaks the variable shape for every pinned consumer and
  requires a migration patch and paired proof per consumer, for a capability
  those consumers did not ask for.

### Option 3: Top-level hostname-keyed map

- **Good, because** it is fully guide-compliant, needs no modifier or migration,
  and its empty default leaves existing plans unchanged.
- **Good, because** validation can require every key to match one system
  hostname, and attachment can still be automatic.
- **Bad, because** it repeats the owning hostname as a map key and separates the
  group's definition from the system it protects.
- **Bad, because** validation can prevent bad references but cannot provide the
  same visual co-location as an attribute in the system object.

### Option 4: Abandon the inline mechanism

- **Good, because** nothing changes.
- **Bad, because** the orphaned-group and dangling-reference failures remain
  unaddressed.

## Migration Consequence

Moving an existing `managed_security_groups` entry to the inline attribute is
not generally a rename. If its map key is not already exactly
`<hostname>-eni-0-sg`, the move changes both the `for_each` resource address and the
immutable AWS security-group name. Terraform therefore replaces the live group;
`terraform state mv` can move the state address but cannot prevent replacement
for the changed name. Perform such a migration only in an environment that can
tolerate the group being recreated and its attachments being rewired.

There is one narrow no-replacement case: an existing map entry already keyed
exactly `<hostname>-eni-0-sg` has the same resource address and AWS name after it moves
inline. If its region, VPC, rules, description, and tags also remain equivalent,
Terraform can retain it without a state move. This exception is why the broader
claim that every map-to-inline migration replaces a group would be inaccurate.

## Confirmation

1. `terraform/variables.tf` MUST declare `all_systems[*].managed_security_group`
   as bare `optional(object({...}))` with no second argument, and every
   companion validation MUST short-circuit on
   `system.managed_security_group == null`.
2. `terraform/terraform.tfvars.example` MUST show the attribute populated on one
   system and written as `null` on another.
3. `terraform/tests/inline_security_groups.tftest.hcl` MUST retain a run proving
   a consumer that sets no inline group creates no additional resources and no
   additional `for_each` keys.
4. Any future `optional(` occurrence carrying a second argument is a style
   violation regardless of this ADR.

## Consequences

### Positive

- Additive capabilities can reach the `all_systems` object type without a
  breaking release.
- New and updated value files preserve explicitness by convention and example,
  while existing value files remain valid without edits.

### Negative

- Reviewers must distinguish bare `optional(T)` from `optional(T, default)`
  instead of rejecting the keyword outright.
- A consumer that omits the attribute produces a value file that Packer would
  need a matching declaration to parse; no shared value file does so today.

### Neutral

- No `*.pkrvars.hcl` mirror of an `all_systems` value file exists in the
  portfolio at the time of this decision, so nothing is broken in practice.

## Assumptions

1. Terraform continues to treat bare `optional(T)` as supplying a typed `null`
   default.
2. Consumers keep writing the attribute explicitly in shared value files.

## Supersedes

None. This decision amends, for this repository, the unconditional
`optional()` prohibition in `docs/reference/style-guide.md`, which now carries
the carve-out and links here.

## Superseded by

The 2026-07-27 removal of the top-level `managed_security_groups` map supersedes
only this decision's map-coexistence, explicit-map-key, and map-to-inline
migration statements. The decision establishing the inline attribute, its
bounded `optional()` use, and its derived naming remains current.

The later 2026-07-27 relocation of framework-created groups from
`all_systems[*].managed_security_group` to flat
`all_systems[*].network_interfaces[*].ingress` and `.egress` attributes
supersedes the system-level declaration, its `optional()` use, and its nullable
object off switch. The general bounded `optional()` exception remains available,
but this repository has no current use. The derived name remains
`<hostname>-eni-<index>-sg`; the raw index now comes from the declaring network
interface.

## Implementing PRs

None yet. The inline per-system security group introduces this ADR and its
implementation together; the merged PR may be added here later.

## Related ADRs

- [Repository ADR-0001](0001-hardcode-first-security-baseline.md) defines where
  variable validations are the sanctioned enforcement home, which is the layer
  this attribute's companion rules use.

## Changelog

| Date       | Change                                                        | Reason                                                                              | Author/Role          | Body-diff? |
| ---------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------- | ---------- |
| 2026-07-27 | Renamed interface-owned groups to `<hostname>-eni-<index>-sg`. | Pair every group visibly with the ENI it protects. | Portfolio maintainer | Yes        |
| 2026-07-27 | Moved created security-group declaration to each network interface. | Model the AWS attachment boundary directly. | Portfolio maintainer | Yes        |
| 2026-07-27 | Removed the top-level managed security-group path.             | Keep security-group creation system-specific; map coexistence and migration contracts no longer apply. | Portfolio maintainer | Yes        |
| 2026-07-26 | Changed inline names to position-derived `<hostname>-eni-<index>-sg`. | Avoid the verified standing-group collision and follow the module's native raw zero-based key style. | Portfolio maintainer | Yes        |
| 2026-07-25 | Accepted the bounded `optional()` exception for additive attributes. | Adding `all_systems[*].managed_security_group` had to be backward compatible. | Portfolio maintainer | Yes        |
