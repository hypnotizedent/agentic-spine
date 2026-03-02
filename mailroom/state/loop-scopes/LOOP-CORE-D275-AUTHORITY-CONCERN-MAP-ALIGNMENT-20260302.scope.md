---
loop_id: LOOP-CORE-D275-AUTHORITY-CONCERN-MAP-ALIGNMENT-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: core
priority: high
horizon: now
execution_readiness: runnable
objective: Resolve D275 by aligning authoritative markers to concern map and removing/relocating out-of-map authority declarations.
---

# Loop Scope: LOOP-CORE-D275-AUTHORITY-CONCERN-MAP-ALIGNMENT-20260302

## Objective

Resolve D275 by aligning authoritative markers to concern map and removing/relocating out-of-map authority declarations.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-CORE-D275-AUTHORITY-CONCERN-MAP-ALIGNMENT-20260302`

## Phases
- W0:  Enumerate D275 violations and owning concerns
- W1:  Align authoritative markers to canonical concern surfaces
- W2:  Prove parity with domain core verify

## Success Criteria
- verify.run -- domain core passes D275
- No authoritative-marker-outside-concern-map violations remain

## Definition Of Done
- Targeted gate D275 PASS + domain core receipt
