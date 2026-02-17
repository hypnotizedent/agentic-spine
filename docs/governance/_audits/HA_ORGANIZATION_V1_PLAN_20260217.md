---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ha-organization-v1-plan
parent_loop: LOOP-HA-ORGANIZATION-V1-20260217
---

# HA Organization V1 Plan (Registration-Only)

## Objective

Prepare governed execution scaffolding for HA organization cleanup without mutating HA runtime in this lane.

## Workstreams

### WS1 — Areas + Naming Normalization

- Loop: `LOOP-HA-AREA-NAMING-BATCH-V1-20260217`
- Gaps: `GAP-OP-651`, `GAP-OP-654`
- Scope: normalize area assignment and device naming rules; define triage path for pseudo-devices/orphans.

### WS2 — IP Normalization + DHCP Audit Population

- Loop: `LOOP-HA-IP-NORMALIZATION-V1-20260217`
- Gap: `GAP-OP-652`
- Scope: align DHCP naming/IP truth with `home.dhcp.audit` and define seed-to-runtime reconciliation.

### WS3 — HA Schema + Environment Contracts

- Loop: `LOOP-HA-SCHEMA-ENVIRONMENTS-V1-20260217`
- Gap: `GAP-OP-653`
- Scope: introduce canonical schema artifacts for HA naming and environment partitioning.

## Exact File Touch Map (HA Executor Lane)

### WS1 expected files

- `ops/plugins/ha/bin/ha-device-rename`
- `ops/plugins/ha/bin/ha-device-map-build`
- `ops/bindings/ha.areas.yaml`
- `ops/bindings/ha.device.map.yaml`
- `ops/bindings/ha.device.map.overrides.yaml`
- `ops/bindings/ha.orphan.classification.yaml`
- `ops/bindings/home.device.registry.yaml`
- `ops/capabilities.yaml` (only if capability metadata/contract text needs parity updates)

### WS2 expected files

- `ops/plugins/network/bin/network-home-dhcp-audit`
- `ops/bindings/home.dhcp.audit.yaml`
- `ops/bindings/network.home.baseline.yaml`
- `ops/bindings/home.device.registry.yaml`
- `ops/capabilities.yaml` (only if capability metadata/contract text needs parity updates)

### WS3 expected files

- `ops/bindings/ha.naming.convention.yaml` (new)
- `ops/bindings/ha.environments.yaml` (new)
- `ops/bindings/ha.device.map.yaml`
- `ops/bindings/ha.ssot.baseline.yaml`
- `ops/bindings/gate.execution.topology.yaml` (only if verify route updates are required)

## Acceptance Criteria

1. Areas and naming standards are codified with deterministic mapping rules and override contract.
2. `home.dhcp.audit` has a defined source contract and reproducible population/reconciliation path.
3. `ha.naming.convention.yaml` and `ha.environments.yaml` exist and validate against executor workflow assumptions.
4. HACS pseudo-device/orphan handling policy is explicitly classified (retain, ignore, quarantine, or delete-triage).
5. All changes remain governed by loop/gap linkage and pass `verify.core.run` + `verify.domain.run home --force`.

## Operator Decisions — LOCKED (2026-02-17 WS1 execution)

1. **Winix area placement:** Physically confirmed via turbo-blast test. Bedroom=bedroom, Guest Room=guest_room, Living Room=living_room, Office=office. Entity names already correct; device names and area_ids need update.
2. **Firestick vs Apple TV:** DEFERRED to future pass. Media players not moved/renamed in WS1. User will confirm physical locations room-by-room.
3. **IP range 70-89:** APPROVED by operator for WiFi IoT devices. Reference only in WS1 — no DHCP changes until WS2.
4. **Laundry area:** DEFERRED. Vibration sensor stays in Entryway for now.
5. **HACS pseudo-device handling:** DEFERRED to WS3. Leave 34 HACS plugin devices unassigned.
6. **Naming convention:** `{area}_{function}_{qualifier}` snake_case. Applied to WS1 device set only.
7. **TP-Link plug assignment:** TEMPORARY — AE99 as `bedroom_plug_king`, B6EE as `bedroom_plug_empress` (pending operator confirmation of which physical plug is which side).
8. **Tuya curtain + planter:** DEFERRED. Left as-is in living_room.

## WS1 Mutation Plan

### Area Moves (4 devices)
| Device ID | Current Name | From | To |
|-----------|-------------|------|----|
| d5133851e178cba86893f0a5ac18e578 | office_button (Z2M TS0041) | living_room | office |
| 96775512e1b9f9c6292b2db2e0f69419 | Guest Room Smart Bulb | living_room | guest_room |
| 989ce93ea4504ba71c1feac70573eff6 | Winix Hallway | living_room | office |
| 7426dcfc7c55cfe7a339d7cff0b23640 | Winix Play Room | living_room | guest_room |

### Renames (12 devices)
| Device ID | Current Name | New Name |
|-----------|-------------|----------|
| 989ce93ea4504ba71c1feac70573eff6 | Winix Hallway | Office Purifier |
| bcb1075aced51e98b75b66a9a91a6800 | Winix Library | Living Room Purifier |
| 7426dcfc7c55cfe7a339d7cff0b23640 | Winix Play Room | Guest Room Purifier |
| f439e4813d1e9b172b32c0a62b0c0d4f | Winix Bed Room | Bedroom Purifier |
| 5a2751339a61abc65934d1ee7b9cea73 | Q8 Max | Living Room Vacuum Q8 |
| 2cffb9c172e42724799d183e5ddd1b18 | Q8 Max Dock | Living Room Vacuum Q8 Dock |
| c176fd7803d58ed555bc665afc8859a9 | Empress Button | Bedroom Button Empress |
| 74f725559a00321623da25790148a79f | KING LIGHT | Bedroom Bulb King |
| 39ebea9941b12e04a78e3a20dca5a0ab | Empress light | Bedroom Bulb Empress |
| 30507401ebb1b318c685c79a0517ac36 | TP-LINK_Smart Plug_AE99 | Bedroom Plug King |
| 61e23b1a8113139522ee1bcecf5f06c5 | TP-LINK_Smart Plug_B6EE | Bedroom Plug Empress |
| e20aaef29f4e1c267f93b648a915a844 | Pogo | Bedroom Litterbot Pogo |
