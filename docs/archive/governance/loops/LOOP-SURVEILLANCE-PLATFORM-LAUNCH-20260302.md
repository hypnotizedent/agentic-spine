---
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
status: planned
owner: "@ronny"
created: "2026-03-02"
target_close: "2026-04-30"
title: "Mint Visibility Platform — Full Surveillance Stack Launch (Shop)"
horizon: later
execution_readiness: blocked
activation_trigger: dependency
depends_on_loop: LOOP-CAMERA-OUTAGE-20260209
---

# LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302

## Purpose

Stand up a production-grade, spine-governed surveillance platform at the Mint Prints shop.

This normalized version replaces legacy draft assumptions and is now the authoritative execution intent.

## Canonical Decisions (Drift Fix)

1. **One Home Assistant instance only**
- Surveillance integrates with the existing home HA instance.
- No separate `shop-ha` VM is part of this loop.

2. **CPU-first deployment path**
- Frigate/go2rtc must ship without requiring Tesla P40 or any external GPU.
- GPU is optional future optimization, not a precondition.

3. **No hardcoded VM IDs in planning docs**
- VM IDs are allocated through governed intake (`infra.vm.intake.scaffold`) and lifecycle bindings.
- Prior `211/212` references are invalid because those IDs are already assigned.

## Blockers (must clear before run)

- **B1 — Camera outage unresolved**
  - Dependency loop: LOOP-CAMERA-OUTAGE-20260209
  - Need baseline live streams before reliable Frigate ingest.

- **B2 — Channel/location normalization incomplete**
  - Camera physical labels and zone mapping must be verified.

## Execution Plan

### Tier 0 — Baseline Recovery

1. Resolve camera outage and re-verify stream health in CAMERA_SSOT.
2. Complete channel physical survey and canonical naming.

### Tier 1 — Surveillance VM (CPU-first)

1. Allocate VM target via intake scaffold (conflict-free VMID/IP).
2. Provision and bootstrap VM via governed infra capabilities.
3. Deploy Frigate + go2rtc with CPU detector baseline.
4. Establish recording/event retention and storage limits.

### Tier 2 — Existing HA Integration

1. Connect Frigate events to the existing home HA instance.
2. Implement baseline automations (person/vehicle/after-hours) in home HA.
3. Validate dashboard/event render and notification flow.

### Tier 3 — Capability + Governance Closure

Register and enforce:

- `surveillance.stack.status`
- `surveillance.event.query`
- `ha.surveillance.status`

Then update authoritative docs:

- `CAMERA_SSOT.md`
- `SHOP_VM_ARCHITECTURE.md` (domain authority)
- `DEVICE_IDENTITY_SSOT.md`
- `SURVEILLANCE_PLATFORM_SSOT.md`
- `SURVEILLANCE_ROLES.md`

## Required Contracts / Artifacts

- Loop scope: `mailroom/state/loop-scopes/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.scope.md`
- VM lifecycle authority: `ops/bindings/vm.lifecycle.yaml`
- Placement policy: `ops/bindings/infra.placement.policy.yaml`
- Storage placement: `ops/bindings/infra.storage.placement.policy.yaml`
- Camera authority: `docs/governance/CAMERA_SSOT.md`

## Success Criteria

- Camera baseline restored and documented.
- Surveillance VM provisioned with governed lifecycle entries and no identity conflicts.
- Frigate/go2rtc running in CPU mode with stable ingest.
- Existing home HA receives events and drives expected automations.
- New surveillance capabilities registered and verify-covered.
- SSOT documents updated with no conflicting references to `shop-ha` or mandatory GPU.

## Out of Scope (for this closure)

- GPU passthrough optimization
- Frigate+ paid features
- Second HA instance at shop

## Notes

- This loop remains `planned/blocked` until camera baseline dependency clears.
- Once dependency clears, execution_readiness should move to runnable and orchestration wave can be kicked off.
