---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-29
scope: governed-change-lifecycle-persistence-gate-discovery
version: 1
machine_enforcement: not_yet_machine_enforced
source_triangulation:
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/bindings/spine.surface.metabolism.registry.yaml
  - ops/plugins/core/verify/tests/test-governed-change-lifecycle-companion-contract.sh
  - docs/governance/GIT_WORKFLOW_DISCIPLINE.md
---

# Governed Change Lifecycle — Persistence Gate Discovery

## Parent Loop

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`
- Concern: `post-h2.governed-change-lifecycle-persistence-gate-enforcement`
- Change class: `new_truth`

## The Gap

The governed change lifecycle contract defines exit evidence for pre-implementation
stages but does not specify where that evidence must reside:

| Stage | Exit Evidence Language | Contract Line |
|---|---|---|
| discovery | "Discovery artifact or equivalent evidence summary exists." | 72 |
| decision | "Decision packet or equivalent synthesis exists." | 79 |
| election | "Election packet/status records one exact result." | 87 |

No verify gate checks whether stage evidence is durable (version-controlled) or
ephemeral (chat, terminal, `.runtime`-only).

### Consequence

Important governed discoveries — the L2 insight, autonomous multi-node vision, git
workflow discipline, reconciliation stop-condition — all landed as committed repo
artifacts. But they did so because the operator and controller chose to commit them,
not because any gate enforced it.

Had any of these stopped at discovery or decision and the session ended, the evidence
would have been chat-only or `.runtime`-only — both ephemeral.

### Current Test Coverage

`test-governed-change-lifecycle-companion-contract.sh` validates contract structure
only: stage names, route classes, metabolism routes. It does NOT validate whether any
stage evidence actually exists for any concern, whether evidence is at a durable
location, or whether `.runtime` or chat satisfies durability.

### Metabolism Registry Classification

The metabolism registry classifies `governance_core` as
`active_not_yet_machine_enforced` with
`recommended_next_action: declared_but_unwired_contract_enforcement`. This aligns with
the gap.

### `.runtime` Is Not Durable

`.runtime` is not a git repository. Files there are not version-controlled, have no
commit history, are not SHA-addressable, and are local to one workstation. `.runtime`
status artifacts are operationally useful but do not satisfy version-controlled
persistence requirements.

## Bootstrap Path

### The Tension

This concern is `new_truth`. The contract requires (line 151):

> No repo-owned mutation before implementation_authorized.

Creating a repo-backed discovery artifact is a file creation in the repo tree.

### Resolution

"Repo-owned mutation" in the `new_truth` route context refers to the implementation
changes the concern proposes — the contract edit and verify gate wiring. A discovery
artifact records analysis findings; it does not implement the concern's meaning change.

The contract's own exit evidence rules require discovery artifacts to exist (line 72).
Creating them in the repo is the way to make them durable.

Precedent: `cc4c1b05` (git workflow discipline) and `cd6848f0` (autonomous multi-node
vision) both committed governance discovery documents before implementation
authorization.

The bootstrap contradiction is partial, not absolute. A strict reading of "no
repo-owned mutation" could include any file creation. The reasonable reading
distinguishes stage evidence from implementation. This tension is itself evidence for
why the contract needs explicit durability language — which is part of the
implementation target below.

## Enforcement Target

### Contract Changes Required

In `ops/bindings/governed.change.lifecycle.contract.yaml`:

1. **Add `stage_evidence_durability` section** under `stage_model`:
   - Durable locations: any committed path within the git working tree
   - Non-durable locations (insufficient alone): chat, terminal scrollback, untracked
     local files, `.runtime`-only state
   - `.runtime` status artifacts remain valid for operational tracking but do not
     alone satisfy stage evidence durability
   - Stage evidence may be repo-backed artifact content or a repo-backed pointer to
     governed content — both are valid

2. **Update discovery exit evidence** (line 72):
   - From: "Discovery artifact or equivalent evidence summary exists."
   - To: "Discovery artifact or equivalent evidence summary exists at a durable,
     version-controlled path."

3. **Update decision exit evidence** (line 79):
   - From: "Decision packet or equivalent synthesis exists."
   - To: "Decision packet or equivalent synthesis exists at a durable,
     version-controlled path."

4. **Update election exit evidence** (line 87):
   - From: "Election packet/status records one exact result."
   - To: "Election packet/status records one exact result at a durable,
     version-controlled path."

5. **Clarify `new_truth` mutation boundary** (line 151):
   - Stage evidence artifacts (discovery, decision, election) are not implementation
     mutations. Implementation mutations are the changes the concern proposes to
     governed surfaces.

### Verify Gate

| Property | Value |
|---|---|
| What it checks | Contract contains `stage_evidence_durability` section with explicit durable and non-durable location lists |
| Location | `ops/plugins/core/verify/tests/test-governed-change-lifecycle-stage-evidence.sh` |
| Wired into | `verify fast` via the existing gate registry |
| Scope | Structural — validates the contract includes durability language |
| Follow-on | Full concern-level evidence auditing is a separate future gate |

### Durability Classification

| Location | Durable | Reason |
|---|---|---|
| Committed file in git tree | Yes | Version-controlled, SHA-addressable |
| `.runtime/` file | No | Not version-controlled, local-only |
| Chat transcript | No | Ephemeral, compacts, session-bound |
| Terminal scrollback | No | Ephemeral |
| Untracked local file | No | Lost on cleanup |

## Election

Result: `supersede_layer_prep_with_persistence_gate_decision`

The persistence gap is more foundational than layer classification:
1. Layer classification will produce `new_truth` discovery/decision/election outcomes
2. Without persistence gates, those outcomes face the same ephemeral-evidence risk
3. Fixing persistence first ensures all subsequent `new_truth` work has durable evidence
4. The metabolism registry recommended `declared_but_unwired_contract_enforcement`

Layer classification preparation is deferred to immediately after persistence gate
implementation lands. `docs/governance/PLATFORM_LAYER_MODEL.md` remains authoritative.
No layer-model truth is discarded.

## Exact Next Action

1. Operator review of this discovery artifact
2. If accepted: authorize implementation (contract edit + verify gate)
3. Implementation pass edits `governed.change.lifecycle.contract.yaml` and creates
   `test-governed-change-lifecycle-stage-evidence.sh`
4. After persistence gate lands: resume `layer_classification_preparation`
