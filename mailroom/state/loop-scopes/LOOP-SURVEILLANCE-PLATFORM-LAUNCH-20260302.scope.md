---
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: agentic-spine
priority: medium
horizon: now
execution_readiness: runnable
execution_mode: single_worker
next_review: "2026-03-15"
activation_trigger: dependency
depends_on_loop: LOOP-CAMERA-OUTAGE-20260209
objective: Stand up a production-grade, spine-governed surveillance platform at the Mint Prints shop with Frigate/go2rtc visibility and home-HA integration using a single Home Assistant instance.
---

# Loop Scope: Mint Visibility Platform — Full Surveillance Stack Launch

## Drift Decision (Authoritative)

This loop is explicitly normalized to:

1. **Single Home Assistant instance** (existing home HA only). No second shop-HA VM.
2. **CPU-first Frigate baseline**. GPU acceleration is optional future enhancement, not a blocker.
3. **No VMID pre-assignment in planning docs**. VM IDs are allocated only through intake scaffold + lifecycle bindings.

These rules override older draft assumptions that referenced `shop-ha` and Tesla P40 as required.

## Problem Statement

The shop currently has a raw Hikvision NVR-only camera access system that is:

1. **Currently offline** — All 12 channels are dark due to the Feb 9 outage (LOOP-CAMERA-OUTAGE-20260209)
2. **Non-governed** — No role-based access control, no integration with spine capabilities
3. **Non-automated** — No governed event flow, no standardized alert routing
4. **Unlabeled** — Channel physical labels are incomplete, blocking zone-based detection consistency

## Deliverables

1. **SURVEILLANCE_PLATFORM_SSOT.md** — Canonical SSOT for Frigate/go2rtc stack, camera categories, CPU-first runtime baseline, and future GPU extension point
2. **SURVEILLANCE_ROLES.md** — Governance doc defining role-based access boundaries
3. **CAMERA_SSOT.md amendment** — Shop channel registry normalized for Frigate ingest
4. **SHOP_VM_ARCHITECTURE.md amendment** — Add surveillance-stack VM using conflict-free VMID assigned by intake
5. **surveillance.stack.status capability** — Frigate health, camera online count, detection pipeline status
6. **surveillance.event.query capability** — Read-only query of Frigate events
7. **ha.surveillance.status capability** — Home-HA integration health for surveillance entities/automations

## Acceptance Criteria

### Step 0 — Blockers

- [x] T0-A: Feb-9 camera outage resolved — 8/12 channels online (ch2-5 remain offline, GAP-OP-031)
- [ ] T0-B: Camera location survey complete — channels have verified physical labels for zone mapping

### Step 1 — Runtime Foundation

- [x] T1-A: surveillance-stack VM 215 provisioned (4 cores, 8GB RAM, 50GB boot, 100GB data on tank-vms)
- [x] T1-B: Frigate 0.17.0 + go2rtc deployed in CPU mode with 8 cameras at 5fps

### Step 2 — Integration

- [ ] T2-A: Home HA (existing instance) receives Frigate events and drives notification automations (STUB-ha-integration: blocked_operator — HACS UI install required)
- [x] T2-B: go2rtc view endpoints working (Frigate built-in go2rtc at :8554/:8555)
- [x] T2-C: `surveillance.stack.status` and `surveillance.event.query` registered and callable

### Step 3 — Governance

- [x] T3-A: SSOT amendments committed and parity-checked
- [ ] T3-B: Roles/access model committed (SURVEILLANCE_ROLES.md)
- [x] T3-C: Future GPU path documented as optional extension (non-blocking)

## Constraints

**Partially resolved:**
- LOOP-CAMERA-OUTAGE-20260209 — 8/12 channels online (ch2-5 remain offline)
- Camera location survey completion — required before stable zone mapping

**Not blockers:**
- Tesla P40 or any external GPU
- Separate shop Home Assistant instance

**Boundary:**
- This loop governs planning artifacts, contracts, and capability registration
- Runtime provisioning/deploy work executes via governed capabilities and workbench implementation surfaces

## Phases

### S0: Blockers
- Resolve camera outage
- Complete location survey

### S1: CPU Bootstrap
- Provision surveillance VM through intake scaffold + lifecycle contracts
- Deploy Frigate/go2rtc with CPU detector path

### S2: HA Integration
- Wire Frigate into existing home HA
- Validate end-to-end event/notification flow

### P3: Governance Closure
- Finalize SSOTs, capability docs, and role boundaries

## Gaps

Filed during execution wave:
- Surveillance capability gaps: to be filed via `gaps.file --id auto` during Lane B execution
- VM provisioning gaps: to be filed via `gaps.file --id auto` during Lane C execution
- Camera outage: tracked under LOOP-CAMERA-OUTAGE-20260209 (GAP-OP-031)

## Evidence Paths

- `docs/governance/CAMERA_SSOT.md`
- `docs/governance/loops/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.md`
- `mailroom/outbox/proposals/CP-20260302-075509__surveillance-platform-launch/`
- `ops/bindings/surveillance.topology.contract.yaml`

## Related Documents

- [CAMERA_SSOT.md](../../docs/governance/CAMERA_SSOT.md)
- [SHOP_VM_ARCHITECTURE.md](../../docs/governance/SHOP_VM_ARCHITECTURE.md)
- [SHOP_SERVER_SSOT.md](../../docs/governance/SHOP_SERVER_SSOT.md)
- [DEVICE_IDENTITY_SSOT.md](../../docs/governance/DEVICE_IDENTITY_SSOT.md)
- [LOOP-CAMERA-OUTAGE-20260209](./LOOP-CAMERA-OUTAGE-20260209.scope.md)
