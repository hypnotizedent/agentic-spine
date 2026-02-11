---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: immich-backup-restore
migrated_from: ronny-ops/immich/BACKUP.md
parent_loop: LOOP-IMMICH-LEGACY-EXTRACTION-20260211
---

# Immich Backup & Restore

> **Service:** Immich (VM 203, immich-1)
> **Containers:** immich_server, immich_machine_learning, immich_postgres, immich_redis
> **Library size:** ~3TB (135K+ assets across 4 users)

---

## What Gets Backed Up

| Data | Location | Size | Method | Schedule | Destination |
|------|----------|------|--------|----------|-------------|
| PostgreSQL | Docker container `immich_postgres` | ~1GB | `pg_dumpall` via script | Daily 03:00 | Local staging, then Synology offsite |
| Photo library | `/mnt/immich/library/` | ~3TB | rsync | Weekly Sun 05:00 | WD Portable external drive |

## What Does NOT Get Backed Up (Regeneratable)

| Data | Path | Reason |
|------|------|--------|
| Thumbnails | `/mnt/immich/thumbs/` | Regenerated from originals on startup |
| Encoded video | `/mnt/immich/encoded-video/` | Re-transcoded from originals |
| ML model cache | `/mnt/immich/model-cache/` | Re-downloaded from Immich releases |
| Redis | Docker container | Ephemeral cache; rebuilt on restart |

---

## VM-Level Backup (Proxmox vzdump)

Spine governs this via `backup.inventory.yaml`:
- Target: `vm-203-primary`
- Schedule: Daily (vzdump job covering VMs 200,202-210)
- Classification: `important`
- Stale threshold: 26 hours

This captures the entire VM disk image. The app-level backups below provide point-in-time PostgreSQL recovery and library-level granularity that vzdump cannot.

---

## PostgreSQL Backup Script

The script runs daily at 03:00 via cron on immich-1 VM.

**Logic:**
1. Discover the running postgres container by name filter (`immich.*postgres`)
2. Execute `pg_dumpall -U postgres` inside the container
3. Pipe output through gzip to local staging directory
4. Validate backup file size (must be >1KB)
5. Remove backups older than 7 days

**Staging directory:** `~/backups/immich/postgres/` (on immich-1 VM)

**Offsite sync:** A separate job at 04:30 copies DB dumps to Synology NAS at `/volume1/backups/immich/postgres/`.

**Cron entry (expected):**
```
0 3 * * * ~/scripts/backup-immich-db.sh >> ~/logs/immich-backup.log 2>&1
```

> **GAP-OP-094:** VM 203 is currently network-isolated. Cron path has not been verified since the UDR6 cutover. The script may reference a stale path. Verify via VNC console when network is restored.

---

## Photo Library Backup

**Method:** rsync with low I/O priority to external WD Portable drive.

**Key parameters:**
- Source: `/mnt/immich/library/`
- Destination: `/mnt/wd-backup/immich/`
- Schedule: Weekly Sunday 05:00
- I/O priority: `ionice -c3 nice -n19` (idle class, won't impact service)
- Duration: Several hours for 3TB
- Prerequisite: WD Portable must be physically connected and mounted at `/mnt/wd-backup`

**Cron entry (expected):**
```
0 5 * * 0 ~/scripts/backup-immich-library.sh >> ~/logs/backup-immich-library.log 2>&1
```

---

## Restore Procedures

### Restore PostgreSQL

```bash
# 1. Stop Immich
cd ~/immich && docker compose down

# 2. Restore from most recent dump
zcat ~/backups/immich/postgres/immich_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i immich-postgres psql -U postgres

# 3. Start Immich
cd ~/immich && docker compose up -d
```

If local backups are lost, retrieve from Synology offsite:
```bash
scp nas:/volume1/backups/immich/postgres/immich_LATEST.sql.gz ~/backups/immich/postgres/
```

### Restore Photo Library

```bash
# 1. Stop Immich
cd ~/immich && docker compose down

# 2. Restore from WD Portable (takes hours for 3TB)
rsync -av --progress /mnt/wd-backup/immich/ /mnt/immich/library/

# 3. Start Immich
cd ~/immich && docker compose up -d

# 4. Immich will automatically regenerate thumbnails
```

---

## Verification Commands

```bash
# Check PostgreSQL backup age
ls -lht ~/backups/immich/postgres/ | head -3

# Check library backup (WD Portable)
du -sh /mnt/wd-backup/immich/

# Check Synology offsite copy
ssh nas "ls -lht /volume1/backups/immich/postgres/ | head -3"

# Check backup cron is registered
crontab -l | grep -i immich
```

---

## Storage Paths Reference

| Item | Path | Notes |
|------|------|-------|
| Compose directory | `~/immich/` | On immich-1 VM |
| Photo library | `/mnt/immich/library/` | 3TB originals |
| Thumbnails | `/mnt/immich/thumbs/` | Regeneratable |
| Encoded video | `/mnt/immich/encoded-video/` | Regeneratable |
| ML model cache | `/mnt/immich/model-cache/` | Re-downloadable |
| DB backup staging | `~/backups/immich/postgres/` | 7-day retention |
| Synology offsite | `/volume1/backups/immich/postgres/` | DB dumps |
| WD Portable | `/mnt/wd-backup/immich/` | Library mirror |
| ZFS datasets (pve) | `tank/immich/photos` (1.15TB), `tank/immich/db` (205K) | Host-level storage |

---

## Special Considerations

- **3TB library rsync** takes hours. Only runs weekly. WD Portable must be connected.
- **pg_dumpall** captures all databases, not just Immich. This is intentional — simpler than targeting specific DBs.
- **Thumbnails regeneration** takes significant time on first start after restore. Plan for 30-60 minutes.
- **Infisical secrets** are separate from backup. `DB_PASSWORD` lives in Infisical project `immich` (`4bf7f25e-596b-4293-9d2a-c2c7c2d0df42`).
