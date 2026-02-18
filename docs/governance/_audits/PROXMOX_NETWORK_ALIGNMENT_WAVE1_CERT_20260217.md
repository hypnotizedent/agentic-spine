---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: proxmox-network-alignment-wave1-certification
parent_loop: LOOP-PROXMOX-NETWORK-ALIGNMENT-V1-20260217
---

# Proxmox-Network Alignment Wave-1 Certification

## Summary

All 5 child gaps (GAP-OP-646 through GAP-OP-650) implemented and fixed.
All 4 child loops and the parent loop closed with verification evidence.

## Implemented Gaps

| Gap | Description | Fixed In |
|-----|-------------|----------|
| GAP-OP-646 | Infra capability metadata (plane/domain/requires) for 6 capabilities | capabilities.yaml |
| GAP-OP-647 | Policy integration (resolve-policy.sh) for 3 infra scripts | infra-proxmox-maintenance, infra-post-power-recovery, infra-proxmox-node-path-migrate |
| GAP-OP-648 | Home-shop maintenance parity: site tags in startup.sequencing.yaml v2, infra-maintenance-window orchestrator, infra.maintenance.window capability | startup.sequencing.yaml, infra-maintenance-window, capabilities.yaml |
| GAP-OP-649 | Proxmox-network composite domain lane: domain profile, topology metadata, release sequence | gate.domain.profiles.yaml, gate.execution.topology.yaml |
| GAP-OP-650 | Drift gates D137/D138/D139 for infra-hygiene family | gate scripts, gate.registry.yaml, gate.execution.topology.yaml, gate.domain.profiles.yaml |

## New Drift Gates

| Gate | Name | Checks |
|------|------|--------|
| D137 | infra-capability-metadata-parity | 7 infra capabilities have plane=fabric, domain=infra, requires preconditions |
| D138 | site-parity-maintenance-order | startup.sequencing.yaml has site tags for all phases, both shop+home represented |
| D139 | nas-baseline-coverage | NAS device identity in home.device.registry.yaml + backup targets in backup.inventory.yaml |

## Final Verification Summary

| Lane | Result | Notes |
|------|--------|-------|
| Core (8 gates) | 8/8 PASS | Clean |
| AOF (19 gates) | 19/19 PASS | D128 PASS after enforcement boundary advance |
| Infra (25 gates) | 24/25 | D86 pre-existing (13 VMs missing vmid field) |
| Proxmox-network (25 gates) | 24/25 | D86 pre-existing (same root cause) |

## Pre-existing Baseline: D86

D86 (vm-lifecycle-parity) fails for 13 active VMs missing the `vmid` field in `ops/bindings/vm.lifecycle.yaml`. This is a known pre-existing gap unrelated to wave-1 scope. Tracked separately.

## Closed Loops

| Loop | Scope | Gaps |
|------|-------|------|
| LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217 | Infra capability metadata + policy | GAP-OP-646, GAP-OP-647 |
| LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217 | Home/shop maintenance ordering | GAP-OP-648 |
| LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217 | Domain profile + verify lane | GAP-OP-649 |
| LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217 | Drift gate coverage | GAP-OP-650 |
| LOOP-PROXMOX-NETWORK-ALIGNMENT-V1-20260217 | Parent wave-1 orchestration | All above |
