---
loop_id: LOOP-AGENT-FRICTION-AUTOPILOT-20260301
created: 2026-03-01
status: active
owner: "@ronny"
scope: agent
priority: high
objective: Automate friction intake/dedupe/triage into governed gaps and control-plane visibility
---

# Loop Scope: LOOP-AGENT-FRICTION-AUTOPILOT-20260301

## Objective

Automate friction intake/dedupe/triage into governed gaps and control-plane visibility

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-AGENT-FRICTION-AUTOPILOT-20260301`

## Phases
- Step 1:  baseline + intake contract
- Step 2:  reconcile + gate + visibility
- Step 3:  ergonomics + closure

## Success Criteria
- Friction queue governed and stale backlog gated
- Verify outputs classify baseline vs wave-local failures

## Definition Of Done
- All wave files committed in scoped commits
