---
loop_id: LOOP-FRICTION-MAILROOM-STATE-EVIDENCE-TRACKING-NORMALIZATION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: medium
horizon: later
execution_readiness: runnable
objective: Make new mailroom/state evidence surfaces persistable without manual .gitignore surgery.
---

# Loop Scope: LOOP-FRICTION-MAILROOM-STATE-EVIDENCE-TRACKING-NORMALIZATION-20260302

## Objective

Make new mailroom/state evidence surfaces persistable without manual .gitignore surgery.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-MAILROOM-STATE-EVIDENCE-TRACKING-NORMALIZATION-20260302`

## Phases
- P1:  audit ignore patterns impacting new evidence surfaces
- P2:  define canonical state-surface allowlist/contract
- P3:  validate governed handoff path and close linked gap

## Success Criteria
- new canonical state artifacts can be committed through governed flow
- ignore policy prevents accidental noise while allowing authority artifacts

## Definition Of Done
- mailroom state persistence contract updated
- linked gap closed with receipts
