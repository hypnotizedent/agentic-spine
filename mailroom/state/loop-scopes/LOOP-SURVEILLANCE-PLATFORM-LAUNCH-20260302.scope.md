---
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: agentic-spine
priority: medium
horizon: later
execution_readiness: blocked
activation_trigger: dependency
depends_on_loop: LOOP-CAMERA-OUTAGE-20260209
objective: Stand up a production-grade, spine-governed surveillance platform at the Mint Prints shop with AI-powered detection, role-scoped visibility, and agentic integration.
---

# Loop Scope: Mint Visibility Platform — Full Surveillance Stack Launch

## Problem Statement

The shop currently has a raw Hikvision NVR-only camera access system that is:
1. **Currently offline** — All 12 channels are dark due to the Feb 9 outage (LOOP-CAMERA-OUTAGE-20260209)
2. **Non-governed** — No role-based access control, no integration with spine capabilities
3. **Non-automated** — No AI detection, no event-driven notifications, no agentic layer
4. **Unlabeled** — All 12 channels have `pending-survey` location labels, blocking zone-based detection

The operator needs a comprehensive physical visibility system that integrates with the spine governance model, enables AI-powered detection and notifications, and establishes a multi-location deployment pattern for future sites.

## Deliverables

1. **SURVEILLANCE_PLATFORM_SSOT.md** — Canonical SSOT covering surveillance-stack VM, Tesla P40 detector hardware, camera categories, display endpoints, and multi-location template
2. **SURVEILLANCE_ROLES.md** — Governance doc defining role-based access boundaries
3. **CAMERA_SSOT.md amendment** — Rename to shop-scoped, add doorbell channel assignments (ch13-14), add ESP32 press arm camera section
4. **SHOP_VM_ARCHITECTURE.md amendment** — Add surveillance-stack VM 211 and shop-ha VM 212
5. **SHOP_SERVER_SSOT.md amendment** — Record Tesla P40 GPU spec and PCIe slot assignment
6. **surveillance.stack.status capability** — Check Frigate health, detection FPS, camera online count
7. **surveillance.event.query capability** — Read-only query to Frigate event database
8. **shop.ha.status capability** — Check shop-ha VM and HA integration health

## Acceptance Criteria

### Phase 0 — Blockers (Must Clear Before T2+)

- [ ] T0-A: Feb-9 camera outage resolved — all 12 channels live with ISAPI-confirmed stream URLs
- [ ] T0-B: Camera location survey complete — all 12 channels have verified physical labels

### Phase 1 — Hardware

- [ ] T1-A: Tesla P40 installed in R730XD PCIe slot with IOMMU passthrough configured
- [ ] T1-B: 12x ESP32-CAM press arm units procured, flashed with ESPHome, and streaming
- [ ] T1-C: 2x Raspberry Pi 4 kiosk displays procured and configured

### Phase 2 — VMs

- [ ] T2-A: surveillance-stack VM 211 provisioned with Frigate + go2rtc
- [ ] T2-B: shop-ha VM 212 provisioned with HAOS + Frigate integration

### Phase 3 — Integration

- [ ] T3-A: All 12 Hikvision cameras connected to Frigate with verified zone labels
- [ ] T3-B: go2rtc multi-view streams serving press operator TV, production TV, and Ronny remote
- [ ] T4-A: shop-ha automations firing push notifications for person/vehicle/delivery/after-hours events
- [ ] T5-A: surveillance.stack.status and surveillance.event.query capabilities registered

### Phase 4 — Governance

- [ ] T6-A: All SSOT amendments applied and committed
- [ ] T6-B: SURVEILLANCE_ROLES.md defines access boundaries and notification routing
- [ ] T6-C: Multi-location template documented for future site deployments

## Constraints

**Blocked by:**
- LOOP-CAMERA-OUTAGE-20260209 — Cannot configure Frigate until baseline camera streams are live
- Camera location survey — Cannot define detection zones until physical labels exist
- Tesla P40 procurement — Physical hardware must be acquired before installation

**Out of scope for initial launch:**
- Home surveillance integration (separate location, separate SSOT)
- Frigate+ paid tier (optional enhancement, can add later)
- Zigbee/Matter coordinator at shop (future expansion)
- Semantic search natural language queries (Frigate+ feature)

**Boundary:**
- This loop governs spine-side planning artifacts and capability registration
- Domain implementation (VM provisioning, Docker compose, HA config) requires workbench execution
- Hardware procurement is operator-owned action

## Phases

### P0: Blockers (now)
- Resolve camera outage
- Complete camera location survey
- Procure Tesla P40

### P1: Hardware (parallel with P0)
- Install Tesla P40
- Procure and flash ESP32 units
- Procure Pi kiosk units

### P2: VMs
- Provision surveillance-stack VM 211
- Provision shop-ha VM 212

### P3: Integration
- Frigate configuration
- go2rtc multi-view setup
- HA automations
- Capability registration

### P4: Governance
- SSOT amendments
- Role documentation
- Multi-location template

## Gaps

To be filed during execution:
- GAP-OP-NNN: Missing NVR credentials in Infisical (if not resolved by camera outage loop)
- GAP-OP-NNN: Missing surveillance capabilities in ops registry

## Evidence Paths

- `docs/governance/CAMERA_SSOT.md` — Camera channel registry
- `docs/governance/loops/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.md` — Extended loop scope (governing document)
- `mailroom/outbox/proposals/CP-20260302-075509__surveillance-platform-launch/` — Change proposal with SSOT drafts

## Related Documents

- [CAMERA_SSOT.md](../../docs/governance/CAMERA_SSOT.md)
- [SHOP_VM_ARCHITECTURE.md](../../docs/governance/SHOP_VM_ARCHITECTURE.md)
- [SHOP_SERVER_SSOT.md](../../docs/governance/SHOP_SERVER_SSOT.md)
- [DEVICE_IDENTITY_SSOT.md](../../docs/governance/DEVICE_IDENTITY_SSOT.md)
- [LOOP-CAMERA-OUTAGE-20260209](./LOOP-CAMERA-OUTAGE-20260209.scope.md)
