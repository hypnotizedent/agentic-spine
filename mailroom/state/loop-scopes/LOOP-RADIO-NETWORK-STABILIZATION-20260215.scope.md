---
id: LOOP-RADIO-NETWORK-STABILIZATION-20260215
status: open
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-438
  - GAP-OP-439
  - GAP-OP-440
  - GAP-OP-441
  - GAP-OP-442
  - GAP-OP-443
---

# Radio Coordinator Stabilization + Home Network Baseline

## Objective

Complete radio coordinator governance (firmware SOPs, Z-Wave/Matter readiness runbooks),
add coordinator health monitoring gates, retire legacy backup docs, and establish a
home network baseline binding.

## Scope

### Phase 1: Documentation (GAP-OP-438 through GAP-OP-441)
- Firmware management SOP (runbook Section 6.1)
- Z-Wave readiness runbook (Section 6.2)
- Matter/Thread readiness runbook (Section 6.3)
- Retire legacy offsite sync documentation (Section 7)

### Phase 2: Monitoring (GAP-OP-442, GAP-OP-443)
- D113 coordinator health probe gate
- D114 automation count stability gate

## Exit Criteria

- Runbook sections 6.1, 6.2, 6.3 exist with complete SOPs
- Section 7 "Offsite Sync" retired with vzdump explanation
- D113 and D114 gates registered and passing (or SKIP if HA unreachable)
- D85 gate count parity PASS
