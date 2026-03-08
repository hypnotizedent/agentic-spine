---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: proxmox-vm-safety-doctrine
version: 1.0
---

# Proxmox VM Safety Doctrine v1

**Purpose**: Define the non-negotiable rules for VM lifecycle, primary backup, offsite backup, destructive hypervisor actions, and restore proof across `pve` and `proxmox-home`.

**Authority**: This doctrine is the canonical source of truth for Proxmox / VM / offsite safety. VM and LXC operations must comply with this doctrine before operators rely on habit, legacy scripts, or thin domain stubs.

**Scope**: Applies to all active VMs and LXCs in `ops/bindings/vm.lifecycle.yaml`, their backup/offsite targets in `ops/bindings/backup.inventory.yaml`, and any guest runtime that can be destroyed, recreated, or restored through Proxmox or guest-level compose operations.

---

## Why This Exists

The current VM safety model is real but fragmented. VM identity lives in `vm.lifecycle.yaml`. Backup and offsite truth live in `backup.inventory.yaml`. Stack meaning lives in `STACK_REGISTRY.yaml` and `SERVICE_REGISTRY.yaml`. Home-site reality is partly explained in `MINILAB_SSOT.md`. Legacy workbench scripts still imply old offsite habits.

That leaves too much room for improvisation around:

- which VMs are actually protected
- which VMs require exact offsite copies
- when app-level backup must supplement VM backup
- what a disabled offsite target means
- what destructive `qm` or guest compose actions require
- what restore proof must exist before calling a VM safe

This doctrine exists to stop that drift class.

---

## One Authority Chain

### 1. VM Inventory Authority

- `ops/bindings/vm.lifecycle.yaml` is the canonical inventory of VMs and LXCs.
- It answers: what exists, where it lives, what it hosts, and what decommission policy applies.

### 2. VM Backup and Offsite Authority

- `ops/bindings/backup.inventory.yaml` is the canonical authority for:
  - primary VM backup policy
  - exact offsite targets
  - app-level supplement targets
  - restore classes
  - backup admission state
- Destination lane names do not replace doctrine semantics. The doctrine defines what counts as primary, offsite, app-level, and protected.

### 3. Runtime Context Authority

- `docs/governance/STACK_REGISTRY.yaml` answers which stacks live on which VM.
- `docs/governance/SERVICE_REGISTRY.yaml` answers which services and compose paths live on that VM.

### 4. Operator Workflow Authority

- This doctrine and `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md` are the canonical operator surfaces.
- Thin domain pages and workbench scripts are reference only unless they explicitly defer to this doctrine.

---

## Core Definitions

### Primary Local Backup

The first canonical backup artifact for a VM or LXC in its normal runtime site.

- On shop `pve`, this is the primary vzdump artifact on the hypervisor backup lane.
- On `proxmox-home`, the Synology NFS-mounted vzdump destination is the current primary backup location for home guests.

Primary does **not** mean offsite.

### Offsite Backup

A copy that is explicitly represented as a separate target outside the VM's primary failure domain.

- For shop VMs, exact offsite usually means the NAS offsite lane under `/volume1/backups/proxmox/vzdump/...`.
- For home VMs, Synology is the current primary backup surface, not a true offsite DR copy for the home site.

If no exact offsite target exists, the VM is not offsite-protected.

### App-Level Backup

A service-native backup that supplements VM backup when VM image restore alone is not sufficient, not feasible for offsite, or not granular enough for safe recovery.

Examples in the current estate include finance app dumps, Mint Postgres backups, mail-archiver backups, and media config-state backups.

### Restore Proof

Restore proof requires all of the following:

- a restore class in `backup.inventory.yaml`
- a known restore surface or runbook
- an identified restore point
- a current receipt or drill within the declared cadence

No current restore proof means the VM may be backed up, but it is not safe to describe as fully protected.

---

## VM Class Model

These classes reflect the current `backup.inventory.yaml` protection patterns.

