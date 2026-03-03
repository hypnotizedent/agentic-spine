---
loop_id: LOOP-HOME-CANONICAL-REALIGNMENT-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: home
priority: high
horizon: later
execution_readiness: blocked
blocked_by: "Offsite — requires physical presence at home for HA/Zigbee/UniFi/Proxmox access and live verification"
next_review: "2026-03-09"
objective: Carve Home infrastructure into a first-class canonical program with dedicated authority contracts, machine inventories, and verify-ring isolation.
---

# Loop Scope: LOOP-HOME-CANONICAL-REALIGNMENT-20260302

## Objective

Establish Home as a first-class canonical domain with:
1. Dedicated authority index and contracts
2. Machine-readable hardware/network/service inventories
3. HA catalog authority (integrations, automations, dashboards, HACS)
4. Zigbee reliability baseline (network map, LQI/SNR policy, dead-router recovery)
5. UniFi + Proxmox-home normalization
6. Verify-ring separation so Home runtime volatility does not leak into Spine core verifies

## Problem Statement

Home infrastructure gates (D113, D114, D115, D118, D119, D120) fail when HA is unreachable (offsite) and pollute Spine release verification. There is no dedicated authority contract, no machine-readable inventory, and no ring separation between home-runtime gates and spine-core gates.

Current state (updated 2026-03-03):
- 6 release gates blocked by HA unreachability (offsite)
- HOME_AUTHORITY_INDEX created with access model (2026-03-03)
- home.authority.contract.yaml created with verify ring definition (2026-03-02)
- Hardware inventory is scattered across DEVICE_IDENTITY_SSOT.md and ad-hoc files
- Z2M naming drift (6 vs 5 device count mismatch)
- No HA catalog snapshot (integrations, automations, dashboards)
- Home gates in same verify ring as spine-core gates (contract defined, not yet enforced)

## Execution Waves (On-Site Day)

### W0: Authority + Contracts (pre-arrival, planning-only)
- [x] Register loop and gap pack
- [x] Create authority index and contract skeletons
- [x] Create inventory file skeletons
- [ ] Populate known hardware from existing docs

### W1: Agent Access Model
- [x] Define read/write lanes for home domain (HOME_AUTHORITY_INDEX.md access model enriched 2026-03-03)
- [x] Service credential inventory (HA tokens, Z2M API, UniFi controller) — Infisical paths documented
- [x] Audit path for home mutations — receipt-based capability model documented

### W2: Hardware + Network Reconciliation
- [ ] Full hardware inventory (walk-through + serial numbers)
- [ ] UniFi device/port/VLAN normalization
- [ ] Proxmox-home node inventory (if applicable)
- [ ] Home WAN speed measurement

### W3: HA Catalog Authority
- [ ] Integration snapshot (all installed integrations + versions)
- [ ] HACS component inventory
- [ ] Add-on inventory
- [ ] Automation/scene/script registry
- [ ] Helper registry
- [ ] Dashboard registry

### W4: Zigbee Reliability
- [ ] Z2M network map capture
- [ ] LQI/SNR baseline per device
- [ ] Dead-router identification and recovery plan
- [ ] Device naming parity fix (living_switch_scene drift)

### W5: Gate-Ring Separation
- [ ] Define home-runtime verify ring (D113-D120 lineage)
- [ ] Separate from spine-core fast verify ring
- [ ] Home gates only run when HA reachable (conditional skip)
- [ ] Update verify.release.run ring topology

### W6: Verify + Closeout
- [ ] All home gates PASS from on-site
- [ ] All inventories populated and committed
- [ ] Authority contract active
- [ ] Ring separation committed and verified

## Success Criteria

1. Zero HA-related gates in spine-core fast verify ring
2. All 8 authority/inventory files populated with live data
3. Z2M naming parity: 0 mismatches
4. HA entities_unexpected_unavailable < 50 (from on-site)
5. Full hardware inventory with serial numbers

## Definition of Done

- [ ] All waves complete
- [ ] Authority contract status: active
- [ ] Home verify ring defined and wired
- [ ] Zero orphan gaps
- [ ] Commit pushed with all artifacts

## Constraints

- Must be executed on-site at home (HA/Zigbee/UniFi require LAN access)
- No remote force-fixes of HA state
- Existing home gates must not regress for on-site runs
- Planning artifacts can be prepared remotely (W0)

## Gap Blocker Evidence (2026-03-03, normalized by Lane C)

