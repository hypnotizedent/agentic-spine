---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: backup-recovery-objectives
---

# Recovery Time / Recovery Point Objectives

Purpose: define per-service RTO (how long until restored) and RPO (how much data loss
is acceptable) based on current backup mechanisms and infrastructure.

Reference: `backup.inventory.yaml` for freshness thresholds, `infra.placement.policy.yaml`
for placement, `SERVICE_REGISTRY.yaml` for service inventory.

## Definitions

- **RTO** (Recovery Time Objective): Maximum acceptable time from failure to service restoration.
- **RPO** (Recovery Point Objective): Maximum acceptable data loss measured in time (e.g., 24h RPO = may lose up to 24h of data).
- **Backup Mechanism**: How the service is backed up today.
- **Classification**: From `backup.inventory.yaml` — critical (26h), important (48h), rebuildable (168h).

## Service Recovery Objectives

### Tier 1: Critical Infrastructure (restore first)

| Service | Host | RTO | RPO | Backup Mechanism | Notes |
|---------|------|-----|-----|------------------|-------|
| cloudflared | infra-core | 1h | 0 | vzdump (daily) + config in compose | Stateless — redeploy from compose. Config is CF-side. |
| pihole | infra-core | 1h | 24h | vzdump (daily) | DNS lists/config in container volume. Rebuild from scratch is fast. |
| infisical | infra-core | 2h | 24h | vzdump (daily) + pg_dump (daily 02:50) + NAS rsync | DB is the critical artifact. Restore per INFISICAL_BACKUP_RESTORE.md. |
| vaultwarden | infra-core | 2h | 24h | vzdump (daily) + tar.gz (daily) + NAS rsync | Restore per compose + data dir from backup. |
| authentik | infra-core | 2h | 24h | vzdump (daily) + pg_dump available | Restore per AUTHENTIK_BACKUP_RESTORE.md. |
| caddy | infra-core | 30m | 0 | vzdump (daily) + Caddyfile in compose | Stateless config — redeploy from compose. |

### Tier 2: Observability + Dev (restore second)

| Service | Host | RTO | RPO | Backup Mechanism | Notes |
|---------|------|-----|-----|------------------|-------|
| prometheus | observability | 4h | 24h | vzdump (daily) | Metrics data loss acceptable — historical data is nice-to-have. |
| grafana | observability | 4h | 24h | vzdump (daily) | Dashboard configs in container volumes. Can rebuild dashboards. |
| loki | observability | 4h | 24h | vzdump (daily) | Log data loss acceptable. |
| uptime-kuma | observability | 4h | 24h | vzdump (daily) | Monitor configs in SQLite. |
| gitea | dev-tools | 4h | 24h | vzdump (daily) + gitea dump + pg_dump | Repos also mirrored to GitHub. Restore per GITEA_BACKUP_RESTORE.md. |

### Tier 3: Media (restore third)

| Service | Host | RTO | RPO | Backup Mechanism | Notes |
|---------|------|-----|-----|------------------|-------|
| radarr | download-stack | 8h | 24h | vzdump (daily) | Config DBs on local ext4 (symlinked from NFS). |
| sonarr | download-stack | 8h | 24h | vzdump (daily) | Same as radarr. |
| jellyfin | streaming-stack | 8h | 24h | vzdump (daily) | Media files on NFS (separate from VM). Library metadata in VM. |
| navidrome | streaming-stack | 8h | 24h | vzdump (daily) | Music DB in container volume. |

### Tier 4: Auxiliary (restore last)

| Service | Host | RTO | RPO | Backup Mechanism | Notes |
|---------|------|-----|-----|------------------|-------|
| n8n | automation-stack | 12h | 24h | vzdump (daily) | Workflow definitions in postgres. |
| ollama | automation-stack | 12h | 0 | vzdump (daily) | Models can be re-pulled. No unique data. |
| open-webui | automation-stack | 12h | 24h | vzdump (daily) | Chat history is nice-to-have. |
| qdrant | ai-consolidation | 12h | 24h | vzdump (daily) | Vector DB can be rebuilt from source docs. |
| anythingllm | ai-consolidation | 12h | 24h | vzdump (daily) | Config + workspace data. |
| mint-os-api | docker-host | 24h | 24h | vzdump (daily) | Legacy app. |
| minio | docker-host | 24h | 24h | vzdump (daily) | Object storage for mint-os. |
| immich | immich-1 | 24h | 24h | vzdump (daily) | Photo library — original files on NFS. |

### Non-VM Services

| Service | Host | RTO | RPO | Backup Mechanism | Notes |
|---------|------|-----|-----|------------------|-------|
| home-assistant | proxmox-home | 4h | 48h | tar backup to NAS (when reachable) | Automation configs + history DB. |
| NAS (Synology) | home site | 8h | N/A | **No offsite backup** (BAK-03) | SPOF for offsite copies. Hardware replacement required. |

## Current Gaps vs Objectives

| Gap | Impact on RTO/RPO |
|-----|-------------------|
| No offline bootstrap creds (BAK-05) | If infra-core + MacBook both lost, RTO for Infisical = **undefined** (no way to recover secrets) |
| NAS has no offsite (BAK-03) | If NAS destroyed, offsite copies of all app-level backups are gone. RPO for app-level = **undefined** |
| VM 200 no offsite (186GB) | If shop site destroyed, docker-host has no offsite copy. RPO = last vzdump before event |
| proxmox-home vzdump not scheduled | Home VMs (HA, immich-home) may have stale or no backups |

## Review Cadence

Review this document quarterly or after any major infrastructure change (site addition,
service migration, backup mechanism change).
