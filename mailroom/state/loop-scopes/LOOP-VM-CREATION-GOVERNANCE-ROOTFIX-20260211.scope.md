---
status: active
owner: "@ronny"
created: 2026-02-11
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

1. **New VM contract doc** exists at `docs/governance/VM_CREATION_CONTRACT.md`
   - Lists every SSOT file that MUST be updated when a VM is created
   - Defines required fields per file
   - Machine-parseable checklist section for gate consumption

2. **VM lifecycle binding** exists at `ops/bindings/vm.lifecycle.yaml`
   - Lists all VMs with their VMID, hostname, LAN IP, Tailscale IP, user, status
   - Single source of truth for "what VMs exist" — all other files reference this
   - Statuses: active, stopped, template, decommissioned

3. **Drift gate** (next available: D69) enforces:
   - Every `active` VM in vm.lifecycle.yaml has entries in:
     - NODE_REGISTRY.yaml (host entry)
     - backup.inventory.yaml (target entry)
     - ssh.targets.yaml (target entry)
   - Every VM in vm.lifecycle.yaml has a valid LAN IP matching D54 IP parity
   - No orphaned VM entries exist in downstream files without lifecycle entry

4. **Existing VMs backfilled** — all current VMs (200, 202-211) pass the gate

5. **spine.verify PASS** — D1-D69 all pass including the new gate

## Phases

| Phase | Scope | Owner | Status |
|-------|-------|-------|--------|
| P0 | Register loop + GAP-OP-103 | Terminal C | PENDING |
| P1 | VM contract doc + lifecycle binding + gate | Terminal D/E/F | PENDING |
| P2 | Backfill existing VMs | Terminal D/E/F | PENDING |
| P3 | Validate + close | Terminal C | PENDING |

## Registered Gaps

- GAP-OP-103: VM creation governance missing at source