| Gap | Title (short) | Blocker Class | Blocked Case | Next Action | ETA |
|-----|---------------|---------------|--------------|-------------|-----|
| GAP-OP-1352 | HA runtime D113/D114/D118/D120 fail | blocked_by_ronny_on_site | HA API at 10.0.0.100:8123 unreachable from offsite | Run ha.status, then verify.release.run | next_home_visit |
| GAP-OP-1354 | HA data-quality D115/D119 | blocked_by_ronny_on_site | D115 (199 unavail entities) + D119 (Z2M naming drift) need live HA/SSH | SSH to hassio, run ha.z2m.devices.snapshot + ha.entity.audit | next_home_visit |
| GAP-OP-1355 | Home agent access model | **CLOSED** | Fixed in a7e316f | N/A | N/A |
| GAP-OP-1356 | Zigbee reliability baseline | blocked_by_ronny_on_site | Z2M network map, LQI/SNR require physical Z2M/HA access | Access Z2M web UI, capture network map, export LQI/SNR per device | next_home_visit |
| GAP-OP-1357 | UniFi/Proxmox normalization | blocked_by_ronny_on_site | UniFi controller + Proxmox-home + WAN speed need LAN | Log into UniFi, SSH to proxmox-home, run speed test | next_home_visit |
| GAP-OP-1358 | Full hardware inventory | blocked_by_ronny_on_site | Physical walk-through for serial numbers/model/placement | Walk through with phone/camera, photograph labels | next_home_visit |
| GAP-OP-1359 | HA catalog authority | blocked_by_ronny_on_site | Integration/HACS/add-on snapshots need HA API at LAN | Run HA REST API: integrations, HACS, add-ons | next_home_visit |
| GAP-OP-1360 | Dashboard/automation registries | blocked_by_ronny_on_site | Dashboard/automation/scene/script/helper listing needs HA API | Run HA REST API: dashboards, automations, scenes, scripts, helpers | next_home_visit |
| GAP-OP-1361 | Verify-ring leakage | blocked_by_ronny_arch_decision | Ring separation needs arch decision (ring_assignment field, conditional skip, or separate verify) | Decide ring architecture, add ring_assignment to gate.registry.yaml D113-D120 | next_home_visit |

**Blocker distribution**: 7 blocked_by_ronny_on_site, 1 blocked_by_ronny_arch_decision

## Home Visit Execution Checklist

One-pass deterministic execution list for the next on-site day.
Order: arch decision first (can be done en route), then LAN-dependent tasks grouped by system.

### Step 0: Pre-Arrival (can be done remotely/en route)
- [ ] **GAP-OP-1361 (arch decision)**: Decide ring separation strategy for home-runtime gates D113-D120. Options: (a) add `ring_assignment` field to gate.registry.yaml, (b) conditional skip in verify.release.run based on HA reachability probe, (c) separate `verify.home.run` command. Record decision.

### Step 1: Arrive and Connect to Home LAN
- [ ] Connect laptop to home WiFi / Ethernet
- [ ] Verify LAN connectivity: `ping 10.0.0.100` (HA), `ping 10.0.0.1` (router)

### Step 2: HA API Verification (GAP-OP-1352)
- [ ] Run `./bin/ops cap run ha.status` -- confirm API UP
- [ ] Run `./bin/ops cap run verify.release.run` -- validate D113/D114/D118/D120 pass
- [ ] If any gate still fails, capture error output for diagnosis

### Step 3: HA Data Quality Repair (GAP-OP-1354)
- [ ] SSH to hassio@ha
- [ ] Run `./bin/ops cap run ha.z2m.devices.snapshot` -- refresh Z2M bindings
- [ ] Run `./bin/ops cap run ha.entity.audit` -- triage 199 unavailable entities
- [ ] Update entity allowlist to get unavailable count below threshold (50)
- [ ] Fix living_switch_scene Z2M naming parity (6 vs 5 device mismatch)
- [ ] Verify D115 and D119 pass

### Step 4: Zigbee Reliability Baseline (GAP-OP-1356)
- [ ] Access Z2M web UI (http://10.0.0.100:8099 or via HA add-on)
- [ ] Capture network map screenshot -> save to docs/
- [ ] Export LQI/SNR per device -> populate home.hardware.inventory.yaml zigbee section
- [ ] Identify dead routers (devices with no child nodes, low LQI)
- [ ] Document recovery plan for dead routers

### Step 5: HA Catalog Snapshots (GAP-OP-1359)
- [ ] Run HA REST API: `GET /api/config/config_entries/entry` (integrations)
- [ ] Capture HACS component inventory (via HACS API or web UI)
- [ ] Capture add-on inventory: `GET /api/hassio/addons`
- [ ] Populate `ops/bindings/home.assistant.catalog.snapshot.yaml`

### Step 6: Dashboard/Automation Registries (GAP-OP-1360)
- [ ] Run HA REST API: list dashboards, automations, scenes, scripts, helpers
- [ ] Populate `ops/bindings/home.automation.registry.yaml`

### Step 7: UniFi/Proxmox Normalization (GAP-OP-1357)
- [ ] Log into UniFi controller web UI
- [ ] Export device list, port assignments, VLAN configuration
- [ ] SSH to proxmox-home: capture node inventory (VM list, storage, network)
- [ ] Run home WAN speed test (speedtest-cli or fast.com)
- [ ] Populate `ops/bindings/home.unifi.network.inventory.yaml`

### Step 8: Hardware Walk-Through (GAP-OP-1358)
- [ ] Walk through home with phone/camera
- [ ] Photograph serial number labels on: router, switches, AP, NAS, Proxmox host, IoT hubs
- [ ] Record model/serial/placement into `ops/bindings/home.hardware.inventory.yaml`

### Step 9: Ring Separation Implementation (GAP-OP-1361)
- [ ] Implement ring architecture decision from Step 0
- [ ] Add ring_assignment field to gate.registry.yaml for D113-D120
- [ ] Update verify.release.run with conditional skip or ring topology
- [ ] Commit and verify ring separation works

### Step 10: Final Verify + Commit
- [ ] Run `./bin/ops cap run verify.release.run` -- all home gates PASS
- [ ] Run `./bin/ops cap run verify.run -- domain home` if available
- [ ] Commit all artifacts
- [ ] Close gaps: 1352, 1354, 1356, 1357, 1358, 1359, 1360, 1361
