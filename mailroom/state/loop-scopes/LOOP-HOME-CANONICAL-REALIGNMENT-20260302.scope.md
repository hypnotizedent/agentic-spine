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

Current state:
- 6 release gates blocked by HA unreachability (offsite)
- No HOME_AUTHORITY_INDEX or home.authority.contract
- Hardware inventory is scattered across DEVICE_IDENTITY_SSOT.md and ad-hoc files
- Z2M naming drift (6 vs 5 device count mismatch)
- No HA catalog snapshot (integrations, automations, dashboards)
- Home gates in same verify ring as spine-core gates

## Execution Waves (On-Site Day)

### W0: Authority + Contracts (pre-arrival, planning-only)
- [x] Register loop and gap pack
- [x] Create authority index and contract skeletons
- [x] Create inventory file skeletons
- [ ] Populate known hardware from existing docs

### W1: Agent Access Model
- [ ] Define read/write lanes for home domain
- [ ] Service credential inventory (HA tokens, Z2M API, UniFi controller)
- [ ] Audit path for home mutations

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
