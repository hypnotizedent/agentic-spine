# Plan: Home Canonical Realignment
## Date: 2026-03-02
## Authority: SPINE-CONTROL-01
## Loop: LOOP-HOME-CANONICAL-REALIGNMENT-20260302
## Status: planned / later / blocked (offsite)

---

## Mission

Carve Home infrastructure into a first-class canonical program. Establish dedicated authority contracts, machine-readable inventories, and verify-ring isolation so Home runtime volatility does not leak into Spine core verifies.

---

## Gap Pack (9 total: 7 new + 2 reparented)

| Gap ID | Title | Type | Severity | Wave |
|--------|-------|------|----------|------|
| GAP-OP-1352 | HA runtime blocker: D113/D114/D118/D120 unreachable | runtime-bug | high | W4 (reparented) |
| GAP-OP-1354 | HA data-quality: D115 (199 unavailable), D119 (Z2M naming) | stale-ssot | high | W3-W4 (reparented) |
| GAP-OP-1355 | Home agent access model undefined | missing-entry | medium | W1 |
| GAP-OP-1356 | Zigbee reliability baseline missing | runtime-bug | high | W4 |
| GAP-OP-1357 | UniFi/Proxmox-home normalization missing | missing-entry | medium | W2 |
| GAP-OP-1358 | Full home hardware inventory missing | missing-entry | medium | W2 |
| GAP-OP-1359 | HA catalog authority missing (199 unavailable entities) | stale-ssot | high | W3 |
| GAP-OP-1360 | Dashboard/automation registries missing | missing-entry | medium | W3 |
| GAP-OP-1361 | Verify-ring leakage (home gates in spine-core ring) | agent-behavior | high | W5 |

---

## Authority Files (Created as Skeletons)

| File | Purpose | Status |
|------|---------|--------|
| `docs/governance/HOME_AUTHORITY_INDEX.md` | Master index for home domain | skeleton |
| `ops/bindings/home.authority.contract.yaml` | Authority contract | skeleton |
| `ops/bindings/home.hardware.inventory.yaml` | Physical device inventory | skeleton |
| `ops/bindings/home.unifi.network.inventory.yaml` | UniFi network inventory | skeleton |
| `ops/bindings/home.proxmox.inventory.yaml` | Proxmox-home node inventory | skeleton |
| `ops/bindings/home.assistant.catalog.snapshot.yaml` | HA integration/HACS/add-on catalog | skeleton |
| `ops/bindings/home.automation.registry.yaml` | Automation/scene/script/helper registry | skeleton |
| `ops/bindings/home.dashboard.registry.yaml` | Dashboard/Lovelace registry | skeleton |

---

## Day Agenda: On-Site Wave Execution

### Pre-Requisites
- Physical presence at home
- Laptop on home LAN (10.0.0.x)
- HA accessible at 10.0.0.100:8123
- SSH access to HA host

### W0: Verification Baseline (15 min)
```bash
./bin/ops cap run verify.release.run    # Confirm D113-D120 status from LAN
./bin/ops cap run ha.status             # Confirm HA API reachable
./bin/ops cap run gaps.status           # Baseline gap count
```
- **Go/No-Go**: HA reachable from LAN. If not, troubleshoot HA first.
- **Rollback**: None (read-only)

### W1: Agent Access Model (30 min)
**Target**: GAP-OP-1355
- [ ] Define read/write lanes in `home.authority.contract.yaml`
- [ ] Inventory service credentials (HA token, Z2M, UniFi controller)
- [ ] Document audit path for home domain mutations
- [ ] Update `HOME_AUTHORITY_INDEX.md` access model section
- **Go/No-Go**: HA token valid, can authenticate
- **Rollback**: Revert contract file to skeleton
- **Operator Input**: Confirm credential storage paths in Infisical

### W2: Hardware + Network Reconciliation (60 min)
**Target**: GAP-OP-1357, GAP-OP-1358
- [ ] Walk-through: photograph and record all physical devices with serial numbers
- [ ] Populate `home.hardware.inventory.yaml` with complete device list
- [ ] Access UniFi controller, export device/port/VLAN config
- [ ] Populate `home.unifi.network.inventory.yaml`
- [ ] Determine Proxmox-home status (active/not_applicable/planned)
- [ ] Update `home.proxmox.inventory.yaml` accordingly
- [ ] Measure home WAN speed (up/down)
- **Go/No-Go**: Physical access to all equipment
- **Rollback**: Revert inventory files to skeleton
- **Operator Input**: UniFi controller credentials, equipment access

