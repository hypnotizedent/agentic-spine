---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: vm-lifecycle-governance
---

# VM Creation Contract

> **Purpose:** Define the canonical phases, required artifacts, and SSOT touchpoints for creating,
> operating, and decommissioning a Proxmox VM under spine governance.
>
> **Authority boundary:**
> - This contract defines the *process*. Hardware/topology facts live in SHOP_SERVER_SSOT.md.
> - Service placement rules live in `ops/bindings/infra.placement.policy.yaml`.
> - Storage tier placement lives in `ops/bindings/infra.storage.placement.policy.yaml`.
> - Per-VM state lives in `ops/bindings/vm.lifecycle.yaml` (the lifecycle binding).
> - Relocation-specific workflow lives in INFRA_RELOCATION_PROTOCOL.md.

---

## Lifecycle Phases

Every spine-governed VM transitions through exactly these phases in order.
Skipping a phase requires an explicit exception registered in the lifecycle binding.

```
PLAN ──▶ PROVISION ──▶ REGISTER ──▶ VALIDATE ──▶ OPERATE ──▶ DECOMMISSION
                                                     ▲            │
                                                     └────────────┘
                                                    (rollback/rebuild)
```

---

## Phase 1: PLAN

**Goal:** Declare intent, assign VMID, define resource envelope, identify SSOT impacts.

### Required Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Loop scope file | `mailroom/state/loop-scopes/LOOP-<NAME>-<DATE>.scope.md` | Why this VM exists, what it hosts, success criteria |
| VMID reservation | `ops/bindings/vm.lifecycle.yaml` | Entry with `status: planning`, assigned VMID |
| Profile selection | `ops/bindings/infra.vm.profiles.yaml` | Which bootstrap profile applies (e.g. `spine-ready-v1`) |

### Required Decisions

- **VMID:** Next available in the site's range (shop: 200-299, home: 100-199)
- **Hostname:** Must match `naming.policy.yaml` conventions (lowercase, hyphenated role name)
- **LAN IP:** Static assignment per SHOP_NETWORK_NORMALIZATION.md (DHCP only for template clones pre-Tailscale)
- **Resource envelope:** CPU cores, RAM, boot disk — from profile or explicitly overridden
- **Role:** Primary workload description (e.g. `finance-stack`, `observability`)
- **Stacks/services:** What compose stacks and services will run on this VM
- **Storage tier:** Consult `infra.storage.placement.policy.yaml` — does this VM need a dedicated data disk (ZFS zvol), NFS mount, or boot-only?

### SSOT Impact Preview

The following files WILL need updates by the end of REGISTER phase:

| File | Update Required |
|------|----------------|
| `ops/bindings/vm.lifecycle.yaml` | New entry (this phase) |
| `docs/governance/SHOP_SERVER_SSOT.md` | VM inventory table row |
| `docs/governance/DEVICE_IDENTITY_SSOT.md` | Device entry with IPs |
| `docs/governance/SERVICE_REGISTRY.yaml` | Service entries for hosted services |
| `docs/governance/STACK_REGISTRY.yaml` | Stack entry |
| `ops/bindings/ssh.targets.yaml` | SSH target entry |
| `ops/bindings/docker.compose.targets.yaml` | Compose target entry |
| `ops/bindings/services.health.yaml` | Health probe endpoints |
| `ops/bindings/backup.inventory.yaml` | Backup target entry |
| `ops/bindings/infra.storage.placement.policy.yaml` | Storage tier declaration for this VM |
| `ops/bindings/secrets.namespace.policy.yaml` | Secret paths (if services need secrets) |

---

## Phase 2: PROVISION

**Goal:** Create the VM on the hypervisor with the correct resource profile.

### Required Steps

1. **Clone from template:**
   ```
   qm clone 9000 <VMID> --name <hostname> --full --storage <storage>
   ```
2. **Apply resource profile:**
   ```
   qm set <VMID> --cores <N> --memory <MB> --balloon 0
   ```
3. **Configure cloud-init:**
   - Static IP (preferred) or DHCP
   - SSH public key injection (MUST happen before first boot)
   - DNS nameserver
