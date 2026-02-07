---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-07
scope: infra-relocation
---

# Infrastructure Relocation Protocol

> **Purpose:** Define the transactional workflow for VM provisioning and service migrations.
> All relocations must follow this protocol to ensure governance, parity, and rollback capability.

---

## Overview

Infrastructure relocations (VM moves, service migrations) are governed operations that require:
1. A canonical manifest (`ops/bindings/infra.relocation.plan.yaml`)
2. Canonical placement policy (`ops/bindings/infra.placement.policy.yaml`)
3. Hypervisor identity integrity (`infra.hypervisor.identity`)
4. Cross-SSOT parity enforcement (D35) + placement enforcement (D37)
5. Receipts at each phase
6. Deterministic rollback capability
7. Controlled state transitions through capability execution (`ops cap run`)

---

## Required Sequence

```
┌─────────────────────────────────────────────────────────────┐
│  1. IMPACT + PREFLIGHT                                       │
│     ops cap run infra.placement.policy                       │
│     ops cap run infra.hypervisor.identity                    │
│     ops cap run infra.relocation.impact                      │
│     ops cap run infra.relocation.preflight                   │
│     → Placement lock + host reachability + identity evidence │
├─────────────────────────────────────────────────────────────┤
│  2. PRE-EXEC PARITY                                           │
│     ops cap run infra.relocation.parity                      │
│     → D35 + D37 must pass before any relocation mutation     │
├─────────────────────────────────────────────────────────────┤
│  3. VM PROVISION (dry-run then execute)                      │
│     ops cap run infra.vm.provision --target ... --dry-run    │
│     ops cap run infra.vm.provision --target ... --execute    │
├─────────────────────────────────────────────────────────────┤
│  4. VM BOOTSTRAP + READY STATUS                              │
│     ops cap run infra.vm.bootstrap --target ... --execute    │
│     ops cap run infra.vm.ready.status --target ...           │
├─────────────────────────────────────────────────────────────┤
│  5. STATE TRANSITION                                          │
│     ops cap run infra.relocation.state.transition ...        │
│     → e.g. planning -> preflight + vm target status updates  │
├─────────────────────────────────────────────────────────────┤
│  6. CUTOVER/CLEANUP PHASES                                    │
│     Execute migration per manifest phases                     │
│     → Post-change parity checks required each phase           │
└─────────────────────────────────────────────────────────────┘
```

---

## Manifest Schema

Location: `ops/bindings/infra.relocation.plan.yaml`

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `active_relocation.change_id` | string | Unique identifier (links to open loop) |
| `active_relocation.state` | enum | `planning` \| `preflight` \| `cutover` \| `cleanup` \| `complete` |
| `active_relocation.owner` | string | Responsible party |
| `active_relocation.approved_by` | string | Approval authority (required for cutover) |
| `vm_targets[]` | array | VMs to provision |
| `services[]` | array | Services to relocate |
| `required_updates[]` | array | SSOT files that must be updated |

### Service Entry Schema

```yaml
services:
  - service: "service-name"
    from_host: "source-host"      # or null for new deployments
    to_host: "target-host"
    phase: 1                       # Migration phase number
    health_url: "http://..."       # Health check endpoint
    rollback_to: "fallback-host"   # Rollback target
    backup_target: "path/to/backup"
    status: "planned"              # planned | cutover | migrated | complete
```

---

## Parity Requirements (D35)

For each service in manifest with `status != planned`, the following must agree:

| SSOT File | Required Parity |
|-----------|-----------------|
| `SERVICE_REGISTRY.yaml` | Service host matches `to_host` |
| `STACK_REGISTRY.yaml` | Compose file location updated |
| `DEVICE_IDENTITY_SSOT.md` | New VMs documented with IPs |
| `services.health.yaml` | Health endpoints point to new host |
| `ssh.targets.yaml` | SSH access configured for new host |
| `backup.inventory.yaml` | Backup paths updated |
| `infra.placement.policy.yaml` | Service + target sites comply with canonical location policy |

### D35 Gate Contract (Strict)

When relocation state is `preflight`, `cutover`, or `cleanup`, D35 fails if any non-`planned` service has:

1. No entry in `SERVICE_REGISTRY.yaml`
2. A host value that does not match manifest `to_host`
3. A `to_host` that is missing from `ops/bindings/ssh.targets.yaml`

