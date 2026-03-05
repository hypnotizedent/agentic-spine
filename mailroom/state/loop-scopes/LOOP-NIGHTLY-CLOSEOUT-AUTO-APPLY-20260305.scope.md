---
loop_id: LOOP-NIGHTLY-CLOSEOUT-AUTO-APPLY-20260305
created: 2026-03-05
status: closed
owner: "@ronny"
scope: wave
priority: high
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Implement safe unattended cleanup for unambiguous merged branches so nightly closeout stops repeating the same stale branch inventory
---

# Loop Scope: LOOP-NIGHTLY-CLOSEOUT-AUTO-APPLY-20260305

## Objective

Implement safe unattended cleanup for unambiguous merged branches so nightly closeout stops repeating the same stale branch inventory.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-NIGHTLY-CLOSEOUT-AUTO-APPLY-20260305`

## Phases

- Step 1: Remote prune before classification (git fetch --prune for all configured remotes)
- Step 2: Auto-apply policy knob in contract + nightly daily runner
- Step 3: Inline branch cleanup on loop close path (--cleanup-branch flag)
- Step 4: D353 gate for auto-apply safety enforcement
- Step 5: Validation (verify fast + loop_gap)

## Safety Constraints

- Keep `require_explicit_apply` model intact for ambiguous/hold cases
- Auto-apply only when dry-run result is fully unambiguous
- Never delete protected branches
- Never delete branches not fully merged (merge-base --is-ancestor guard)
- No destructive git reset/checkout commands
