---
loop_id: {{LOOP_ID}}
created: {{DATE}}
status: active
owner: "@ronny"
scope: {{SCOPE}}
priority: {{PRIORITY}}
horizon: now
execution_readiness: runnable
objective: {{OBJECTIVE}}
---

# Loop Scope: {{LOOP_ID}}

## Objective

{{OBJECTIVE}}

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops {{LOOP_ID}}`
