---
loop_id: LOOP-MAILROOM-2-0-PLANS-LIFECYCLE-CANONICAL-FIX-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: loop_gap
priority: high
horizon: later
execution_readiness: blocked
activation_trigger: manual
blocked_by:
  - "Wave 2 implementation pending commit + verify evidence"
next_review: "2026-03-19"
objective: Eliminate plans lifecycle drift, add canonical contract/control-plane, and enforce index/projection parity with lock discipline.
---

# Loop Scope: LOOP-MAILROOM-2-0-PLANS-LIFECYCLE-CANONICAL-FIX-20260303

## Objective

Deliver Mailroom 2.0 plans lifecycle hardening so plans have canonical lifecycle
contracts/capabilities, lock-safe mutators, scheduled enforcement, and dual-surface
(index vs PLAN-*.md projection) reconciliation.

## Wave Deliverables

1. `ops/bindings/plans.lifecycle.yaml` as canonical lifecycle authority.
2. New capabilities: `planning.plans.status`, `planning.plans.reconcile`, `planning.plans.archive`.
3. Lock discipline on plan mutators (`create/promote/retire/cancel`).
4. Dedicated plans lifecycle verify lock and scheduled enforcement.
5. Reconcile/fix path for legacy statuses and projection drift.

## Guard Commands

- `./bin/ops cap run verify.run -- fast`
- `./bin/ops cap run verify.run -- domain loop_gap`
- `./bin/ops cap run planning.plans.status`
- `./bin/ops cap run planning.plans.reconcile -- --check`

## Definition Of Done

- Plan index uses canonical statuses only.
- Legacy statuses are tombstoned via reconcile mapping.
- Orphan/stale projection drift is detectable and fixable.
- Plan mutators are lock-safe.
- Daily scheduler path includes loop-gap lifecycle enforcement.
