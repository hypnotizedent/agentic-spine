---
loop_id: LOOP-SURVEILLANCE-E2E-HARDENING-20260305
created: 2026-03-05
status: active
owner: "@ronny"
scope: surveillance
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Harden surveillance capabilities E2E against live Frigate runtime, fix go2rtc bundled check, refresh tailnet snapshot for VM 215, enable backup target, close resolved gaps
---

# Loop Scope: LOOP-SURVEILLANCE-E2E-HARDENING-20260305

## Objective

Harden surveillance capabilities E2E against live Frigate runtime, fix go2rtc bundled check, refresh tailnet snapshot for VM 215, enable backup target, close resolved gaps

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-SURVEILLANCE-E2E-HARDENING-20260305`

## Lanes (orchestrator_subagents)

### Lane A: Capability E2E Hardening
- Fix `surveillance.stack.status` go2rtc_api check — Frigate 0.17 bundles go2rtc internally, standalone port 1984 doesn't exist
- Validate `surveillance.event.query` returns correct structure against live Frigate API
- Validate `ha.surveillance.status` gracefully reports pending until HACS integration installed

### Lane B: Binding Parity
- Refresh `ops/bindings/tailscale.tailnet.snapshot.yaml` — add VM 215 (100.89.1.111)
- Enable backup target for VM 215 in `ops/bindings/backup.inventory.yaml`
- Verify D310 (tailnet-snapshot-parity) passes with updated snapshot

### Lane C: Gap Sweep + Closure
- Scan `operational.gaps.yaml` for surveillance-related open gaps
- Close any gaps that are now resolved by live Frigate runtime
- Update loop scope with final progress

## Success Criteria
- `surveillance.stack.status` returns HEALTHY (not DEGRADED)
- D310 passes with VM 215 in tailnet snapshot
- All closeable surveillance gaps closed with evidence
- verify fast 20/20 PASS

## Definition Of Done
- All 3 capability checks pass against live runtime
- Binding parity confirmed (tailnet snapshot, backup inventory)
- Scope artifacts updated and committed
- Loop status can be moved to closed