4. **Provision storage tier** (per `infra.storage.placement.policy.yaml`):
   - **boot-only:** No action (stateless workloads, SQLite on `/opt/appdata`)
   - **tank-vms:** Create ZFS zvol, attach as virtio disk:
     ```
     zfs create -V <SIZE> tank/vms/vm-<VMID>-data
     qm set <VMID> --virtio1 tank/vms/vm-<VMID>-data
     ```
   - **tank-docker / nfs-media:** Configure NFS mount in cloud-init or post-boot:
     ```
     echo "<NFS_SOURCE> <MOUNT_PATH> nfs defaults 0 0" >> /etc/fstab
     ```
   - Update Docker data-root if data disk is mounted (e.g., `/mnt/docker`)
5. **Set boot policy:**
   ```
   qm set <VMID> --onboot 1
   ```
6. **Start VM and wait for cloud-init:**
   ```
   qm start <VMID>
   qm guest exec <VMID> -- cloud-init status --wait
   ```

### Required Artifacts

| Artifact | Description |
|----------|-------------|
| Provision receipt | `ops cap run infra.vm.provision` output confirming VMID, resources, IP |
| Cloud-init evidence | `cloud-init status --wait` output showing completion |

### Rollback

```
qm stop <VMID> && qm destroy <VMID> --purge
```

Update `vm.lifecycle.yaml` status back to `planning` or `abandoned`.

---

## Phase 3: REGISTER

**Goal:** Make the VM visible to spine tooling by updating all required SSOTs and bindings.

### Required SSOT Updates

Each update MUST be committed. The order below minimizes drift window:

| # | File | What to Add | Commit Scope |
|---|------|-------------|--------------|
| 1 | `ops/bindings/vm.lifecycle.yaml` | Update status to `registered`, add Tailscale IP | lifecycle |
| 2 | `ops/bindings/ssh.targets.yaml` | SSH target entry (id, host, user, tags) | connectivity |
| 3 | `ops/bindings/docker.compose.targets.yaml` | Compose target with stack paths | stack discovery |
| 4 | `docs/governance/DEVICE_IDENTITY_SSOT.md` | Device row (hostname, LAN IP, TS IP, VMID) | identity |
| 5 | `docs/governance/SHOP_SERVER_SSOT.md` | VM inventory table row | hardware SSOT |
| 6 | `docs/governance/SERVICE_REGISTRY.yaml` | Service entries (host, port, health, container) | service truth |
| 7 | `docs/governance/STACK_REGISTRY.yaml` | Stack entry (stack_id, path, deploy_method) | stack truth |
| 8 | `ops/bindings/services.health.yaml` | Health probe endpoints for each service | monitoring |
| 9 | `ops/bindings/backup.inventory.yaml` | Backup target entry for vzdump artifacts | backup coverage |
| 10 | `ops/bindings/secrets.namespace.policy.yaml` | Secret key paths (if services need Infisical) | secrets |

### Validation Gate

After all updates:
```
./bin/ops cap run spine.verify
```
All drift gates (D34, D35, D37, D54, D59) must pass. If they don't, the registration is incomplete.

---

## Phase 4: VALIDATE

**Goal:** Prove the VM is operational and all spine tooling can reach it.

### Required Checks

| Check | Command | Expected |
|-------|---------|----------|
| SSH reachable | `ssh <target> hostname` | Returns correct hostname |
| Tailscale connected | `ssh <target> tailscale status --self` | Shows connected |
| Docker running | `ssh <target> docker ps` | Lists expected containers |
| QEMU agent | `qm agent <VMID> ping` | Returns `{"return":{}}` |
| Health probes | `./bin/ops cap run services.health.status` | All new endpoints OK |
| Compose status | `./bin/ops cap run docker.compose.status` | New stack shows ok |
| Backup binding | `./bin/ops cap run backup.status` | New target present |
| Full verify | `./bin/ops cap run spine.verify` | ALL PASS |

### Required Artifacts

| Artifact | Description |
|----------|-------------|
| Validation receipt | `spine.verify` receipt showing all gates pass |
| Health status output | `services.health.status` receipt |
| Compose status output | `docker.compose.status` receipt |

### Transition

Update `vm.lifecycle.yaml` status to `active`.

---

## Phase 5: OPERATE

**Goal:** Steady-state operation under spine governance.

### Ongoing Requirements

| Requirement | Enforcement |
|-------------|------------|
| Health probes passing | `services.health.status` (continuous via Uptime Kuma + on-demand) |
| Backup freshness | `backup.status` capability + D58 SSOT freshness gate |
| Compose parity | `docker.compose.status` capability |
| SSH reachable | `ssh.targets.yaml` binding + connectivity checks |
| Drift gates green | `spine.verify` (all gates) |
| SSOT freshness | `last_reviewed` dates within D58 threshold (14 days) |

