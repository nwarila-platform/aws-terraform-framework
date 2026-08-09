# ADR-0001: Adopt a Hardcode-First Security Baseline

| Field            | Value                                                                       |
| ---------------- | --------------------------------------------------------------------------- |
| ID               | ADR-0001                                                                    |
| Scope            | Repository-specific                                                         |
| Status           | Accepted                                                                    |
| Decision-subject | Security-baseline enforcement and retirement of the repository OPA surface. |
| Date accepted    | 2026-07-22                                                                  |
| Date             | 2026-07-22                                                                  |
| Last reviewed    | 2026-07-22                                                                  |
| Authors          | Nick Warila (@NWarila)                                                      |
| Decision-makers  | Nick Warila (sole portfolio maintainer)                                     |
| Consulted        | Independent architecture reviews.                                           |
| Informed         | Framework maintainers and consumer owners.                                  |
| Reversibility    | Medium                                                                      |
| Review-by        | 2027-01-22                                                                  |

## TL;DR

This repository uses a hardcode-first security doctrine. A security invariant
owned by the module is set directly on every applicable resource whenever
Terraform permits that value to be fixed. Native `terraform test` assertions
guard those hardcodes. Variable validations exist only for valid-typeable
consumer inputs that objectively depart from the established baseline and
cannot be hard-coded. The repository no longer owns or runs an OPA policy
surface; any additional policy evaluation belongs to consumers.

## Context and Problem Statement

The repository previously transformed mocked Terraform test output into a
reduced plan document and evaluated an OPA ruleset against it. The ruleset
repeated several controls already fixed in module code, including encrypted EBS
and RDS storage, encrypted EC2 root volumes, IMDSv2 tokens, private RDS
instances, and the absence of automatically associated public IP addresses.
That second representation added a toolchain and a projection layer that could
drift from the Terraform configuration it was intended to protect.

The enforcement path was also repository-local. No consumer currently evaluates
this repository's policy during deployment, so retaining a policy definition on
the premise of downstream enforcement would describe an architecture that does
not exist. Consumers own their live plan/apply/destroy lifecycle and may add
policy evaluation at that boundary when their threat model requires it.

Two useful gaps had to be closed before removing the old surface. First,
world-open security-group ingress is a valid Terraform input and cannot be fixed
on the resource because consumers still choose scoped ingress sources. Second,
an RDS database with null or empty `vpc_security_group_ids` falls back to the VPC
default security group. Both are objective deviations from this repository's
baseline, so Terraform variable validation is their native enforcement home.
The old gate's remaining unique regression value was protection against edits
to hard-coded EBS and RDS encryption attributes; native test assertions now
cover those resource collections directly.

This repository already intentionally differs from the frozen Template Sync
baseline at `2114aec93668cde41003beb6445b85a68cf12ec5`. That red gate predates
this decision and is stack-wide divergence identified by T00, not a new T19
regression. T20 is the landing-blocking plan to re-pin and reconcile the
baseline after this doctrine lands.

## Decision Drivers

1. **Controls should live at the earliest effective layer.** A fixed resource
   attribute prevents insecure input rather than detecting it after plan
   construction.
2. **Valid consumer footguns need plan-time rejection.** World-open ingress and
   default-security-group fallback remain type-correct, so they require explicit
   Terraform validations.
3. **Regression checks should inspect the native object.** Terraform tests can
   assert the planned resource attributes without maintaining a separate plan
   projection and policy language.
4. **The documented enforcement path must be real.** Two independent reviews
   confirmed the B1 design--definition in the framework, enforcement in
   consumers, and a mocked repository self-gate--if consumers actually ran it.
   Both reviews also identified the same caveat: no consumer evaluates the
   policy today, making C plus a world-open-ingress validation the honest minimum
   architecture.
5. **Consumers own additional policy.** Account context, live credentials, and
   deployment-specific constraints exist at the consumer boundary, not in this
   credential-free mocked test surface.
6. **Template divergence must be explicit.** Template ADR-0002 allows a
   derivative to change the inherited command and policy surface only through a
   superseding repository ADR.

