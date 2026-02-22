---
status: implemented
owner: "@ronny"
last_verified: 2026-02-21
scope: loop-proposal-linkage-fix
loop_id: LOOP-MAILROOM-LOOP-PROPOSAL-LINKAGE-ENFORCEMENT-20260221
gap_id: GAP-OP-750
proposal_id: CP-20260221-021304__canonical-fix--enforce-loop-bound-proposal-creation--block-loop-close-auto-close-when-pending-proposals-exist--and-surface-loop-proposal-mismatch-in-status-control-views-
---

# Loop Proposal Linkage Fix (2026-02-21)

## Objective

Eliminate loop/proposal drift by enforcing one canonical lifecycle:
`loop -> gap -> proposal -> apply/implement -> gap close -> loop close`.

## Implemented Changes

1. Enforced loop binding at proposal creation in `ops/plugins/proposals/bin/proposals-submit`.
- `--help` no longer creates proposals.
- `loop_id` is mandatory (`SPINE_LOOP_ID` or `--loop-id`).
- Submit blocks for missing, unknown, or closed loop ids.
2. Added manual loop-close guard in `ops/commands/loops.sh`.
- `ops loops close` now blocks when any pending proposal references the loop.
3. Added auto-close guard in `ops/plugins/lifecycle/bin/loops-auto-close`.
- Auto-close skips loops that still have pending linked proposals.
4. Added linkage visibility in `ops/plugins/proposals/bin/proposals-status`.
- Reports: missing loop_id, missing scope, closed-loop targets, unknown loop status, open-loop proposal coverage.
5. Updated operator docs in `ops/plugins/proposals/QUICK_START.md`.
- Loop-first + mandatory loop binding workflow documented.

## Behavioral Validation

- `./ops/plugins/proposals/bin/proposals-submit --help` prints usage without creating a CP.
- `./ops/plugins/proposals/bin/proposals-submit "dry-run-check-missing-loop"` fails with loop-binding error.
- `./ops/commands/loops.sh close LOOP-MAILROOM-LOOP-PROPOSAL-LINKAGE-ENFORCEMENT-20260221` blocks while linked CP is pending.
- `./bin/ops cap run proposals.status` now prints Loop-Proposal Linkage section.

## Verification Receipts

- `CAP-20260221-021921__stability.control.snapshot__Rtf9u39577` (WARN due runtime latency/heartbeat, no verify gate failure)
- `CAP-20260221-022008__verify.core.run__Rwijv47289` (PASS 7/7)
- `CAP-20260221-022057__verify.pack.run__Rdj4x63347` (PASS 7/7)

## Outcome

Canonical linkage controls are now runtime-enforced instead of convention-only.

Loop closure cannot bypass pending proposals, and pending proposals cannot be created without explicit loop attachment.
