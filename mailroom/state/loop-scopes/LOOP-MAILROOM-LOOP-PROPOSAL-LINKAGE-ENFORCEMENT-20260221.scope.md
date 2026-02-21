---
loop_id: LOOP-MAILROOM-LOOP-PROPOSAL-LINKAGE-ENFORCEMENT-20260221
created: 2026-02-21
status: active
owner: "@ronny"
scope: mailroom
priority: high
objective: Enforce loop-proposal-gap linkage so loop work cannot complete without linked proposal lifecycle and status visibility.
---

# Loop Scope: LOOP-MAILROOM-LOOP-PROPOSAL-LINKAGE-ENFORCEMENT-20260221

## Objective

Enforce loop-proposal-gap linkage so loop work cannot complete without linked proposal lifecycle and status visibility.

## Canonical Fix Contract

1. Proposal admission hard gate:
`proposals.submit` must require explicit loop binding (`SPINE_LOOP_ID` or equivalent explicit arg) and fail fast when missing.
2. Loop close hard gate:
`loops.close` and `loops.auto.close` must refuse closure when any `pending` proposal is linked to the loop.
3. Control-plane visibility:
`spine.control.tick`/status surfaces must report loop-proposal mismatch states so drift is visible before execution.
4. Operator path consistency:
proposal flow docs and command help must describe loop-first registration and linked submission as the default path.

## Linked Artifacts

- Gap: `GAP-OP-750`
- Proposal: `CP-20260221-021304__canonical-fix--enforce-loop-bound-proposal-creation--block-loop-close-auto-close-when-pending-proposals-exist--and-surface-loop-proposal-mismatch-in-status-control-views-`

## Execution Sequence

1. Implement proposal-submit loop requirement and add tests/guards.
2. Implement loop-close and auto-close pending-proposal guards.
3. Add mismatch checks to control/status surfaces.
4. Verify with `stability.control.snapshot`, `verify.core.run`, and `verify.pack.run core-operator`.

## Done Criteria

- No new proposal can be created with `loop_id: null`.
- A loop with pending linked proposals cannot be closed manually or automatically.
- Status output explicitly flags loop/proposal mismatches.
- Receipts show gap-linked execution path from registration through apply.
