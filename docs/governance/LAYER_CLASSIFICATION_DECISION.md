---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-29
scope: layer-classification-decision
version: 1.0
source_triangulation:
  - docs/governance/LAYER_CLASSIFICATION_DISCOVERY.md
  - docs/governance/PLATFORM_LAYER_MODEL.md
  - docs/governance/GIT_WORKFLOW_DISCIPLINE.md
  - docs/governance/AUTONOMOUS_MULTI_NODE_VISION.md
  - docs/governance/SPINE.md
  - NORTH_STAR.md
  - ops/bindings/governed.change.lifecycle.contract.yaml
machine_enforcement: not_yet_machine_enforced
---

# Layer Classification Decision

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.layer-classification`

## Authoritative Discovery Artifact Path

- `/Users/ronnyworks/code/agentic-spine/docs/governance/LAYER_CLASSIFICATION_DISCOVERY.md`

## Exact Decision On Whether `layer` Is Added

- Yes.
- `layer` should be added as a governed capability-metadata axis alongside
  `domain` and `plane`.
- `domain` remains the ownership axis.
- `plane` remains the execution-surface axis.
- `layer` becomes the primitive-function axis.
- Layer classification does not replace or collapse domain ownership truth.

## Allowed Layer Values

- `L1_engine`
- `L2_shared_infrastructure`
- `L3_product_runtime`

## Granularity Rules

- Family-level classification is allowed only when the entire family passes one
  layer test without internal seams.
- Sub-family classification is required when one prefix contains multiple
  primitive clusters that can be separated truthfully below the family root.
- Capability-level classification is required when the seam is driven by one
  exact capability, a tool-prefixed primitive, or a provider-local exception.
- Mixed residue must be handled with mixed granularity depending on the seam;
  one fixed granularity is not truthful for the remaining `domain: none`
  residue.
- Automatic `core` growth is closed absent new explicit justification; a family
  that leans engine-like still requires primitive-function proof rather than
  default lift into `core`.

## Handling Rules For Mixed Seams

- `mixed` is rejected as a metadata value.
- Mixed cases must be resolved by dropping to lower granularity until one of
  `L1_engine`, `L2_shared_infrastructure`, or `L3_product_runtime` is truthful.
- A mixed family is not a reason to invent a fourth layer or to blur distinct
  primitives into one classification.
- Small L3 pockets may be classified as `L3_product_runtime` without forcing
  their parent family or neighboring capabilities into L3.
- Residual governance and control-plane seams may land in `L1_engine`, but only
  when the L1 test is satisfied by the primitive itself.

## Treatment Of Provider Surfaces And Tool Seams

- Provider-named families are not layers.
- Provider surfaces must be classified by primitive function:
  - control-plane observation or governance primitives may land `L1_engine`
  - reusable provider transport or shared publication rails may land
    `L2_shared_infrastructure`
  - product-local provider behavior may land `L3_product_runtime`
- Tool-prefixed seams must not inherit layer from the tool name alone.
- Capabilities such as `codex.worktree.status`, `git.stage.commit.scoped`,
  `git.merge.safe`, `capability.map.projection.build`, and
  `catalog.domain.sync` must be classified by the primitive they operate, not
  by their prefix.

## Implementation Boundary

- The later implementation stage should:
  - add a `layer` field to selected governed capability records in
    `/Users/ronnyworks/code/agentic-spine/ops/capabilities.yaml`
  - classify the remaining residue using the elected mixed
    family/sub-family/capability boundary
  - teach
    `/Users/ronnyworks/code/agentic-spine/ops/plugins/core/authority/bin/capability-map-projection-build`
    to project `layer`
  - regenerate `/Users/ronnyworks/code/agentic-spine/ops/bindings/capability_map.yaml`
  - add or update targeted verification so allowed values, no-`mixed` posture,
    and projection parity are machine-checkable
- The later implementation stage should not require:
  - domain reassignment
  - plane reassignment
  - `ops/bindings/capability.domain.catalog.yaml` edits
  - domain bundle or domain doc rewrites
  - plugin directory renames
  - binding directory renames
  - capability id or prefix renames
  - routing-dispatch changes

## Non-Goals

- no election artifact in this decision pass
- no `layer` schema implementation in this decision pass
- no capability metadata mutation in this decision pass
- no domain, plane, or capability-id changes
- no new domains such as `engine` or `platform`
- no retirement/removal decision
- no contract-enforcement implementation
- no git-workflow implementation
- no autonomous multi-node implementation
- no H3 publication implementation
- no extraction work

## Exact Proposed Next Action

- `layer_classification_election`
