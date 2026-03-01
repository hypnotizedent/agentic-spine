---
loop_id: LOOP-MAIL-ARCHIVER-EWS-CANONICAL-CLOSURE-20260301-20260301
created: 2026-03-01
status: closed
owner: "@ronny"
scope: mail
priority: medium
horizon: now
execution_readiness: runnable
objective: Close remaining Microsoft deep-archive lane + normalize contracts + clear mail-archiver backup drift
---

# Loop Scope: LOOP-MAIL-ARCHIVER-EWS-CANONICAL-CLOSURE-20260301-20260301

## Objective

Close remaining Microsoft deep-archive lane + normalize contracts + clear mail-archiver backup drift

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MAIL-ARCHIVER-EWS-CANONICAL-CLOSURE-20260301-20260301`

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