### Change Management During Operate

- **Adding services:** Follow REGISTER phase updates (SERVICE_REGISTRY, health binding, etc.)
- **Removing services:** Update all SSOTs, disable health probes, run `spine.verify`
- **Resizing VM:** Update `vm.lifecycle.yaml` resources + SHOP_SERVER_SSOT VM inventory
- **Relocating services:** Follow INFRA_RELOCATION_PROTOCOL.md

---

## Phase 6: DECOMMISSION

**Goal:** Safely remove a VM with evidence that no dependencies remain.

### Pre-Decommission Checklist

- [ ] All services migrated or confirmed unnecessary
- [ ] No other VMs/services depend on this VM (check `deploy.dependencies.yaml`)
- [ ] Final backup captured and verified
- [ ] `./bin/ops cap run spine.ripple.check <hostname>` shows zero live references
- [ ] Loop scope exists documenting decommission rationale

### Required Steps

| # | Step | Command/Action |
|---|------|---------------|
| 1 | Stop all containers | `ssh <target> 'cd <stack-path> && docker compose down'` |
| 2 | Stop VM | `qm stop <VMID>` |
| 3 | Capture final snapshot | `vzdump <VMID> --storage <backup-storage>` (optional, per policy) |
| 4 | Destroy VM | `qm destroy <VMID> --purge` |
| 5 | Clean ZFS dataset | `zfs destroy <dataset>` (if dedicated dataset exists) |
| 6 | Remove from all SSOTs | Reverse of REGISTER phase — all 10 files |
| 7 | Update lifecycle binding | Set `status: decommissioned`, add `decommissioned_at` |
| 8 | Run spine.verify | Confirm all gates pass without the VM |
| 9 | Close loop | `./bin/ops close loop <LOOP_ID>` |

### Decommission Policies

Defined per-VM in `vm.lifecycle.yaml`:

| Policy | Meaning |
|--------|---------|
| `requires_migration_first` | All services must be relocated before VM destruction |
| `requires_final_backup` | A vzdump must be captured before destruction |
| `allow_immediate_destroy` | VM can be destroyed without migration (e.g. empty or test VMs) |

### Evidence Requirements

| Evidence | Location |
|----------|----------|
| Decommission receipt | `receipts/sessions/` from spine.verify |
| Migration receipts | Referenced from loop scope (if services were migrated) |
| Backup artifact | vzdump file on backup storage (if required by policy) |
| Ripple check output | Zero live references to decommissioned hostname |

---

## Rollback Rules

### General Principle

Every phase is reversible until the next phase begins. Once a phase is completed and the next started, rollback must go through the full reverse sequence.

### Phase-Specific Rollback

| Phase | Rollback Action |
|-------|----------------|
| PLAN | Delete lifecycle entry, close loop as abandoned |
| PROVISION | `qm destroy <VMID> --purge`, revert lifecycle to planning/abandoned |
| REGISTER | Revert all SSOT commits, set lifecycle status to `provisioned` |
| VALIDATE | If validation fails, either fix and retry or rollback to REGISTER |
| OPERATE | N/A (steady state — changes follow their own protocols) |
| DECOMMISSION | Cannot be rolled back after `qm destroy`. Final backup is the safety net. |

### Rollback Evidence

Every rollback must produce:
1. A commit reverting SSOT changes
2. An updated lifecycle binding entry showing the rollback
3. A note in the loop scope explaining why rollback occurred

---

## Cross-Reference

| Document | Relationship |
|----------|-------------|
| `ops/bindings/vm.lifecycle.yaml` | Per-VM state tracking (lifecycle binding) |
| `ops/bindings/infra.vm.profiles.yaml` | Reusable bootstrap profiles |
| `ops/bindings/infra.placement.policy.yaml` | Where VMs are allowed to be placed |
| `ops/bindings/infra.storage.placement.policy.yaml` | What storage tier each VM should use |
| `docs/governance/INFRA_RELOCATION_PROTOCOL.md` | Protocol for moving services between VMs |
| `docs/governance/SHOP_SERVER_SSOT.md` | Hardware-level VM inventory |
| `docs/governance/SERVICE_REGISTRY.yaml` | Service-to-host mapping |
| `docs/core/STACK_LIFECYCLE.md` | Stack-level operations within a VM |
