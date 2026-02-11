---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: backup-strategy
github_issue: "#622"
---

# Backup Governance

> **Purpose:** Governance rules for infrastructure-level backups. Defines what
> gets backed up, where backups are stored, and how backup health is verified.

---

## Backup Documentation Hierarchy

This document is the **strategy layer** -- it defines what gets backed up, where,
and how health is verified. Per-app documents are the **procedure layer** -- they
contain step-by-step backup and restore instructions for individual services. The
DR Runbook is the **recovery layer** -- it covers site-wide failure scenarios and
cross-service restoration order.

```
Strategy (this doc)
  ├── Site plans
  │   └── HOME_BACKUP_STRATEGY.md          (home site)
  ├── Per-app procedures (governance/)
  │   ├── AUTHENTIK_BACKUP_RESTORE.md       (infra-core, VM 204)
  │   ├── GITEA_BACKUP_RESTORE.md           (dev-tools, VM 206)
  │   ├── INFISICAL_BACKUP_RESTORE.md       (infra-core, VM 204)
  │   └── VAULTWARDEN_BACKUP_RESTORE.md     (infra-core, VM 204)
  ├── Per-app procedures (brain/lessons/)
  │   ├── IMMICH_BACKUP_RESTORE.md          (immich-1, VM 203)
  │   └── FINANCE_BACKUP_RESTORE.md         (docker-host, VM 200)
  ├── Operational tooling
  │   └── BACKUP_CALENDAR.md                (schedule visibility)
  └── Recovery
      └── DR_RUNBOOK.md                     (site-wide disaster recovery)
```

| Document | Layer | Scope | Location |
|----------|-------|-------|----------|
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) (this file) | Strategy | Cross-site backup policy, storage targets, retention, verification | `docs/governance/` |
| [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md) | Strategy | Home site (proxmox-home + Synology NAS) backup plan | `docs/governance/` |
| [AUTHENTIK_BACKUP_RESTORE.md](AUTHENTIK_BACKUP_RESTORE.md) | Procedure | App-level backup/restore for Authentik (VM 204) | `docs/governance/` |
| [GITEA_BACKUP_RESTORE.md](GITEA_BACKUP_RESTORE.md) | Procedure | App-level backup/restore for Gitea (VM 206) | `docs/governance/` |
| [INFISICAL_BACKUP_RESTORE.md](INFISICAL_BACKUP_RESTORE.md) | Procedure | App-level backup/restore for Infisical (VM 204) | `docs/governance/` |
| [VAULTWARDEN_BACKUP_RESTORE.md](VAULTWARDEN_BACKUP_RESTORE.md) | Procedure | App-level backup/restore for Vaultwarden (VM 204) | `docs/governance/` |
| [IMMICH_BACKUP_RESTORE.md](../brain/lessons/IMMICH_BACKUP_RESTORE.md) | Procedure | App-level backup/restore for Immich (VM 203) | `docs/brain/lessons/` |
| [FINANCE_BACKUP_RESTORE.md](../brain/lessons/FINANCE_BACKUP_RESTORE.md) | Procedure | App-level backup/restore for Finance stack (VM 200) | `docs/brain/lessons/` |
| [BACKUP_CALENDAR.md](BACKUP_CALENDAR.md) | Tooling | Subscribable .ics calendar for backup schedule visibility | `docs/governance/` |
| [DR_RUNBOOK.md](DR_RUNBOOK.md) | Recovery | Site-wide failure scenarios, dependency map, recovery priority | `docs/governance/` |

---

## Backup Strategy

### Shop Site (pve R730XD)

| Tier | Scope | Method | Target |
|------|-------|--------|--------|
| VM/CT | Proxmox VMs and containers | vzdump | tank-backups (ZFS) |
| Config | Compose files, env templates | Git | agentic-spine repo |
| Data | Application databases | App-level dumps | Per-stack procedures (see below) |

### Home Site (proxmox-home Beelink)

| Tier | Scope | Method | Target |
|------|-------|--------|--------|
| VM/CT | Proxmox VMs and containers | vzdump | synology-backups (NAS NFS) |
| Data | Home Assistant | HA built-in backup | NAS `/volume1/backups/homeassistant_backups/` |

See: [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md) for full home backup plan.

## App-Level Procedures (Required)

VM-level backups are not enough for critical stateful services. The following
procedures are the minimum app-level backup/restore contract:

- [Authentik Backup + Restore (App-Level)](AUTHENTIK_BACKUP_RESTORE.md)
- [Gitea Backup + Restore (App-Level)](GITEA_BACKUP_RESTORE.md)

---

## Verification

The spine provides two backup verification paths:

### 1. Backup Status (Capability)

```bash
# Read-only inventory check (freshness + reason codes)
./bin/ops cap run backup.status
```

### 2. Backup Verify (Surface Script)

```bash
# Verify backup inventory against live state
surfaces/verify/backup_verify.sh
```

### 3. Backup Audit (Data Generator)

```bash
# Generate JSON backup inventory (writes backup_inventory.json)
surfaces/verify/backup_audit.sh
```

---

## Backup Calendar

Generate an iPhone-subscribeable `.ics` calendar from SSOT/bindings:

```bash
./bin/ops cap run backup.calendar.generate
```

See: [Backup Calendar (.ics)](BACKUP_CALENDAR.md)

---

## Freshness Rules

| Threshold | Status |
|-----------|--------|
| < 24 hours | OK |
| 24-48 hours | WARNING |
| > 48 hours | CRITICAL |

---

## Storage Targets

| Site | Target | Path | Type |
|------|--------|------|------|
| Shop | tank-backups | `/tank/backups/vzdump/dump` | ZFS on pve |
| Home | synology-backups | `/mnt/pve/synology-backups/dump` | NAS NFS on proxmox-home |

## Retention

### Shop (pve)

Retention is enforced at the **storage layer** on `pve`, not only via `maxfiles`
on the job. Canonical setting:

- `pve:/etc/pve/storage.cfg` `dir: tank-backups` includes:
  - `prune-backups keep-last=2`

### Home (proxmox-home)

Retention is enforced at the **storage layer** on proxmox-home:

- `proxmox-home:/etc/pve/storage.cfg` `nfs: synology-backups` includes:
  - `prune-backups keep-last=3`
- Job-level overrides: P0/P1 `keep-last=3`, P2 `keep-last=2`

If pruning ever falls behind (e.g. backlog from before retention was enabled),
run a receipt-backed prune:

```bash
./bin/ops cap run backup.vzdump.prune
# Dry-run by default; use --execute to delete.
./bin/ops cap run backup.vzdump.prune -- --execute
```

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md) | Home site backup strategy |
| [STACK_REGISTRY.yaml](STACK_REGISTRY.yaml) | Stack inventory |
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Device identity |
