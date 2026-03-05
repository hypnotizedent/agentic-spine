---
loop_id: LOOP-MAILROOM-2-0-PLANS-LIFECYCLE-CANONICAL-FIX-20260303
created: 2026-03-03
status: closed
closed_at: "2026-03-05"
owner: "@ronny"
scope: loop_gap
priority: high
horizon: later
execution_readiness: runnable
activation_trigger: manual
blocked_by: []
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

## Close Summary

- `ops/bindings/plans.lifecycle.yaml` is live as canonical plans lifecycle authority.
- Lifecycle mutators and status surfaces are present: `planning.plans.status`, `planning.plans.reconcile`, `planning.plans.archive`, `planning.plans.retire`.
- `GAP-OP-1496` is fixed with regression lock `D343`.
- Plans status is clean with zero noncanonical rows or projection drift.

## Execution Evidence

- `CAP-20260305-172114__planning.plans.status__Rd96r44107`
- `CAP-20260305-172117__loops.status__Rtyx443790`
- `GAP-OP-1496`
- `D343`
