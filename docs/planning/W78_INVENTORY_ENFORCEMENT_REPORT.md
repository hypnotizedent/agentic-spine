# W78 Inventory Enforcement Report

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228

## New Enforcement Surfaces

| gate_id | purpose | mode | contract/script |
|---|---|---|---|
| D294 | Rogue Proxmox VM detection (runtime vs `vm.lifecycle`) | report_only | `ops/bindings/inventory.enforcement.contract.yaml`, `surfaces/verify/d294-proxmox-rogue-vm-detection-lock.sh` |
| D295 | Undeclared docker stack detection (runtime vs compose targets) | report_only | `ops/bindings/inventory.enforcement.contract.yaml`, `surfaces/verify/d295-undeclared-docker-stack-detection-lock.sh` |

## Execution Evidence

- Direct script checks:
  - `D294 REPORT: runtime observation unavailable (qm command missing); declared_active_vm_count=15`
  - `D295 REPORT: docker compose runtime list unavailable/empty; declared_stack_count=28`
- Pack evidence:
  - `CAP-20260228-082937__verify.pack.run__R9t3o74492` (`hygiene-weekly` includes D294/D295 PASS in report-only mode)

## Interpretation

Runtime access constraints are surfaced as explicit non-green report evidence, not silent green drift. Enforcement can be flipped by contract mode when runtime access windows are approved.
