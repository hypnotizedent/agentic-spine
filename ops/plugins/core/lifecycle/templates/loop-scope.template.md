---
loop_id: {{LOOP_ID}}
created: {{DATE}}
status: active
owner: "@ronny"
scope: {{SCOPE}}
priority: {{PRIORITY}}
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: {{OBJECTIVE}}
---

# Loop Scope: {{LOOP_ID}}

## Objective

{{OBJECTIVE}}

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops {{LOOP_ID}}`
- **Friction**: `./bin/ops cap run friction.ingest -- --loop-id {{LOOP_ID}} --capability <capability> --expected "..." --actual "..." --severity <low|medium|high> --auto-reconcile`

## Authority Order

- current operator directive
- active loop scope
- live runtime/broker state and current governed receipts
- authoritative bindings/contracts/SSOT docs
- historical evidence and old receipts
- raw shell output

## Execution Commands

<!-- Authors: list the governed mutating/orchestration capabilities for this loop before any raw shell fallback. -->
- **Primary execution**: `./bin/ops cap run <capability>`
- **Fallback shell**: use only when no governed execution surface exists or the physical step cannot go through the spine
