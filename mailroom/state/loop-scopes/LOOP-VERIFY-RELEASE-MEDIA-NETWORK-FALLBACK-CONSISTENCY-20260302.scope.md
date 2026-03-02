---
loop_id: LOOP-VERIFY-RELEASE-MEDIA-NETWORK-FALLBACK-CONSISTENCY-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: verify
priority: high
horizon: now
execution_readiness: runnable
objective: Normalize D107/D108/D109 to use LAN->Tailscale fallback consistently for off-LAN terminals.
---

# Loop Scope: LOOP-VERIFY-RELEASE-MEDIA-NETWORK-FALLBACK-CONSISTENCY-20260302

## Objective

Normalize D107/D108/D109 to use LAN->Tailscale fallback consistently for off-LAN terminals.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-VERIFY-RELEASE-MEDIA-NETWORK-FALLBACK-CONSISTENCY-20260302`

## Phases
- Step 1:  Register loop+gap
- Step 2:  Patch media gates
- Step 3:  Verify and classify release failures

## Success Criteria
- D107/D108/D109 pass in off-LAN context when Tailscale path is healthy
- verify.release.run remains present and executable

## Definition Of Done
- Only scoped files changed
- Run keys recorded before/after