| Class | Current signal | Current examples | Required baseline |
|---|---|---|---|
| `tier1` | `backup_profile: vm-tier1` or `data_class: tier1_critical` | `infra-core`, `finance-stack`, `mint-data`, `communications-stack`, `homeassistant` | primary backup mandatory, restore class mandatory, app-level supplement when guest hosts material service state |
| `primary` | `backup_profile: vm-primary` | `automation-stack`, `immich`, `observability`, `dev-tools`, `ai-consolidation`, `mint-apps`, `surveillance-stack` | primary backup mandatory, app-level supplement only when service state demands it |
| `large-state exception` | exact offsite target exists but is `enabled: false` with size/bandwidth rationale | `mint-data`, `communications-stack` | primary backup mandatory, exact offsite exception must be explicit, compensating app-level backup mandatory |
| `media-lean` | `backup_profile: media-lean` | `download-stack`, `streaming-stack` | config-state backup exists, payload is excluded by design, never describe as full media protection |
| `rebuildable` | `backup_profile: vm-rebuildable` or equivalent | `pihole-home` | primary backup or rebuild proof may be sufficient if state is genuinely low-value and reproducible |

These are protection classes, not provisioning classes.

---

## Offsite Policy

### Default Rule

- Offsite is required only when it is explicitly declared in `backup.inventory.yaml`.
- Do not infer exact offsite protection from a VM being important, from the presence of a NAS, or from a legacy rsync script.

### Offsite-Required Class

- The offsite-required class is the set of VMs with dedicated exact offsite targets in `backup.inventory.yaml`.
- If that exact target is `enabled: true`, the VM is expected to have a current exact copy.
- If that exact target is `enabled: false`, the VM is in a governed exception state and must not be described as exact-offsite protected.
- If no exact target exists, the VM is primary-protected only unless a separate app-level offsite lane says otherwise.

### Current Shop Rule

- Shop VMs on `pve` must always have primary local vzdump protection.
- Exact shop offsite protection exists only for VMs with dedicated offsite targets or an explicit documented exception.

### Current Home Rule

- `proxmox-home` primary VM backups land on Synology and are the canonical home primary backup surface.
- Home does **not** currently have a general second-hop offsite DR surface beyond Synology.
- Do not call home VMs offsite-protected unless a separate cross-site or external copy is explicitly declared.

### Current Exact Offsite State

- Exact offsite enabled: `vm-211-finance-stack-offsite`, `vm-213-mint-apps-offsite`
- Exact offsite exception: `vm-212-mint-data-offsite`, `vm-214-communications-stack-offsite`
- No home-wide true offsite DR exists yet beyond Synology primary storage

---

## Size-Based Exception Model

Large-state VMs are allowed to deviate from nightly exact VM offsite only when the exception is explicit.

A disabled offsite target is governed only if all of the following are true:

- the target exists in `backup.inventory.yaml`
- `enabled: false` is intentional, not accidental
- the description states why nightly exact offsite is infeasible
- the guest has a compensating app-level backup path for irreplaceable state
- restore proof covers the compensating path, not just the local VM image

Current examples:

- `mint-data` VM 212: exact VM offsite disabled because artifacts are too large for the nightly window; Mint Postgres backup is the current compensating lane for database state
- `communications-stack` VM 214: exact VM offsite disabled because the VM approaches 1TB; mail-archiver app backup is the current compensating lane for mail-archiver state

An exception is not the same as a safe state. It is only safe when the compensating control is real and proven.

---

## When VM-Level Backup Alone Is Acceptable

VM-level backup alone is acceptable only when all of the following are true:

- the VM is not represented by a companion app-level runtime unit in `backup.inventory.yaml`
- the guest does not host material database, document, mail, object, or vault state that needs granular restore
- recovery from a VM image is operationally sufficient
- restore proof exists for the VM class

Typical current examples:

- `observability`
- `ai-consolidation`
- `mint-apps`
- `pihole-home` when treated as rebuildable

VM-level backup is **not** enough when the guest hosts stateful services that already have a companion app-aware or tier1-small-state unit in `backup.inventory.yaml`.

Current supplement-required examples:

- `finance-stack`
- `mint-data`
- `communications-stack`
- `automation-stack`
- `dev-tools`
- `download-stack` and `streaming-stack` for config-state recovery

If a companion app-level unit exists, operators must assume supplement is required unless the inventory explicitly says the guest is `vm-covered`.

---

## Destructive Operation Rules

Any operation that can destroy, overwrite, or irreversibly scramble VM or guest state is break-glass work.

### Protected Hypervisor Actions

- `qm destroy` / `pct destroy`
- disk detach, delete, recreate, or backing-volume destruction
- `qmrestore` / `pct restore` over an existing VMID or CTID
- replacing a guest disk with a new blank disk
- deleting primary or offsite backup artifacts

### Protected Guest Actions

- `docker compose down` on a stateful guest stack
- volume deletion or state-root path changes inside a VM
- restore-overwrite actions against guest databases or object stores

### Break-Glass Contract

