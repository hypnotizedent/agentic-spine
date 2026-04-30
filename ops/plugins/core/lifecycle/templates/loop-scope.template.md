---
loop_id: {{LOOP_ID}}
created: {{DATE}}
status: active
owner: "@ronny"
scope: {{SCOPE}}
priority: {{PRIORITY}}
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: "{{OBJECTIVE}}"
next_action: ""
evidence_refs: []
exclusions: []
supersedes: []
---
<!-- Authority: loop scope files are runtime projections/materializations of governed
     loop lifecycle state, not the primary authority.
     Runtime location: $SPINE_STATE/loop-scopes/ (externalized from repo).
     Default close path: wave.finish -> loop-closeout-finalize.
     Manual control-plane recovery close: orchestration.loop.close.
     Do not use raw shared_authority.db mutation as the operator path. -->

# Loop Scope: {{LOOP_ID}}

## Objective

{{OBJECTIVE}}

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run spine.verify`
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

## Workflow Readback

<!-- Agents use this section to avoid rediscovering ceremony from memory. -->
- **Evidence**: collect source refs, run keys, files, receipts, or operator approval before mutation.
- **Loop**: this scope is the bounded parent objective; attach related work here instead of creating siblings.
- **Custody**: do not start from a loop claim; derive custody from carried evidence plus governed claim/heartbeat/receipt proof.
- **Packet**: create or use a packet when there is a bounded research or implementation slice.
- **Execution**: use governed capabilities, waves, delegation, or mailroom tasks; fallback shell only when no surface exists.
- **Verification**: record `verify.engine.run`, `spine.verify`, and scoped capability receipts as evidence refs.
- **Close decision**: use `slice_complete` when more work remains and `loop_complete` when success criteria are met; if a new next step exists, packetize it before final readback.

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