## Considered Options

1. **Option C, hardcode-first Terraform-native enforcement (chosen).** Remove the
   repository OPA surface, hard-code module-owned invariants, validate only
   unhardcodeable baseline footguns, and use native tests for regression
   coverage.
2. **Option B1, framework-defined and consumer-enforced policy.** Keep the OPA
   definition and mocked self-gate here, then require every consumer to evaluate
   it against live plans.
3. **Keep repository-only plan policy.** Preserve the existing mocked plan
   projection and policy gate without adding consumer enforcement.
4. **Move all enforcement to consumers.** Remove local policy without adding
   Terraform validations or native hardcode assertions.

## Decision Outcome

Chosen option: **Option 1, Option C with hardcode-first Terraform-native
enforcement.**

The repository MUST:

- Hard-code security attributes it owns directly on every applicable Terraform
  resource.
- Assert those hardcodes through native `terraform test` planned-resource
  checks, including every normal and refresh resource collection.
- Use variable validation only for valid-typeable settings that objectively
  violate the established baseline and cannot be hard-coded.
- Reject world-open IPv4 managed security-group ingress while allowing
  unrestricted egress.
- Require every RDS database to receive at least one explicit VPC security-group
  ID.
- Keep OPA and Rego tooling, policy files, plan-input projections, and CI targets
  out of this repository.
- Leave any additional plan-policy evaluation to consumers.

## Pros and Cons of the Options

### Option 1: Option C with hardcode-first Terraform-native enforcement

- **Good, because** fixed resource attributes make insecure alternatives
  unrepresentable through the public variable surface.
- **Good, because** validation diagnostics appear at the consumer input that
  caused the deviation.
- **Good, because** native tests inspect the same planned resources the module
  defines.
- **Good, because** the repository gate no longer depends on a second language,
  binary, or lossy plan projection.
- **Bad, because** consumers that need broader contextual policy must own and run
  it themselves.
- **Bad, because** a future module design that exposes a formerly hard-coded
  attribute must add a validation and tests in the same change.

### Option 2: Option B1, framework-defined and consumer-enforced policy

- **Good, because** one policy definition could be shared across consumers.
- **Good, because** live-plan evaluation could inspect provider-resolved values.
- **Bad, because** no current consumer supplies the required enforcement path.
- **Bad, because** the repository would retain a mocked self-gate and projection
  even though the authoritative evaluation occurs elsewhere.

### Option 3: Keep repository-only plan policy

- **Good, because** it preserves the existing command surface.
- **Bad, because** it detects hardcode regressions indirectly through a reduced
  plan projection.
- **Bad, because** it gives no enforcement to consumers at deploy time.

### Option 4: Move all enforcement to consumers

- **Good, because** consumer policy has deployment and account context.
- **Bad, because** the framework would permit known baseline footguns that it can
  reject safely during input validation.
- **Bad, because** module-owned hardcodes would lose focused regression coverage.

## Confirmation

1. `terraform/resources.tf` MUST keep module-owned encryption, IMDSv2 token
   enforcement (`http_tokens = "required"`), the disabled IMDS IPv6 endpoint,
   disabled instance-metadata tags, private database, and related fixed security
   attributes hard-coded. The IMDS PUT response hop limit is the sanctioned
   exception: it is consumer-set through `all_systems[*].imds_hop_limit` because
   container hosts legitimately need 2, and it MUST stay guarded by a variable
   validation bounding it to 1 or 2.
2. `terraform/tests/systems.tftest.hcl` MUST assert EBS encryption across both
   normal and refresh collections, RDS storage encryption, EC2 root encryption,
   and IMDSv2 (token enforcement, disabled IMDS IPv6, disabled metadata tags,
   hop-limit pass-through, and rejection of out-of-bounds hop limits).
3. `all_systems[*].network_interfaces[*].ingress` validation MUST reject any
   `cidr_ipv4` with a `/0` prefix. `terraform/tests/inline_security_groups.tftest.hcl`
   MUST cover this with `inline_group_rejects_world_open_ipv4_ingress`,
   `inline_group_rejects_zero_padded_world_open_ipv4_ingress`, and
   `inline_group_rejects_noncanonical_world_open_ipv4_ingress`, with
   `inline_group_allows_world_open_egress` as the passing unrestricted-egress
   control.
