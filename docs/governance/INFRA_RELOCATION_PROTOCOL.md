---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-06
scope: infra-relocation
---

# Infrastructure Relocation Protocol

> **Purpose:** Define the transactional workflow for VM provisioning and service migrations.
> All relocations must follow this protocol to ensure governance, parity, and rollback capability.

---

## Overview

Infrastructure relocations (VM moves, service migrations) are governed operations that require:
1. A canonical manifest (`ops/bindings/infra.relocation.plan.yaml`)
2. Cross-SSOT parity enforcement (D35 gate)
3. Receipts at each phase
4. Deterministic rollback capability

---

## Required Sequence

```
┌─────────────────────────────────────────────────────────────┐
│  1. PREFLIGHT                                                │
│     ops cap run infra.relocation.preflight                  │
│     → Host reachability + health baseline                    │
│     → Receipt required before proceeding                     │
├─────────────────────────────────────────────────────────────┤
│  2. MANIFEST PARITY PASS                                     │
│     ops cap run infra.relocation.parity                     │
│     → All SSOTs in sync with manifest                        │
│     → D35 gate must pass                                     │
├─────────────────────────────────────────────────────────────┤
│  3. CUTOVER PHASE RECEIPT                                    │
│     Execute migration per manifest phases                    │
│     → Update manifest state to "cutover"                     │
│     → Each service move produces receipt                     │
├─────────────────────────────────────────────────────────────┤
│  4. PARITY PASS (post-cutover)                              │
│     ops cap run infra.relocation.parity                     │
│     → Verify SSOTs updated for new locations                 │
│     → D35 gate must pass                                     │
├─────────────────────────────────────────────────────────────┤
│  5. CLEANUP PHASE RECEIPT                                    │
│     → Decommission old resources                             │
│     → Update manifest state to "complete"                    │
│     → Final parity verification                              │
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

---

## Capabilities

| Capability | Purpose | Safety |
|------------|---------|--------|
| `infra.relocation.preflight` | Host reachability + health baseline | read-only |
| `infra.relocation.parity` | Cross-SSOT consistency check | read-only |
| `infra.relocation.impact` | Delta matrix for required changes | read-only |
| `infra.relocation.rollback.plan` | Deterministic rollback checklist | read-only |

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
6. Run `ops cap run spine.verify` to confirm D35 passes
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
- [ ] `ops cap run infra.relocation.preflight` receipt captured
- [ ] `ops cap run infra.relocation.parity` passes
- [ ] Backups verified for services with `backup_target`
- [ ] Approval documented in `approved_by` field

### Post-Cutover
- [ ] All SSOTs updated for new service locations
- [ ] `ops cap run infra.relocation.parity` passes
- [ ] Health checks passing on new hosts
- [ ] `ops cap run spine.verify` passes (D34-D36 all green)

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
| [CORE_LOCK.md](../core/CORE_LOCK.md) | D35/D36 gate definitions |
| [HOST_DRIFT_POLICY.md](HOST_DRIFT_POLICY.md) | Exception policy |
