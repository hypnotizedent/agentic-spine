---
loop_id: LOOP-BACKUP-RESTORE-PROOF-ROLLOUT-E2E-20260309
created: 2026-03-09
status: active
owner: "@ronny"
scope: backup
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Implement and prove governed restore-drill coverage for all restorable backup classes: shop-vm, home-restore, infisical, media-config, and communications-mailarchiver. Drive the estate toward restore-green with canonical capabilities, receipts, gates, and schedules.
---

# Loop Scope: LOOP-BACKUP-RESTORE-PROOF-ROLLOUT-E2E-20260309

## Objective

Implement and prove governed restore-drill coverage for all restorable backup classes: shop-vm, home-restore, infisical, media-config, and communications-mailarchiver. Drive the estate toward restore-green with canonical capabilities, receipts, gates, and schedules.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-BACKUP-RESTORE-PROOF-ROLLOUT-E2E-20260309`

## Phases
- Step 1: capture and classify findings
- Step 2: implement changes
- Step 3: verify and close out

## Success Criteria
- All linked gaps/proposals are captured and linked to this loop.
- Relevant verify pack(s) pass.

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.
