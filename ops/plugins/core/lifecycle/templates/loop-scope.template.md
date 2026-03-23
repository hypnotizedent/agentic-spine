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
exclusions: []
supersedes: []
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

## Scope Boundaries

<!-- Authors: list what is explicitly OUT of scope and what prior work this loop replaces. -->
<!-- Agents must not rediscover or re-audit excluded surfaces. -->

### Exclusions
<!-- Surfaces, seams, or prior work explicitly not in scope for this loop. -->
<!-- Example: "- WD music pipeline (superseded by streaming-stack, see LOOP-MEDIA-...)" -->

### Supersedes
<!-- Prior loops, plans, or contracts this loop replaces. Agents must not create sibling loops for these. -->
<!-- Example: "- LOOP-OLD-NAME-20260301 (scope absorbed into this loop)" -->

## Execution Commands

<!-- Authors: list the governed mutating/orchestration capabilities for this loop before any raw shell fallback. -->
- **Primary execution**: `./bin/ops cap run <capability>`
- **Fallback shell**: use only when no governed execution surface exists or the physical step cannot go through the spine

## Closure Checklist

<!-- All boxes must be checked before disposition: landed. -->
- [ ] Runtime agrees (services/containers/hosts reflect the change)
- [ ] Control plane agrees (bindings, contracts, SSOT docs updated)
- [ ] Projections agree (docs, dashboards, gate registry current)
- [ ] Residue retired (stale branches, worktrees, exports, mounts removed or dispositioned)
