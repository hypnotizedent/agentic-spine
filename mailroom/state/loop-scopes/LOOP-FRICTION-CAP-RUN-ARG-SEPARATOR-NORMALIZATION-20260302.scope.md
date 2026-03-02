---
loop_id: LOOP-FRICTION-CAP-RUN-ARG-SEPARATOR-NORMALIZATION-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: friction
priority: high
horizon: later
execution_readiness: runnable
objective: Normalize cap-run flag forwarding so argparse-backed capabilities accept canonical separator form.
---

# Loop Scope: LOOP-FRICTION-CAP-RUN-ARG-SEPARATOR-NORMALIZATION-20260302

## Objective

Normalize cap-run flag forwarding so argparse-backed capabilities accept canonical separator form.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-FRICTION-CAP-RUN-ARG-SEPARATOR-NORMALIZATION-20260302`

## Phases
- P1:  reproduce separator mismatch across cap wrappers
- P2:  patch wrapper forwarding and add regression coverage
- P3:  validate and close linked friction gap

## Success Criteria
- cap run friction.queue.status accepts -- --json form
- wrapper parity confirmed on representative argparse capabilities

## Definition Of Done
- regression lock added for separator forwarding
- linked gap closed with evidence
