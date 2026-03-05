---
loop_id: LOOP-REMOTE-BOOTSTRAP-FALLBACK-HARDENING-20260305
created: 2026-03-05
status: active
owner: "@ronny"
scope: remote
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: single_worker
objective: Eliminate recurring remote bootstrap drift by making LAN/Tailscale fallback deterministic in diagnostics, then bootstrap VM215 access path.
---

# Loop Scope: LOOP-REMOTE-BOOTSTRAP-FALLBACK-HARDENING-20260305

## Objective

Eliminate recurring remote bootstrap drift by making LAN/Tailscale fallback deterministic in diagnostics, then bootstrap VM215 access path.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-REMOTE-BOOTSTRAP-FALLBACK-HARDENING-20260305`

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
