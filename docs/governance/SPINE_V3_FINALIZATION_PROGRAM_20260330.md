---
status: authoritative
owner: "@ronny"
scope: spine-v3-finalization-program
updated_at: 2026-03-31
---

# Spine V3 Finalization Program 2026-03-30

## Canonical Status

This document is the elected authority for finishing the current V3 spine overhaul.

It exists to end the open-ended overhaul pattern and replace it with one bounded close-condition program. V3 is complete when this program is complete. Until then, the spine is still in finalization.

## Canonical Parent Loop

- Parent loop: `/Users/ronnyworks/code/.runtime/spine/state/loop-scopes/LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326.scope.md`

Lean correction:

- No new competing parent loop is created.
- The existing spine closure parent remains the single active parent authority.
- V3 finalization now becomes its canonical next phase.

## Supporting Boundaries

The following files are relevant to this program, but they are not equal in authority:

- `/Users/ronnyworks/code/agentic-spine/ops/bindings/node.role.contract.yaml` is the live node-boundary authority for physical-node taxonomy and role semantics.
- `/Users/ronnyworks/code/agentic-spine/docs/governance/LOCAL_CONTROL_PLANE_CONTRACT.md` is current authority for local node and filesystem reality on the operator workstation.
- `/Users/ronnyworks/code/agentic-spine/docs/governance/EXECUTION_NODE_SPEC.md` is explicitly historical and non-authoritative. It may inform archive or future design work, but it does not define the live V3 boundary.
- The engine-map visual at `/Users/ronnyworks/code/agentic-spine/ops/archive/pre-2026-04-01-spine/visuals/SPINE_V3_FINALIZATION_ENGINE_MAP_20260330.html` is support material only. It is useful for operator orientation, but it is not a governing contract.

## Purpose

Finish V3 as a usable governed autonomous execution system, stop the endless overhaul cycle, and move the spine from being worked on to being used.

## Final Form

The first-string V3 engine is exactly these eight pieces:

1. Session Entry
   - `session.v3.attach`
   - entry packet
   - runtime and role bootstrap
2. Control Loop
   - `spine.control.tick`
   - `spine.control.plan`
   - `spine.control.execute`
   - `spine.control.cycle`
3. Orchestration
   - `orchestration.loop.open`
   - `wave.execute`
   - `wave.finish`
   - `session.execution.lane.*`
4. Dispatch Backbone
   - `mailroom.task.enqueue`
   - the minimal live mailroom worker and bridge path under `ops/plugins/infra/mailroom-bridge/`
5. Continuity
   - `loops.*`
   - `gaps.*`
   - `session.handoff.*`
   - `friction.*`
   - loop and gap closeout / continuity update path
6. Observation, Evidence, And Telemetry
   - `receipts.exec.emit`
   - `receipts.search`
   - `receipts.summary`
   - `receipts.trends`
   - `spine.timeline.query`
   - `spine.graph.show`
   - `spine.surface.usage.telemetry`
   - `lifecycle.health`
7. Verification And Recovery
   - `verify.core.run`
   - `verify.pack.run`
   - `verify.gate_quality.scorecard`
   - recovery surfaces
8. Translator Boundary
   - `TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`
   - translator emits packets, not execution or verdicts

Everything else folds under these, belongs to domain/runtime work, or moves to archive.

## Operating Rules

Only two sprint types are legal:

- `work_sprint`
- `reduction_sprint`

One sprint type is illegal:

- `ceremonial_sprint`

Definitions:

- `work_sprint`: use the spine to do a real operator task; only bounded blocker fixes allowed.
- `reduction_sprint`: fold, eliminate, or trim one engine seam; it must reduce surfaces or improve planner selection.
- `ceremonial_sprint`: classification, governance, or documentation work that does not reduce or produce an operator outcome.

## Time Budget Rule

Each subloop has a hard time ceiling.

