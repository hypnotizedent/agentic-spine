---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-29
scope: layer-classification-election
version: 1.0
source_triangulation:
  - docs/governance/LAYER_CLASSIFICATION_DISCOVERY.md
  - docs/governance/LAYER_CLASSIFICATION_DECISION.md
  - docs/governance/PLATFORM_LAYER_MODEL.md
  - ops/bindings/governed.change.lifecycle.contract.yaml
machine_enforcement: not_yet_machine_enforced
---

# Layer Classification Election

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.layer-classification`

## Authoritative Discovery Artifact Path

- `docs/governance/LAYER_CLASSIFICATION_DISCOVERY.md`
- Commit: `c0408377`

## Authoritative Decision Artifact Path

- `docs/governance/LAYER_CLASSIFICATION_DECISION.md`
- Commit: `b77443e0`

## Exact Elected Result

- `authorize_layer_classification_implementation`

## Explicit Rationale

- Discovery bounded the remaining 68 `domain: none` capabilities by family,
  produced provisional layer buckets using the L1/L2/L3 tests from
  `PLATFORM_LAYER_MODEL.md`, identified mixed families requiring
  lower-granularity treatment, and closed both ownership-only tranches and
  automatic `core` growth.
- Decision ratified `layer` as a separate primitive-function metadata axis
  alongside `domain` (ownership) and `plane` (execution-surface), fixed the
  allowed values to `L1_engine`, `L2_shared_infrastructure`, and
  `L3_product_runtime`, rejected `mixed` as a metadata value, and defined the
  exact implementation boundary and non-goals.
- Both stage artifacts are durable, version-controlled, and committed on `main`,
  satisfying the V2 lifecycle persistence gate.
- No unresolved open question blocks implementation. The seven open questions
  from discovery are answerable within the implementation boundary using the
  decided granularity rules.

## Whether Implementation Is Authorized Now

- Yes.

## Exact Authorized Implementation Boundary

- Add a `layer` field to selected governed capability records in
  `ops/capabilities.yaml`.
- Classify the remaining 68 `domain: none` capabilities using the elected mixed
  family/sub-family/capability granularity.
- Teach `ops/plugins/core/authority/bin/capability-map-projection-build` to
  project `layer`.
- Regenerate `ops/bindings/capability_map.yaml`.
- Add or update targeted verification so allowed values, no-`mixed` posture,
  and projection parity are machine-checkable.

## What Is Explicitly Not Authorized

- Domain reassignment.
- Plane reassignment.
- `ops/bindings/capability.domain.catalog.yaml` edits.
- Domain bundle or domain doc rewrites.
- Plugin directory renames.
- Binding directory renames.
- Capability id or prefix renames.
- Routing-dispatch changes.
- New domains such as `engine` or `platform`.
- Retirement or removal decisions.
- Contract-enforcement implementation beyond layer verification.
- Git workflow implementation.
- Autonomous multi-node implementation.
- H3 publication.
- Extraction work.

## Preserved Non-Goals

- No further ownership-only tranche remains justified.
- Automatic `core` growth remains closed absent new explicit justification.
- Git workflow discipline remains a separate doctrine concern.
- Autonomous multi-node operation remains a separate downstream `new_truth`.
- H3 publication remains inactive.
- Extraction remains inactive.
- Cowork remains `out_of_scope_until_governed_adapter_exists`.

## Exact Next Action

- `layer_classification_implementation`
