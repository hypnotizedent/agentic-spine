---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-19
scope: machine-storage-architecture-standard
---

# Machine-Storage Architecture Standard

Purpose: make every machine and storage plane boring to reason about. A machine should tell the operator what kind of work lives there. A storage plane should tell the operator what kind of data lives there. Together, they answer: where does this service belong, and where does its backup land?

## The Five Planes

Every estate has exactly five planes. Every machine maps to one primary plane.

| Plane | Purpose | Example |
|-------|---------|---------|
| Operator Control | Human workspace: code, governance, agent orchestration | MacBook / workstation |
| Primary Compute | VM runtime: all active services run here | 730XD / rack server |
| Attached Bulk Storage | Cold backup, archive, staging, tombstones | MD1400 DAS / cold NAS |
| Home Personal-Data | Personal data, home backups, separate trust domain | Synology + home hypervisor |
| Edge/IoT | Coordinators, sensors, gateways — no durable state | Zigbee, Thread, Z-Wave, UniFi |

## Storage Temperature Classes

| Class | Meaning | Access Pattern | Retention |
|-------|---------|---------------|-----------|
| **hot** | Active runtime: VM boot disks, live app state | Read/write continuously | As long as service is active |
| **warm** | Active payload: media libraries, photo originals | Read frequently, write occasionally | Long-term but lifecycle-managed |
| **cold** | Backup authority and archive: recovery copies, aged content | Read on restore/audit only | Policy-based (30+ days) |
| **staging** | Ephemeral intake: downloads, imports, reconciliation | Write on intake, drain within days | Hard cap + drain deadline (7 days) |
| **boot** | Hypervisor/host metadata: not application state | Host-level only | Tied to host lifecycle |
| **control-plane** | Governance repos, operator tools, SSH keys | Operator access | Tied to operator |

## Service Placement Decision Tree

```
New service → which site?
├── Shop/business → compute on primary compute plane (pve)
│   ├── Boot disk on tank (hot)
│   ├── >10GB durable state? → externalize to /tank/<service> dataset
│   ├── >1TB payload? → consider dedicated pool placement
│   └── Backup: daily VM + app-state dumps → cold plane (md1400)
├── Home/personal → compute on home compute plane
│   ├── Boot disk on local-lvm (hot)
│   ├── >1GB durable state? → externalize to NAS path
│   └── Backup: daily vzdump → NAS
└── Operator/dev → lives on operator machine, governed by spine
```

## Backup Class Model

| Class | Examples | What | Where | Retention | Restore Proof |
|-------|----------|------|-------|-----------|---------------|
| Tier-1 Critical | Mint, Finance, Infra-core, Immich originals | Full VM + app-state dumps | Cold plane (md1400 or NAS) | 30+ days | Mandatory drill |
| Tier-2 Important | HA, Gitea, Observability, Communications | VM backup + config exports | Cold plane | 14-30 days | Documented procedure |
| Tier-3 Regenerable | Media, AI, Downloads | Config only; payload re-downloadable | Cold plane (config only) | 14 days | Not required |
| Operational | Backup generator lane | Short-retention freshness copies | Hot plane (tank) | 7-14 days | N/A |
| Retired | Tombstoned services | One cold capsule with expiry | Cold plane | Until expiry date | N/A |

## Anti-Patterns (Rejected by Verify)

1. **Critical state on boot drive** — externalize to declared data plane
2. **Competing canonical roots** — one root per data class, others are backup or tombstone
3. **Archives mixed with runtime** — separate path classes, separate directories
4. **Staging becoming permanent** — hard caps + drain deadlines + alerts
5. **Duplicate backup lanes** — max 3 per service (generator + cold + offsite)
6. **Ghost/empty shares** — populate within 30 days or delete
7. **Home directories as service roots** — use /opt/stacks/ and /srv/data/
8. **Mixed path classes** — each root serves exactly one class
9. **Undocumented bind mounts** — declare source, class, consumer, backup story
10. **Legacy without expiry** — tombstones must have review/expiry dates

## Authority Surfaces

| Concern | Authority File |
|---------|---------------|
| Machine identity | `ops/bindings/hardware.inventory.yaml`, `ops/bindings/home.hardware.inventory.yaml` |
| Storage planes | `ops/bindings/shop.storage.map.yaml`, `ops/bindings/home.storage.map.yaml` |
| Backup authority | `ops/bindings/backup.inventory.yaml` |
| Path classes | `docs/governance/MACHINE_FILESYSTEM_CONTRACT.md` |
| Media tiers | `docs/governance/MEDIA_STORAGE_CONTRACT.md` |
| Machine roles | This document |

## Verification

```bash
# Estate boringness build (storage authority rebuild)
./bin/ops cap run infra.estate.boringness.build

# Core verify sweep
./bin/ops cap run verify.run -- fast
```