Before any protected action, operators must have:

- a linked loop or gap
- an identified restore point
- explicit approval for the destructive step
- a statement of why safer recovery or non-destructive inspection is not enough

Where governed wrappers exist, use them. Where they do not yet exist, the lack of automation does **not** waive the break-glass requirement.

### Decommission Rule

`vm.lifecycle.yaml` decommission policy wins:

- `requires_final_backup` means no destroy until a named final backup exists
- `requires_migration_first` means state migration and successor authority must exist before destroy
- `allow_immediate_destroy` still requires confirming the runtime is genuinely rebuildable

---

## Restore-Proof Rules

- Every active VM/LXC must have a restore class in `backup.inventory.yaml`.
- `tier1` and `vm-dry-run-quarterly` classes require current quarterly restore proof.
- `app-dry-run-monthly` and `media-config-dry-run-monthly` classes require current monthly proof for the app-level supplement, not just the VM artifact.
- A VM with a governed offsite exception must prove the compensating app-level restore lane within cadence.
- If restore proof is missing, the VM is `planned` or `exception-risk`, not `safe`.

---

## Safe vs Planned vs Exception

### Safe

A VM or LXC is safe only when:

- `vm.lifecycle.yaml` says it is active
- `backup.inventory.yaml` says `backup_admission_state: production_ready`
- primary backup targets are fresh
- required app-level targets are fresh
- offsite state is truthfully represented
- restore proof is current for the required class

### Planned

A VM or LXC is planned or incomplete when any of the following are true:

- admission is not production-ready
- primary backup exists only as intent
- restore proof is missing
- an operator says "covered" but the inventory does not prove it

### Exception

An exception is a deliberate deviation from the default path.

- It is valid only when the exception is explicit in the inventory or lifecycle docs.
- It is safe only when compensating controls and restore proof are current.
- A disabled offsite target with no compensating proof is exception drift, not a stable exception.

---

## Relationship Between `pve` and `proxmox-home`

- `pve` and `proxmox-home` are separate hypervisors with separate failure domains.
- `vm.lifecycle.yaml` is the shared inventory authority for both, but backup semantics are site-specific.
- Shop `pve` uses local hypervisor primary backup plus selective exact offsite to NAS.
- `proxmox-home` currently uses Synology as primary backup storage for home guests.
- Home Synology is not a substitute for true offsite DR.
- Never copy shop assumptions onto home or home assumptions onto shop without explicit inventory truth.

---

## Forbidden Anti-Patterns

1. Treating `vm.lifecycle.yaml` as backup policy
2. Treating `backup.inventory.yaml` as VM inventory
3. Calling a VM offsite-protected when only primary backup exists
4. Calling a home VM offsite-protected because its primary backup is on Synology
5. Treating a disabled offsite target as harmless drift
6. Using legacy workbench scripts as policy authority
7. Using raw `qm destroy` or disk recreation without a named restore point
8. Using `docker compose down` on stateful guest services without break-glass
9. Claiming VM image backup replaces app-level backup when companion app-level units exist
10. Describing media config backups as full payload protection

---

## Operator Checklist

See companion document: `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md`

---

## Status Line

- **Doctrine Version**: v1.0
- **Last Verified**: 2026-03-08
- **Parent Gap**: `GAP-OP-1512`
- **Canonical Shop Hypervisor**: `pve` (active VM range `200-299`)
- **Canonical Home Hypervisor**: `proxmox-home` (active VM/LXC range `100-199`)
- **Exact Shop Offsite Active**: VM 211 finance, VM 213 mint-apps
- **Exact Shop Offsite Exceptions**: VM 212 mint-data, VM 214 communications-stack
- **Home True Offsite DR**: deferred; Synology is current home primary backup surface, not cross-site DR

---

## Governance State

- **Canonical Home**: `docs/governance/PROXMOX_VM_SAFETY_DOCTRINE_V1.md`
- **Operator Workflow**: `docs/governance/PROXMOX_VM_OPERATOR_CHECKLIST.md`
- **Inventory Authority**: `ops/bindings/vm.lifecycle.yaml`
- **Backup Authority**: `ops/bindings/backup.inventory.yaml`
- **Context Authority**: `docs/governance/STACK_REGISTRY.yaml`, `docs/governance/SERVICE_REGISTRY.yaml`
- **Home Topology Context**: `docs/governance/MINILAB_SSOT.md`

**This doctrine is frozen as v1.0 on 2026-03-08. Future changes require explicit version increment and rationale.**
