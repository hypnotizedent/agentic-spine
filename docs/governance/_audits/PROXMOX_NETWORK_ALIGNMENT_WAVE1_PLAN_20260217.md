---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: proxmox-network-alignment-wave1-plan
parent_loop: LOOP-PROXMOX-NETWORK-ALIGNMENT-V1-20260217
---

# Proxmox-Network Alignment Wave-1 Plan (Registration-Only)

- Parent loop: `LOOP-PROXMOX-NETWORK-ALIGNMENT-V1-20260217`
- Child loops:
  - `LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217`
  - `LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217`
  - `LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217`
  - `LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217`
- Existing blocker reused: `GAP-OP-531` (left unchanged)
- This artifact is planning only. No infra runtime behavior changes are implemented in this lane.

## Findings Summary

1. Infra capability entries for `infra.proxmox.maintenance.*` and `infra.post_power.recovery*` are present but do not declare consistent machine-readable metadata (`plane`/`domain`/`requires`) in `ops/capabilities.yaml`.
2. Infra scripts currently execute with local argument parsing and safety checks but do not consistently resolve policy knobs through `ops/lib/resolve-policy.sh`.
3. Cross-site maintenance orchestration exists, but home/shop ordering and a composite maintenance-window surface are not registered as a dedicated governed lane.
4. `verify.domain.run` topology currently covers `infra` and `network` domains, but proxmox-network specific domain-profile lane scaffolding is missing.
5. Drift-gate coverage for infra metadata parity + site parity + NAS baseline checks is not yet registered as a dedicated gate family (tracked as D137/D138/D139-style intent).

## Exact File Touch Map (Execution Scope for Infra Agent)

### LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217
- `ops/capabilities.yaml`
- `ops/plugins/infra/bin/infra-proxmox-maintenance`
- `ops/plugins/infra/bin/infra-post-power-recovery`
- `ops/lib/resolve-policy.sh`

### LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217
- `ops/bindings/startup.sequencing.yaml`
- `ops/plugins/infra/bin/infra-post-power-recovery`
- `ops/capabilities.yaml`
- `ops/bindings/network.cutover.policy.yaml`

### LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.domain.profiles.yaml`
- `ops/bindings/agent.verify.profiles.yaml`
- `ops/plugins/verify/bin/verify-topology`

### LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217
- `surfaces/verify/d137-infra-capability-metadata-parity.sh` (planned new)
- `surfaces/verify/d138-site-parity-maintenance-order.sh` (planned new)
- `surfaces/verify/d139-nas-baseline-coverage.sh` (planned new)
- `ops/bindings/gate.registry.yaml`
- `ops/bindings/gate.execution.topology.yaml`

## Execution Order (Infra Agent)

1. `LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217` (`GAP-OP-646`, `GAP-OP-647`)
2. `LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217` (`GAP-OP-648`)
3. `LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217` (`GAP-OP-649`)
4. `LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217` (`GAP-OP-650`, coordinated with pre-existing `GAP-OP-531`)

## Acceptance Criteria

1. New capability metadata fields are present and non-empty for targeted infra surfaces.
2. Target infra scripts resolve policy knobs through governed resolver (`resolve-policy.sh`) with backward compatibility.
3. Home/shop maintenance ordering and maintenance-window orchestration are represented by governed capability/binding surfaces.
4. Proxmox-network lane can be routed by `verify.domain.run` through topology/profile contracts.
5. New drift gates are registered, runnable, and domain-assigned with deterministic PASS/FAIL semantics.

## Stop Conditions

1. Any modification attempts to change status/definition of `GAP-OP-590`, `GAP-OP-635`, `GAP-OP-642`, `GAP-OP-643`, `GAP-OP-644`, `GAP-OP-645`, or `GAP-OP-531`.
2. Any mutation beyond registration/planning surfaces in this lane.
3. Any proposal queue action other than pending proposal submission.
4. Any failing core/aof certification gate in closeout.
