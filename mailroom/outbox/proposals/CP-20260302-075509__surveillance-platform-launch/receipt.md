# Proposal Receipt: CP-20260302-075509__surveillance-platform-launch

## What was done

Drafted canonical planning artifacts for the Mint Visibility Platform surveillance stack:

1. **Loop Scope** — `mailroom/state/loop-scopes/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.scope.md`
   - Status: `planned` (deferred intent)
   - Horizon: `later` (not immediate execution)
   - Execution readiness: `blocked` (depends on LOOP-CAMERA-OUTAGE-20260209)
   - Phased approach: P0 (blockers) → P1 (hardware) → P2 (VMs) → P3 (integration) → P4 (governance)

2. **SURVEILLANCE_PLATFORM_SSOT.md** — Full technical specification including:
   - surveillance-stack VM 211 (Frigate + go2rtc + TensorRT detection)
   - shop-ha VM 212 (Home Assistant OS + MQTT + automations)
   - Tesla P40 detector hardware with caveats (compute-only, no NVDEC/NVENC)
   - Camera categories: Hikvision NVR channels (12) + ESP32 press arms (12)
   - Display endpoints: kiosk-press, kiosk-production
   - Multi-location deployment template

3. **SURVEILLANCE_ROLES.md** — Governance boundary document including:
   - Role definitions: owner, production-staff, press-operator, kiosk-display
   - Stream URL map with network-scoped access
   - Notification routing matrix
   - Multi-location access extension pattern
   - Prohibited uses policy

## Why

The operator needs a governed planning surface for the surveillance platform that:

1. Integrates with the spine governance model (loops, gaps, proposals, capabilities)
2. Establishes the multi-location deployment pattern for future sites
3. Documents the dependency on resolving the Feb-9 camera outage first
4. Provides a complete technical blueprint for desktop/execution agents to implement

## Constraints

- **Desktop-only execution:** This proposal creates planning artifacts only. No VM provisioning, no Docker deployment, no hardware installation.
- **Blocked by camera outage:** P2+ work cannot begin until LOOP-CAMERA-OUTAGE-20260209 is resolved and all 12 channels are live.
- **Procurement required:** Tesla P40, ESP32-CAM units, and Pi kiosk hardware must be acquired before hardware phases.
- **No secrets in repo:** All RTSP URLs and credentials reference Infisical paths, never embedded values.

## Expected outcomes

When the operator applies this proposal:

1. `docs/governance/loops/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.md` — Extended loop scope
2. `docs/core/SURVEILLANCE_PLATFORM_SSOT.md` — Canonical SSOT
3. `docs/governance/SURVEILLANCE_ROLES.md` — Access boundary document
4. `mailroom/state/loop-scopes/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.scope.md` — Loop scope entry

The loop will remain in `planned` status with `horizon: later` until the camera outage blocker is resolved.

## Evidence

- CAMERA_SSOT.md confirms 12 channels configured, 0 showing video (Feb-9 outage)
- SHOP_VM_ARCHITECTURE.md confirms VM 211-212 available for allocation
- SHOP_SERVER_SSOT.md confirms R730XD has PCIe slots available for Tesla P40
- planning.horizon.contract.yaml confirms `planned` status for deferred-intent loops

## Run keys

- CAP-20260302-025258__session.start__R7ioz96438
- CAP-20260302-025339__proposals.list__Rzki520529
