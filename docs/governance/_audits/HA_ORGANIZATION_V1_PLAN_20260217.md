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

## Operator Decision Required

1. Winix area placement policy (single room vs shared/common area).
2. Firestick vs Apple TV identity model (separate entities vs unified media endpoint naming).
3. Formal policy for reserved IP normalization range `70-89`.
4. Laundry area treatment (separate area vs folded into utility/common).
5. HACS handling policy for pseudo-devices and orphans (visibility and cleanup thresholds).
6. Final tie-break rule when device naming conflicts with existing SSOT aliases.
