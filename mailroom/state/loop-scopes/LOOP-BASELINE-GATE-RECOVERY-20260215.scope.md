---
loop_id: LOOP-BASELINE-GATE-RECOVERY-20260215
created: 2026-02-15
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Restore spine baseline by resolving non-media drift gate failures D3, D14, D15, D48, D75, D87, and D90.
---

## Problem Statement

Post-media stabilization, `spine.verify` still fails on non-media gates that block baseline readiness. Failures include entrypoint preflight stop conditions, stale worktree hygiene, and multiple gate-contract mismatches in cloudflare/github/rag surfaces.

## Deliverables

- Register and fix newly discovered gate/runtime defects under this loop.
- Clean stale/orphaned worktree state that blocks D48 and preflight.
- Correct D14/D15 and D87 gate logic where enforcement scope mismatches runtime implementation.
- Resolve D90 false failures caused by historical log accumulation (existing GAP-OP-385).
- Re-run verification and capture receipts.

## Acceptance Criteria

- `./bin/ops preflight` passes without degraded override.
- Targeted gates D3, D14, D15, D48, D75, D87, D90 pass.
- Any remaining `spine.verify` failures are outside this loop scope and explicitly identified.

## Constraints

- Follow work-discovery-first policy; file gaps before fixes.
- Do not alter unrelated domains beyond required gate wiring or runtime contracts.
- Keep changes deterministic and governance-traceable.

## Closure Summary

- Fixed gates and contracts: D48, D75, D87, D14, D15.
- Implemented GAP-OP-385 fix: RAG runtime failure counters now scope to latest `START rag sync` segment in:
  - `ops/plugins/rag/bin/rag-reindex-remote-status`
  - `ops/plugins/rag/bin/rag-reindex-remote-verify`
  - `surfaces/verify/d90-rag-reindex-runtime-quality-gate.sh`
- Closed child gaps: GAP-OP-423, GAP-OP-424, GAP-OP-425, GAP-OP-426.
- Closed related semantics gap: GAP-OP-385.

## Residual Out-of-Scope

- `spine.verify` may still fail D90 if the latest remote reindex run has real runtime failures
  (failed uploads/checkpoint residue). This is tracked by existing runtime recovery gap:
  `GAP-OP-370`.