- If a subloop cannot close inside its budget, scope must be cut.
- Ronny makes the cut decision.
- Codex does not expand time or widen scope to preserve its own plan.

## Continuity Rule

Each subloop must produce one continuity artifact that becomes the only required bootstrap for the next subloop.

The continuity artifacts live under:

- `/Users/ronnyworks/code/.evidence/spine/reports/finalization/`

The next subloop may use the repo and runtime state, but it must not depend on chat reconstruction.

## Execution Discipline Correction

Remaining finalization slices must not repeat the sloppy pattern of governed wave state wrapped around single-terminal manual execution.

Correction rules:

- every wave must declare whether it is genuinely delegated or explicitly `single_terminal_mode`
- `single_terminal_mode` is an exception, not the default
- execution and audit ownership must be assigned before the next reduction slice starts
- manual wave-adoption fallback must be declared as residue up front if no governed adoption surface exists
- if a required orchestration surface is missing, stop and fix the surface or cut scope; do not silently continue as if the engine already supports the step

Trace authority for this correction:

- `/Users/ronnyworks/code/.evidence/spine/reports/finalization/SPINE_V3_EXECUTION_DISCIPLINE_AND_SUBAGENT_ORCHESTRATION_TRACE_20260331.md`

## Program Subloops

### 1. Prefight And Election

- Loop: `LOOP-SPINE-V3-PREFLIGHT-AND-ELECTION-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_PREFLIGHT_AND_ELECTION_20260330.md`
- Purpose:
  - freeze scope
  - baseline dirty and in-flight state
  - elect this program

### 2. Starting Lineup, Cut List, And Workbench Boundary

- Loop: `LOOP-SPINE-V3-STARTING-LINEUP-CUTLIST-AND-WORKBENCH-BOUNDARY-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_STARTING_LINEUP_AND_CUTLIST_20260330.md`
- Purpose:
  - elect first string
  - elect cut list
  - classify `implementation_repo: workbench` capabilities

Rules:

- `spine.surface.usage.telemetry` and `spine.surface.metabolism.registry.yaml` drive the cut list
- they do not auto-archive anything by themselves
- the keep / fold / archive decision is still explicit and elected

Current counted workbench block:

- `157` capabilities with `implementation_repo: workbench`

### 3. Planner And Observation Wiring

- Loop: `LOOP-SPINE-V3-PLANNER-AND-OBSERVATION-WIRING-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_PLANNER_AND_OBSERVATION_WIRING_20260330.md`
- Target file: `/Users/ronnyworks/code/agentic-spine/ops/plugins/core/evidence/bin/spine-control`
- Co-authority file: `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_NORMALIZATION_KERNEL_20260326.md`

Exact seam:

- `SPINE_NORMALIZATION_KERNEL_20260326.md` surviving-set landing
- `build_plan_payload()`
- `derive_route_hint()`
- `run_control_cycle()`

Required change shape:

- land the kernel surviving-set reduction as live authority, not as chat residue
- use loop priority and age instead of naive ordering
- route spine/platform work explicitly
- consume live observation signals instead of collecting them and ignoring them
- make closure-critical work outrank shallow churn when present

### 4. Lean Repo Cutover

- Loop: `LOOP-SPINE-V3-LEAN-REPO-CUTOVER-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_LEAN_REPO_CUTOVER_20260330.md`
- Archive boundary:
  - `/Users/ronnyworks/code/agentic-spine/ops/archive/pre-2026-04-01-spine/`

### 5. Docs Minimum Canon

- Loop: `LOOP-SPINE-V3-DOCS-MINIMUM-CANON-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_DOCS_MINIMUM_CANON_20260330.md`

Mandatory live canon is elected as:

- `/Users/ronnyworks/code/agentic-spine/NORTH_STAR.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/PLATFORM_LAYER_MODEL.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_NORMALIZATION_KERNEL_20260326.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/LOCAL_CONTROL_PLANE_CONTRACT.md`
- `/Users/ronnyworks/code/agentic-spine/docs/governance/EXECUTION_NODE_SPEC.md` only if it is rewritten and re-elected as live authority; until then it remains historical and outside the minimum canon
- historical workflow-discipline writeups stay archived unless re-elected into the live canon

