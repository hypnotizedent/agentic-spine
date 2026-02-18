---
loop_id: LOOP-SPINE-GRAPH-TIMELINE-V1-20260218
opened: 2026-02-18
status: active
owner: "@ronny"
severity: high
scope: spine-graph-timeline-v1
---

# Loop Scope: Spine Graph + Timeline V1 (Final Adjusted Plan)

## Summary

Implement graph/timeline in the existing evidence plugin, with shared runtime path resolution and strict path authority boundaries, explicit capability/map registration, schema-convention-aligned fields, and resilience/concurrency test coverage.

## Path Authority Contract (Explicit)

### Repo-authoritative sources

- `/Users/ronnyworks/code/agentic-spine/receipts/sessions`
- `/Users/ronnyworks/code/agentic-spine/mailroom/state/loop-scopes`
- `ops/bindings/operational.gaps.yaml`

### Runtime-authoritative sources

- `${SPINE_STATE}` and `${SPINE_OUTBOX}` for ledger, handoffs, orchestration, proposals, and audits.
- Loop scopes remain repo-local even when runtime contract is active.

## Public Interfaces

- `spine.graph.show` (read-only)
- `spine.timeline.query` (read-only)
- `spine.timeline.report` (mutating)

## Data Contracts

Add bindings:

- `ops/bindings/spine.execution.graph.yaml`
- `ops/bindings/spine.execution.graph.schema.yaml`
- `ops/bindings/spine.timeline.event.schema.yaml`

Timeline event fields:

- Required: `id`, `created_at`, `event_type`, `subject_type`, `subject_id`, `status`, `loop_id`, `capability`, `source_path`, `summary`
- Optional: `severity`, `actor_id`

Gap state source is always `ops/bindings/operational.gaps.yaml`.

## Implementation Steps

1. Register loop/gaps for this lane before mutation.
2. Add shared runtime resolver library: `ops/lib/runtime-paths.sh`.
3. Reuse `runtime-paths.sh` in `ops/commands/cap.sh`, `ops/commands/run.sh`, handoff scripts, `ops/plugins/audit/bin/agent-session-closeout`, and `ops/plugins/briefing/bin/briefing-section-work`.
4. Extend existing evidence plugin with:
   - `ops/plugins/evidence/bin/spine-graph-show`
   - `ops/plugins/evidence/bin/spine-timeline-query`
   - `ops/plugins/evidence/bin/spine-timeline-report`
5. Keep evidence scripting conventions consistent: `--help`, `--json`, deterministic envelope, argument validation failure with `FAIL` + exit `2`.
6. Query source order: receipt index first, then runtime state/outbox, optional full receipt scan only with explicit flag.
7. Report outputs default to `spine-timeline-latest.md` and `spine-timeline-latest.json`.
8. Explicitly update:
   - `ops/capabilities.yaml`
   - `ops/bindings/capability_map.yaml`
   - `ops/plugins/MANIFEST.yaml`
9. Add governance docs and register them in `docs/governance/_index.yaml`.

## Verification / Tests

- D67 parity check after manual capability/map edits.
- D84 docs index registration lock for new governance docs.
- D129/schema conventions check for new bindings.
- Runtime fallback tests: `active:true` and `active:false` behavior for runtime vs repo paths.
- Empty-state handling: missing/empty ledger, handoffs, orchestration, proposals, receipt index.
- Time-window correctness: timezone handling and cross-midnight windows.
- Concurrency determinism: repeated concurrent `spine.timeline.report` runs produce deterministic content/order.
- Multi-terminal policy enforcement: `spine.timeline.report` blocked for direct execution when effective policy is proposal-only.

## Governance Rule

`spine.timeline.report` is mutating; in multi-terminal mode it is writer-lane only via proposal/apply flow when policy enforces proposal-only writes.

## Assumptions

- Foundational schema/yaml loops remain baseline complete.
- `ops ssot list` work is out of scope.
- Scope remains spine core only.
