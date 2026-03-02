---
loop_id: LOOP-MAIL-ARCHIVER-TURNKEY-ONBOARDING-20260302-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: mail
priority: medium
horizon: now
execution_readiness: runnable
objective: Make client email onboarding turnkey with one authoritative contract path, one operator runbook, no stale surfaces, and verify-enforced drift protection
---

# Loop Scope: LOOP-MAIL-ARCHIVER-TURNKEY-ONBOARDING-20260302-20260302

## Objective

Make client email onboarding turnkey with one authoritative contract path, one operator runbook, no stale surfaces, and verify-enforced drift protection

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAIL-ARCHIVER-TURNKEY-ONBOARDING-20260302-20260302`

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