Governance doc budget:

- `8` mandatory
- `10` max live canon

Node-boundary correction:

- node truth is not required to live as a prose doc if the binding authority is stronger
- the live node-boundary authority is `/Users/ronnyworks/code/agentic-spine/ops/bindings/node.role.contract.yaml`
- `EXECUTION_NODE_SPEC.md` is not part of live canon unless re-elected from scratch

First safe docs archive slice:

- source: `/Users/ronnyworks/code/agentic-spine/docs/governance/EXECUTION_NODE_SPEC.md`
- destination: `/Users/ronnyworks/code/agentic-spine/ops/archive/pre-2026-04-01-spine/docs/governance/EXECUTION_NODE_SPEC.md`
- treatment:
  - historical
  - non-authoritative
  - archive through the docs loop wave path, not by ad hoc file movement

### 6. Self-Orchestrated Finalization Proof

- Loop: `LOOP-SPINE-V3-SELF-ORCHESTRATED-FINALIZATION-PROOF-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_SELF_ORCHESTRATED_FINALIZATION_PROOF_20260330.md`

This is the non-negotiable proof:

- if the spine cannot orchestrate its own finalization wave through its own workflow engine, V3 is not complete

### 7. Seven-Day Reconciliation

- Loop: `LOOP-SPINE-V3-7DAY-RECONCILIATION-20260330`
- Budget: `7 days`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_7DAY_RECONCILIATION_20260330_TO_20260405.md`

Daily shape:

- Day 1: starting-lineup smoke
- Day 2: one real work sprint
- Day 3: one reduction sprint on discovered residue only
- Day 4: continuity, handoff, and friction drill
- Day 5: verify and recovery drill
- Day 6: operator-offload drill
- Day 7: residue classification and go/no-go

### 8. Completion Declaration

- Loop: `LOOP-SPINE-V3-COMPLETION-DECLARATION-20260330`
- Budget: `1 session`
- Output artifact: `.evidence/spine/reports/finalization/SPINE_V3_COMPLETION_DECLARATION_20260330.md`

## Final Folder Shape

The live repo remains:

- `/Users/ronnyworks/code/agentic-spine/bin`
- `/Users/ronnyworks/code/agentic-spine/docs/core`
- `/Users/ronnyworks/code/agentic-spine/docs/governance`
- `/Users/ronnyworks/code/agentic-spine/fixtures`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings`
- `/Users/ronnyworks/code/agentic-spine/ops/commands`
- `/Users/ronnyworks/code/agentic-spine/ops/lib`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/core`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/infra`
- `/Users/ronnyworks/code/agentic-spine/ops/plugins/domains`
- `/Users/ronnyworks/code/agentic-spine/surfaces/verify`
- `/Users/ronnyworks/code/agentic-spine/ops/archive/pre-2026-04-01-spine`

## Hard Budgets

- parent finalization loop: `1`
- child subloops: `8`
- first-string engine pieces: `8`
- live operator-facing first-string surfaces: `25-35`
- live operational bindings target after cutover: `<=242` top-level `ops/bindings/*.yaml`
- domain subdirectory bindings under `ops/bindings/domains/*/` are governed domain truth and tracked separately from this control-plane reduction budget
- allowed sprint types: `2`
- forbidden sprint types: `1`

## Completion Gate

V3 is complete only when:

- the starting lineup is elected
- the workbench boundary is settled
- the planner uses observation signals
- the node boundary is represented by live authority files instead of historical aspirational drafts
- the archive boundary is real
- the docs canon is cut to minimum
- the spine proves it can orchestrate its own finishing move
- the seven-day reconciliation passes
- and the next session uses the spine instead of reopening “what is V3?”
