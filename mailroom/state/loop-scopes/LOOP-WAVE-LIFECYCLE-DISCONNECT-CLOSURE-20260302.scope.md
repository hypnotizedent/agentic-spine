---
loop_id: LOOP-WAVE-LIFECYCLE-DISCONNECT-CLOSURE-20260302
created: 2026-03-02
status: closed
owner: "@ronny"
scope: wave
priority: high
horizon: now
execution_readiness: runnable
objective: Close wave lifecycle contract disconnects across schema role DoD gates MCP and lane compatibility
---

# Loop Scope: LOOP-WAVE-LIFECYCLE-DISCONNECT-CLOSURE-20260302

## Objective

Close wave lifecycle contract disconnects across schema role DoD gates MCP and lane compatibility

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-WAVE-LIFECYCLE-DISCONNECT-CLOSURE-20260302`

## Phases
- W0:  forensic baseline and contract parity check
- W1:  receipt schema and role propagation fixes
- W2:  DoD guard hardening and wave close semantics
- W3:  drift gates D315 to D320 and contract coverage
- W4:  MCP role context and lane role compatibility enforcement
- W5:  verification sweep and closeout

## Success Criteria
- All six disconnect classes are fixed with evidence and regression locks
- No orphaned contract paths between loop proposal wave and role surfaces
- verify.run fast passes and targeted domain checks pass

## Definition Of Done
- Loop allowlist respected with no unrelated file edits
- Run keys and commit refs captured in final report
- Loop is close-ready without force bypass
