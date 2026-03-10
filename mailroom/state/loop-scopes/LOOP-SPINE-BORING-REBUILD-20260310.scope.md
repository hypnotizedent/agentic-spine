---
loop_id: LOOP-SPINE-BORING-REBUILD-20260310
created: 2026-03-10
status: active
owner: "@ronny"
scope: agentic-spine
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Make agentic-spine boring again by classifying every folder and file, extracting runtime concerns out of spine, and defining the productized public starter surface without destructive moves
---

# Loop Scope: LOOP-SPINE-BORING-REBUILD-20260310

## Objective

Make agentic-spine boring again by classifying every folder and file, extracting runtime concerns out of spine, and defining the productized public starter surface without destructive moves.

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Worktree hygiene**: `./ops/plugins/ops/bin/worktree-lifecycle-reconcile --brief`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "spine boring rebuild checkpoint" --loops LOOP-SPINE-BORING-REBUILD-20260310`

## Context

The spine accumulated too many responsibilities at once:
- governance and control-plane source
- live mailroom/runtime state
- receipts and machine evidence
- migration/archive residue
- operator memory and planning seams

This produced governance bloat, ceremonial drift gates, branch/worktree confusion, and uncertainty about what the spine actually is.

The corrective mission is not a blind move-things-around cleanup. The mission is a deep qualification pass:
- read every folder and file inside agentic-spine
- determine whether each artifact is spine-worthy
- define what must leave the spine and what must remain
- define how to keep the spine boring and lean after the extraction
- define the public productized starter surface for GitHub

## Non-Destructive Rules

1. First pass is classification, not relocation.
2. Do not move or delete files just to make the tree look cleaner.
3. If an item is unclear, classify it as `needs-operator-decision` and continue.
4. Do not stop the mission at a blocker; record the blocker and keep auditing adjacent surfaces.
5. Runtime, evidence, archive, and source must be judged as separate artifact classes.
6. Any proposed extraction must preserve current behavior until explicitly promoted.

## Classification Rubric

Every folder and file must land in exactly one primary bucket:

- `spine-source`: belongs in the boring control plane (commands, bindings, policies, verification, canonical docs, fixtures)
- `runtime-only`: live queue/state/log/lease/session output that should not live in the spine repo
- `evidence-only`: receipts/proof/audit artifacts that may be retained but should not live beside governance source
- `foundation-source`: reusable extracted source that belongs in a pulled-out foundation/runtime repo or root outside `agentic-spine`
- `archive-only`: historical residue that should not stay in the hot path
- `needs-operator-decision`: ambiguous item that needs explicit judgment before move/promote/retire

## Lanes

### Lane A: Root, Entry, and Workflow Contracts
Scope:
- repo root
- `bin/`
- top-level repo contracts
- git/worktree/handoff workflow surfaces

Outcome:
- determine what the boring spine root should own
- determine which workflow surfaces are canonical vs legacy overlap

### Lane B: Engine and Capability Surfaces
Scope:
- `ops/`

Outcome:
- classify source-only vs archive/staged/generated residue
- determine what the actual boring control-plane engine should contain

### Lane C: Verification, Docs, and Fixtures
Scope:
- `surfaces/`
- `docs/`
- `fixtures/`

Outcome:
- identify canonical vs duplicate vs generated vs archive documentation/policy surfaces
- determine what human-facing control-plane documentation is truly live

### Lane D: Mailroom, Receipts, and Runtime Extraction
Scope:
- `mailroom/`
- `receipts/`
- runtime-linked state referenced from spine

Outcome:
- define exact boundary between spine-source, runtime, and evidence
- produce extraction map for moving mailroom/runtime concerns out of spine

### Lane E: Productization and Public Starter Surface
Scope:
- what remains after extraction
- what belongs in a reusable foundation
- what belongs in the public GitHub starter surface

Outcome:
- define the public product shape
- define the private/internal Ronny operator shape
- define the foundation root for what is pulled out of spine

## Phases

1. Baseline inventory and boringness criteria lock
2. Parallel folder-by-folder and file-by-file qualification sweep
3. Runtime/evidence/foundation boundary synthesis
4. Public starter surface synthesis
5. Non-regression guard design so the spine cannot become messy again
6. Final review, promotion decisions, and closeout

## Success Criteria

- Every top-level folder in `agentic-spine` is classified as source, runtime, evidence, foundation, archive, or decision-needed
- Every subfolder and file touched by the sweep has an explicit qualification result
- A clear boring definition exists for the spine root and each hot-path subfolder
- Mailroom extraction boundary is explicit, not implied
- The public GitHub starter surface is defined as a product, not a mirror of Ronny's live operator repo
- A non-regression model exists so future growth stays boring instead of ceremonial

## Definition Of Done

- The spine has a written boringness contract
- The mailroom/runtime extraction target is fully defined
- The foundation root for extracted reusable surfaces is defined
- The public GitHub starter surface is defined
- All major ambiguities are either resolved or isolated as explicit operator decisions
- The loop can be handed from parallel workers back to coordination without rediscovery
