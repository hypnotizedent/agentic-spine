---
id: LOOP-COORDINATOR-ACTIVATION-20260215
status: closed
closed: 2026-02-15
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-453
  - GAP-OP-454
  - GAP-OP-455
  - GAP-OP-456
  - GAP-OP-457
---

# Coordinator Activation (All Three Plugged In)

## Objective

All three radio coordinators (SLZB-06, SLZB-06MU, TubesZB) are now plugged into a
UniFi switch. Fix stale firmware docs, update bindings, extend D113, write CLI-based
activation checklists for Z-Wave JS UI and OTBR, and create snapshot capabilities.

## Phase A: Governance Fixes (GAP-OP-453 through GAP-OP-455)
- Fix runbook S6 firmware versions (SLZB-06MU v3.2.4, radio 20241105)
- Update device registry + baseline (TubesZB "on-hand" -> "connected")
- Extend D113 to check TubesZB ESPHome + Z-Wave serial state

## Phase B: Activation + Capabilities (GAP-OP-456, GAP-OP-457)
- Z-Wave JS UI activation checklist (CLI-only, no HA UI)
- OTBR wiring checklist (CLI-only)
- ha.zwave.devices.snapshot capability

## Exit Criteria

- Runbook firmware versions match live API
- D113 checks all 3 coordinators
- CLI activation checklists in runbook
- ha.zwave.devices.snapshot capability registered