### W3: HA Catalog Authority (60 min)
**Target**: GAP-OP-1354 (partial), GAP-OP-1359, GAP-OP-1360
- [ ] Snapshot all HA integrations (domain, title, state, version)
- [ ] Inventory HACS components (category, name, version, repository)
- [ ] Inventory add-ons (slug, name, version, state)
- [ ] Populate `home.assistant.catalog.snapshot.yaml`
- [ ] Registry all automations, scenes, scripts, helpers
- [ ] Populate `home.automation.registry.yaml`
- [ ] Registry all Lovelace dashboards and custom resources
- [ ] Populate `home.dashboard.registry.yaml`
- [ ] Run `ha.ssot.baseline.build` to refresh entity baseline
- **Go/No-Go**: HA API returns valid responses for all endpoints
- **Rollback**: Revert catalog/registry files to skeleton
- **Operator Input**: None (API-driven)

### W4: Zigbee Reliability (45 min)
**Target**: GAP-OP-1352, GAP-OP-1354 (remainder), GAP-OP-1356
- [ ] Capture Z2M network map (topology + link quality)
- [ ] Record LQI/SNR per device
- [ ] Identify dead routers or weak links
- [ ] Fix Z2M naming parity drift (`living_switch_scene` resolution)
- [ ] Run `ha.z2m.devices.snapshot` to refresh device snapshot
- [ ] Run `ha.device.map.build` to rebuild cross-reference
- [ ] Verify D118 (Z2M device health) PASS
- [ ] Verify D119 (Z2M naming parity) PASS
- [ ] Verify D113/D114/D120 PASS from LAN
- **Go/No-Go**: Z2M bridge connected, SLZB-06MU reachable
- **Rollback**: Naming changes revertible via git
- **Operator Input**: Decision on `living_switch_scene` — add to devices.yaml or remove from naming.yaml

### W5: Gate-Ring Separation (30 min)
**Target**: GAP-OP-1361
- [ ] Define `home-runtime` verify ring
- [ ] Move D113, D114, D115, D118, D119, D120 to home-runtime ring
- [ ] Add conditional skip when HA unreachable (offsite detection)
- [ ] Update verify.release.run ring topology
- [ ] Ensure `verify.run -- fast` (spine-core) unaffected
- [ ] Test: from offsite, home-runtime gates SKIP (not FAIL)
- [ ] Register ring separation in gate.registry.yaml
- **Go/No-Go**: All previous waves complete
- **Rollback**: Revert ring configuration
- **Operator Input**: Ring naming convention approval

### W6: Verify + Closeout (15 min)
- [ ] Run `verify.release.run` — confirm all gates PASS
- [ ] Run `gaps.status` — confirm 0 open gaps for this loop (all resolved)
- [ ] Update all skeleton files to `status: active`
- [ ] Update `home.authority.contract.yaml` status to active
- [ ] Close loop: `loops.close LOOP-HOME-CANONICAL-REALIGNMENT-20260302`
- [ ] Commit and push all artifacts
- **DoD**: Zero HA-related gates in spine-core fast verify. All inventories populated. Authority contract active.

---

## Timing Estimate (On-Site Day)

| Wave | Duration | Running Total |
|------|----------|---------------|
| W0 | 15 min | 0:15 |
| W1 | 30 min | 0:45 |
| W2 | 60 min | 1:45 |
| W3 | 60 min | 2:45 |
| W4 | 45 min | 3:30 |
| W5 | 30 min | 4:00 |
| W6 | 15 min | 4:15 |

**Total: ~4.25 hours** (single dedicated day, with breaks)

---

## Files Changed in This Planning Wave

| File | Change |
|------|--------|
| `mailroom/state/loop-scopes/LOOP-HOME-CANONICAL-REALIGNMENT-20260302.scope.md` | new |
| `docs/governance/HOME_AUTHORITY_INDEX.md` | new |
| `ops/bindings/home.authority.contract.yaml` | new |
| `ops/bindings/home.hardware.inventory.yaml` | new |
| `ops/bindings/home.unifi.network.inventory.yaml` | new |
| `ops/bindings/home.proxmox.inventory.yaml` | new |
| `ops/bindings/home.assistant.catalog.snapshot.yaml` | new |
| `ops/bindings/home.automation.registry.yaml` | new |
| `ops/bindings/home.dashboard.registry.yaml` | new |
| `ops/bindings/operational.gaps.yaml` | 7 gaps added + 2 reparented |
| `mailroom/state/plans/PLAN-HOME-CANONICAL-REALIGNMENT-20260302.md` | new |

**Zero runtime mutations. Planning/governance only.**
