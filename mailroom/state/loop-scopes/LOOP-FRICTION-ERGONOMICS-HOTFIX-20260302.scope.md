---
loop_id: LOOP-FRICTION-ERGONOMICS-HOTFIX-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: friction
priority: high
horizon: now
execution_readiness: runnable
objective: "Close friction hotfix items for cap separator handling, D128 commit ergonomics, portable gaps.file behavior, and vaultwarden read-path fallback semantics"
---

# Loop Scope: LOOP-FRICTION-ERGONOMICS-HOTFIX-20260302

## Objective

Close friction hotfix items for cap separator handling, D128 commit ergonomics, portable gaps.file behavior, and vaultwarden read-path fallback semantics

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-ERGONOMICS-HOTFIX-20260302`

## Phases
- Step 1: reproduce and classify friction defects
- Step 2: patch runtime ergonomics and fallback behavior
- Step 3: verify, reconcile queue, and close linked gaps

## Success Criteria
- Canonical `cap run <capability> -- --flag` separator form works for affected capabilities.
- Linked friction gaps (1294-1297) are fixed with receipts.
- Friction queue returns to `queued=0` after reconcile.

## Definition Of Done
- Scope artifact committed.
- Linked gap state is normalized and unambiguous.
- Verification receipts recorded.

## Resolution

- `cap.sh` strips a single leading separator before dispatch (`--` form parity).
- `.githooks/commit-msg` auto-populates D128 trailers before enforcing block.
- `gaps-file` title derivation is BSD-safe (no GNU `sed` branch dependency).
- Vaultwarden audit path is deterministic: LAN failure falls back to Tailscale; fully unreachable path emits BLOCKED.
- GAP-OP-1294/1295/1296/1297 set to fixed.
- GAP-OP-1283 decision: fixed via fallback policy (LAN outage remains operational signal, not unresolved contract gap).
- Friction queue reconcile executed; `queued=0` after filing 12 new backlog friction gaps.

## Evidence

- CAP-20260302-021614__friction.reconcile__Rfub828655
- CAP-20260302-021624__friction.queue.status__R9kn030293
- CAP-20260302-021427__ssh.target.status__Rgh8512369
- CAP-20260302-021444__vaultwarden.vault.audit__Rci8716356
- CAP-20260302-021411__verify.run__Rmbkz8705