### D37 Gate Contract (Strict)

D37 fails when any of the following is true:

1. `vm_targets` place a VM on a non-canonical Proxmox host/site
2. VMID is outside the allowed range for that site
3. Any service `to_host` violates primary site policy
4. Any rollback target violates DR site policy

---

## Capabilities

| Capability | Purpose | Safety |
|------------|---------|--------|
| `infra.relocation.preflight` | Host reachability + health baseline | read-only |
| `infra.placement.policy` | Canonical placement policy validation (site/hypervisor/vmid/service target) | read-only |
| `infra.hypervisor.identity` | Hypervisor ID/hostname/machine-id uniqueness check | read-only |
| `infra.hypervisor.hostname.set` | Set canonical hostname for a Proxmox host-id (dry-run/execute) | mutating (manual) |
| `infra.relocation.parity` | Cross-SSOT consistency + placement policy check | read-only |
| `infra.relocation.impact` | Delta matrix for required changes | read-only |
| `infra.relocation.rollback.plan` | Deterministic rollback checklist | read-only |
| `infra.vm.provision` | Provision Proxmox VM from profile | mutating (manual) |
| `infra.vm.bootstrap` | Bootstrap VM to spine-ready baseline | mutating (manual) |
| `infra.relocation.state.transition` | Controlled manifest state + vm target updates | mutating (manual) |
| `infra.relocation.service.transition` | Controlled service status transition in relocation manifest | mutating (manual) |
| `infra.relocation.promote` | Gate-checked service promotion (`cutover -> migrated`) | mutating (manual) |
| `infra.vm.ready.status` | Read-only readiness report (running/ssh/tailscale/profile checks) | read-only |

---

## Rollback Requirements

1. **Maximum Rollback Window:** Defined in manifest (`rollback.max_rollback_window_hours`)
2. **Backup Verification:** Required before cutover if `rollback.requires_backup_verification: true`
3. **Health Baseline:** Required before cutover if `rollback.requires_health_baseline: true`

### Rollback Procedure

1. Stop service on new host
2. Restore data from backup (if applicable)
3. Start service on rollback target
4. Update DNS/routing
5. Revert all SSOTs to previous state
6. Run `ops cap run spine.verify` to confirm D35 + D37 pass
7. Document incident

---

## Exception Handling

Temporary exceptions during migration are declared in manifest:

```yaml
exceptions:
  - label: "split-dns-during-migration"
    reason: "DNS may resolve to old host during cutover"
    expires_at: "2026-02-15T23:59:59Z"
```

D36 enforces exception hygiene (no stale/expired exceptions).

---

## Checklist

### Pre-Cutover
- [ ] Manifest complete with all services and phases
- [ ] `ops cap run infra.relocation.impact` reviewed
- [ ] `ops cap run infra.placement.policy` passes
- [ ] `ops cap run infra.hypervisor.identity` passes
- [ ] `ops cap run infra.relocation.preflight` receipt captured
- [ ] `ops cap run infra.relocation.parity` passes
- [ ] VM provisioned via `ops cap run infra.vm.provision --execute`
- [ ] VM bootstrapped via `ops cap run infra.vm.bootstrap --execute`
- [ ] VM readiness passes via `ops cap run infra.vm.ready.status --target <vm>`
- [ ] State transitioned via `ops cap run infra.relocation.state.transition --state preflight --execute`
- [ ] Backups verified for services with `backup_target`
- [ ] Approval documented in `approved_by` field

### Post-Cutover
- [ ] All SSOTs updated for new service locations
- [ ] `ops cap run infra.hypervisor.identity` passes
- [ ] `ops cap run infra.relocation.parity` passes
- [ ] Health checks passing on new hosts
- [ ] `ops cap run spine.verify` passes (D34-D37 all green)

### Post-Cleanup
- [ ] Old resources decommissioned
- [ ] Manifest state set to `complete`
- [ ] Open loop closed with evidence

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [SERVICE_REGISTRY.yaml](SERVICE_REGISTRY.yaml) | Service-to-host mapping SSOT |
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Host naming and IP SSOT |
| [CORE_LOCK.md](../core/CORE_LOCK.md) | D35-D37 gate definitions |
| [HOST_DRIFT_POLICY.md](HOST_DRIFT_POLICY.md) | Exception policy |