4. `all_databases` validation MUST reject both null and empty
   `vpc_security_group_ids`, with isolated negative tests for each case.
5. `make ci`, the CI tool installer, Renovate annotations, and current reference
   documentation MUST contain no OPA/Rego execution surface.
6. T20 MUST reconcile and re-pin the frozen template baseline before this stack
   lands.

## Consequences

### Positive

- Security controls are enforced at the Terraform layer that owns them.
- Validation failures identify the unsafe consumer input before provider RPC.
- The mocked test suite covers the former policy gate's unique hardcode
  regression value without translation.
- CI and contributor bootstrap have fewer tools and fewer generated artifacts.

### Negative

- The repository no longer provides a reusable policy package to consumers.
- Consumer-specific policy implementations can diverge unless a future shared
  consumer contract standardizes them.

### Neutral

- Live plan/apply/destroy evidence remains consumer-owned.
- Unrestricted egress remains supported; the new security-group validation is
  deliberately ingress-only.
- The existing Template Sync failure remains sanctioned only until T20 performs
  the landing-blocking baseline reconciliation.

## Assumptions

1. Terraform variable validation remains available before provider operations.
2. Module-owned hardcodes continue to be visible in mocked planned resources.
3. Consumers that need controls beyond this baseline can evaluate policy at
   their deployment boundary.
4. T20 lands before the stack is merged and resolves the pre-existing frozen
   baseline divergence.

## Supersedes

For this repository only, this decision supersedes the recommendation in
[Template ADR-template/0002](../template/0002-keep-reference-framework-credential-free.md)
that derivative frameworks retain the template's OPA policy and command surface.
The template ADR's credential-free self-validation and caller-owned backend
decisions remain in force.

## Superseded by

The 2026-07-27 removal of the top-level `managed_security_groups` map supersedes
Confirmation item 3 only as to its declaration path. The world-open ingress ban
remains current and is enforced on
`all_systems[*].managed_security_group.ingress`.

The later 2026-07-27 relocation from the system-level inline object to flat
network-interface rule attributes supersedes that declaration path again. The
ban remains current and is now enforced on
`all_systems[*].network_interfaces[*].ingress`.

The 2026-08-07 removal of IPv6 from network-interface rule inputs supersedes the
IPv6 half of the original ingress baseline and Confirmation item 3. The framework
is IPv4-only, so IPv6 ingress validation and negative tests are no longer required.

## Implementing PRs

None yet. T19 introduces this ADR and its implementation together; the merged PR
may be added here later.

## Related ADRs

- [Template ADR-template/0002](../template/0002-keep-reference-framework-credential-free.md)
  defines the inherited framework surface and permits repository-tier
  supersession.

## Compliance Notes

This decision is an engineering control-placement rule, not a claim of
compliance with a particular framework. The Terraform validations and tests are
reviewable evidence that the stated ingress, security-group attachment,
encryption, and metadata-service baselines are enforced in module code.

## Changelog

| Date       | Change                                             | Reason                                        | Author/Role          | Body-diff? |
| ---------- | -------------------------------------------------- | --------------------------------------------- | -------------------- | ---------- |
| 2026-08-07 | Removed IPv6 ingress checks. | Inputs are IPv4-only. | Portfolio maintainer | Yes |
| 2026-07-27 | Removed the top-level managed security-group path. | Keep security-group creation system-specific while retaining the ingress baseline on inline groups. | Portfolio maintainer | Yes        |
| 2026-07-22 | Accepted the hardcode-first security baseline ADR. | Record the maintainer's enforcement ruling.   | Portfolio maintainer | Yes        |
| 2026-07-22 | Sanctioned `imds_hop_limit` as a validated input.  | Container hosts need hop limit 2; bounded 1-2 with explicit-null rejection per the exposure rule this ADR defines. | Portfolio maintainer | Yes        |
