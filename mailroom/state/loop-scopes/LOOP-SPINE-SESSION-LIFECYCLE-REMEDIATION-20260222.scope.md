---
loop_id: LOOP-SPINE-SESSION-LIFECYCLE-REMEDIATION-20260222
created: 2026-02-22
status: active
owner: "@ronny"
scope: spine
priority: high
objective: Rebuild startup/session lifecycle into a fast-by-default workflow while preserving safety gates, Mailroom routing, and release-cert rigor.
---

# Loop Scope: LOOP-SPINE-SESSION-LIFECYCLE-REMEDIATION-20260222

## Objective

Rebuild startup/session lifecycle into a fast-by-default workflow while preserving safety gates, Mailroom routing, and release-cert rigor.

## Parent Gaps

- GAP-OP-817

## Problem Statement

Current day-to-day startup behavior is running heavyweight reliability and verification commands before useful work begins.
This creates avoidable latency, battery drain, and context bloat, and encourages bypass behavior.

## Deliverables

- Startup lifecycle audit with measured wall-clock baselines and bottleneck attribution.
- Phased remediation plan that keeps governance guarantees while reducing startup tax.
- Mailroom proposal(s) for execution phases, with explicit gate/contract touch map.
- Verification strategy with fast-lane SLOs and fallback/full-lane controls.

## Acceptance Criteria

- A fast startup lane is defined and governed (target <10s p95 for day-to-day entry).
- Heavy checks are explicitly deferred to post-work, mutation-time, or full-cert lanes.
- Entry surface contract and related gates are updated without breaking D124/D65 invariants.
- Operator has a clear, sequenced rollout path with rollback points.

## Constraints

- Do not weaken mutation safety controls for critical domains.
- Keep receipts and proposal routing as mandatory execution boundaries.
- Preserve release/nightly certification lane semantics.
- Maintain compatibility across Codex/Claude/OpenCode entry surfaces.

## Initial Verification Matrix

- `./bin/ops status --brief`
- `./bin/ops cap run proposals.list`
- `./bin/ops cap run proposals.reconcile`
- `./bin/ops cap run verify.route.recommend`

## Notes

- Planning and registration started on 2026-02-22.
- Execution patch set is tracked via CP draft-hold and will be promoted to pending after owner review.
