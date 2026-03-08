---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: proxmox-vm-operator-checklist
version: 1.0
companion_to: docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md
---

# Proxmox VM Operator Checklist

**Purpose**: Executable checklist for operators changing VM protection, offsite posture, restore state, or destructive hypervisor/guest runtime behavior.

**When to Use**: Before VM or LXC changes, before offsite changes, before calling a guest protected, and before any destructive restore or recreate path.

---

## Before Changing a VM or LXC

- [ ] Link the work to an active loop or gap
- [ ] Read `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md` if the protection class is unclear
- [ ] Confirm the guest exists and is active in `ops/bindings/vm.lifecycle.yaml`
- [ ] Confirm the guest backup and restore class in `ops/bindings/backup.inventory.yaml`
- [ ] Identify the hosted stacks and services in `docs/governance/STACK_REGISTRY.yaml` and `docs/governance/SERVICE_REGISTRY.yaml`
- [ ] Run `./bin/ops cap run backup.status`
- [ ] If the guest is on `proxmox-home`, run `./bin/ops cap run home.backup.status`
- [ ] Run `./bin/ops cap run verify.run -- domain backup`
- [ ] Name the current restore point before mutation

---

## Before Enabling or Disabling Offsite

- [ ] Confirm whether this is a shop exact offsite target, a home primary backup target, or an app-level offsite supplement
- [ ] Verify the target exists in `ops/bindings/backup.inventory.yaml`
- [ ] If enabling offsite, state the exact source artifact, destination path, freshness threshold, and restore class
- [ ] If disabling offsite, write the reason as an explicit exception, not a vague note
- [ ] If disabling for size or bandwidth, name the compensating app-level backup lane that will carry irreplaceable state
- [ ] Rebuild posture after the change with `./bin/ops cap run backup.posture.snapshot.build`
- [ ] Re-run `./bin/ops cap run backup.status`

Never describe a VM as offsite-protected unless an exact offsite target is enabled and fresh.

---

## Before Declaring a VM "Protected"

- [ ] `vm.lifecycle.yaml` says the guest is active
- [ ] `backup.inventory.yaml` says `backup_admission_state: production_ready`
- [ ] Primary target is fresh
- [ ] Required app-level targets are fresh
- [ ] Offsite state is truthful: enabled, explicit exception, or not claimed
- [ ] Restore class is present
- [ ] Current restore receipt exists within cadence

Use this vocabulary:

- `safe` = all required controls and proof exist now
- `planned` = inventory exists but protection or proof is incomplete
- `exception` = non-default path is explicit; only call it safe if compensating proof is current

---

## Before Using VM-Level Backup as a Substitute for App-Level Backup

- [ ] Check whether the guest has a companion app-level or container-fleet unit in `backup.inventory.yaml`
- [ ] If the guest hosts Postgres, MinIO, mail, document, vault, or similar mutable state, assume VM-only is not enough
- [ ] If the guest is `media-lean`, remember config-state is covered but payload is excluded
- [ ] If the guest is `vm-rebuildable` or `vm-covered`, verify that rebuild or VM restore is actually sufficient for the service
- [ ] If app-level supplement is required, identify the exact app target and restore class before proceeding

Current default supplement-required guests:

- `finance-stack`
- `mint-data`
- `communications-stack`
- `automation-stack`
- `dev-tools`
- `download-stack`
- `streaming-stack`

---

## Before Destructive Restore, Recreate, or Destroy

- [ ] Identify the exact artifact to restore or preserve
- [ ] Confirm the target VMID or CTID
- [ ] Confirm decommission policy in `vm.lifecycle.yaml`
- [ ] Take or verify a current final backup before overwrite or destroy
- [ ] Record the break-glass reason in the loop or receipt
- [ ] Get explicit operator approval for:
  - `qm destroy` / `pct destroy`
  - disk detach, delete, or recreate
  - `qmrestore` / `pct restore` over an existing ID
  - stateful `docker compose down`
  - restore-overwrite actions
- [ ] If a governed compose wrapper exists, use it instead of raw `docker compose`
- [ ] After the action, re-run backup status and record the new restore point

---

## Monthly Checks

Run monthly:

```bash
./bin/ops cap run backup.status
./bin/ops cap run backup.posture.snapshot.build
./bin/ops cap run verify.run -- domain backup
./bin/ops cap run home.backup.status
```

- [ ] Review all degraded VM and app targets
- [ ] Review all disabled exact offsite targets and confirm the rationale still holds
- [ ] Review whether any guest has gained stateful services that now require app-level supplement
- [ ] Review home claims carefully: Synology means primary backup, not true offsite DR

---

## Quarterly Checks

Run quarterly:

```bash
./bin/ops cap run verify.pack.run backup
```

- [ ] Prove restore coverage for all `vm-dry-run-quarterly` and `tier1-small-state-dry-run-quarterly` classes
- [ ] Prove compensating app-level restore for any VM with disabled exact offsite
- [ ] Re-attest that `mint-data` and `communications-stack` still require size-based exact offsite exceptions
- [ ] Reconfirm that no guest is being called protected without a current restore receipt

---

## Quick Reference

- **Doctrine**: `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md`
- **Inventory**: `ops/bindings/vm.lifecycle.yaml`
- **Backup Policy**: `ops/bindings/backup.inventory.yaml`
- **Home Site Context**: `docs/governance/MINILAB_SSOT.md`
- **Gap Filing**: `./bin/ops cap run gaps.file -- --id auto --type missing-entry --severity medium --description "..."`

---

## Checklist Version

- **Version**: v1.0
- **Last Updated**: 2026-03-08
- **Companion Doctrine**: Proxmox VM Safety Doctrine v1.0
