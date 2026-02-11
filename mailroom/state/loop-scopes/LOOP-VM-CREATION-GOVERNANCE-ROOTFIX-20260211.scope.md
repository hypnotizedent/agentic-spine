---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-VM-CREATION-GOVERNANCE-ROOTFIX-20260211
severity: high
---

# Loop Scope: LOOP-VM-CREATION-GOVERNANCE-ROOTFIX-20260211

## Goal

Implement root governance for VM creation so agents cannot create drift.
Today, a new VM can be provisioned without updating all required SSOT files,
leaving registries, backup inventory, health probes, and IP parity out of sync.
This loop adds a contract, lifecycle binding, and drift gate to enforce
cross-file parity at the source.

## Problem

No single gate prevents an agent from creating a VM and forgetting to update
SERVICE_REGISTRY, STACK_REGISTRY, NODE_REGISTRY, backup.inventory,
services.health, docker.compose.targets, ssh.targets, or IP parity docs.
D54 checks IP parity but only for existing entries — it does not enforce
that a new VM entry exists in all required files.

## Acceptance Criteria

1. **New VM contract doc** exists at `docs/core/VM_CREATION_CONTRACT.md` — DONE (cb6a892)
2. **VM lifecycle binding** exists at `ops/bindings/vm.lifecycle.yaml` — DONE (cb6a892)
3. **Drift gate D69** enforces cross-file parity for active VMs — DONE (53a8d1e + bd74181)
4. **Existing VMs backfilled** — 10/10 active shop VMs pass D69 — DONE (bd74181)
5. **spine.verify PASS** — D1-D69 all pass — DONE

## Phases

| Phase | Scope | Owner | Status | Commit/Proposal |
|-------|-------|-------|--------|-----------------|
| P0 | Register loop + GAP-OP-103 | Terminal C | DONE | 9efa67e |
| P1 | VM contract doc + lifecycle binding + registration | Terminal D | DONE | CP-20260211-203626 / cb6a892 |
| P2 | D69 gate + vm.governance.audit capability | Terminal E | DONE | CP-20260211T203757Z / 53a8d1e |
| P3 | Wiring + immich ssh fix + validate + close | Terminal C | DONE | bd74181 + (this commit) |

## Registered Gaps

- GAP-OP-103: VM creation governance missing at source — **FIXED**

## P3 Validation Evidence

**spine.verify**: ALL PASS (D1-D69)
**vm.governance.audit**: 10/10 active shop VMs governed, 0 gaps
**gaps.status**: GAP-OP-037 (baseline) + GAP-OP-103 (closed this commit)

Receipt IDs:
- CAP-20260211-154538__spine.verify__Roe5767765
- CAP-20260211-154637__vm.governance.audit__R6ih078672
- CAP-20260211-154636__gaps.status__Ruyuc78601

## What Changed "At Root"

Before this loop, VM creation was ungoverned — agents could provision VMs without
updating all SSOT files. Now:

1. **Contract**: `docs/core/VM_CREATION_CONTRACT.md` defines 6 lifecycle phases (PLAN → DECOMMISSION)
   with required artifacts and SSOT touchpoints at each phase
2. **Binding**: `ops/bindings/vm.lifecycle.yaml` is the single source of truth for "what VMs exist"
   (11 entries: 10 active shop + 1 decommissioned + 1 template)
3. **Gate**: D69 enforces every active shop VM has entries in ssh.targets, SERVICE_REGISTRY,
   backup.inventory, and services.health — checked on every `spine.verify`
4. **Capability**: `vm.governance.audit` provides on-demand columnar coverage report
5. **Bug fix**: Added immich to ssh.targets.yaml (real gap caught by D69 on first run)
