---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-backup-restore
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: Backup & Restore Procedures

> Operational knowledge for finance stack database backup and restore on docker-host (VM 200).

## What Gets Backed Up

| Component | Method | Size (approx) | Frequency | Retention |
|-----------|--------|---------------|-----------|-----------|
| Firefly III PostgreSQL | `pg_dump` → gzip | ~50 MB | Daily 02:00 | 30 days |
| Ghostfolio data | `tar -czf` of data directory | ~50 MB | Daily 02:00 | 30 days |
| Paperless documents | `document_exporter` + SQLite dump | Variable | Daily 02:00 | 30 days |

### What Does NOT Get Backed Up

| Component | Reason |
|-----------|--------|
| Redis | Ephemeral cache/session data; rebuilds automatically |
| Firefly III uploads | Low volume; stored in Docker volume (recoverable from compose) |
| Data Importer config | Stateless; configuration via env vars |

## Backup Script

The backup script (`backup-finance-stack.sh`, ~209 lines) runs on docker-host and performs:

1. **Firefly PostgreSQL dump:**
   ```
   docker exec finance-postgres pg_dump -U firefly -d firefly > firefly_YYYYMMDD.sql
   gzip firefly_YYYYMMDD.sql
   ```

2. **Ghostfolio data archive:**
   ```
   tar -czf ghostfolio_YYYYMMDD.tar.gz /mnt/data/finance/ghostfolio/
   ```

3. **Paperless export:**
   ```
   docker exec paperless document_exporter /export
   sqlite3 /mnt/data/finance/paperless/db.sqlite3 .dump > paperless_db_YYYYMMDD.sql
   ```

4. **Cleanup:** Remove files older than 30 days from backup directory

### Backup Destinations

| Destination | Path | Notes |
|-------------|------|-------|
| Local staging | `/home/docker-host/backups/finance/` | On docker-host local disk |
| NFS (Synology) | `/mnt/backups/finance/` | NFS mount to Synology NAS |

### Cron Schedule

```
0 2 * * * /home/docker-host/stacks/finance/backup-finance-stack.sh >> /var/log/finance-backup.log 2>&1
```

> **Spine binding status:** `backup.inventory.yaml` has `app-firefly` registered but **disabled** (`enabled: false`). This needs to be enabled as part of the extraction follow-up (P2).

## Restore Procedures

### Restore Firefly III Database

```bash
# 1. Stop Firefly (keep Postgres running)
docker compose -f ~/stacks/finance/docker-compose.yml stop firefly-iii data-importer cron

# 2. Drop and recreate database
docker exec -i finance-postgres psql -U firefly -c "DROP DATABASE IF EXISTS firefly;"
docker exec -i finance-postgres psql -U firefly -c "CREATE DATABASE firefly OWNER firefly;"

# 3. Restore from backup
gunzip -c /mnt/backups/finance/firefly_YYYYMMDD.sql.gz | \
  docker exec -i finance-postgres psql -U firefly -d firefly

# 4. Restart services
docker compose -f ~/stacks/finance/docker-compose.yml up -d

# 5. Verify
curl -s -H "Authorization: Bearer $FIREFLY_PAT" \
  https://firefly.ronny.works/api/v1/about | jq .
```

### Restore Ghostfolio

```bash
# 1. Stop Ghostfolio
docker compose -f ~/stacks/finance/docker-compose.yml stop ghostfolio

# 2. Restore data directory
rm -rf /mnt/data/finance/ghostfolio/*
tar -xzf /mnt/backups/finance/ghostfolio_YYYYMMDD.tar.gz -C /

# 3. Restart
docker compose -f ~/stacks/finance/docker-compose.yml up -d ghostfolio
```

### Restore Paperless

```bash
# 1. Stop Paperless
docker compose -f ~/stacks/finance/docker-compose.yml stop paperless-ngx

# 2. Restore SQLite database
cp /mnt/backups/finance/paperless_db_YYYYMMDD.sql /tmp/
sqlite3 /mnt/data/finance/paperless/db.sqlite3 < /tmp/paperless_db_YYYYMMDD.sql

# 3. Restore documents (if document_exporter backup exists)
# Documents are stored at /mnt/data/finance/paperless/media/

# 4. Restart
docker compose -f ~/stacks/finance/docker-compose.yml up -d paperless-ngx
```

## Disaster Recovery Notes

- **RPO:** 24 hours (daily backup at 02:00)
- **RTO:** ~30 minutes (restore from NFS, restart containers)
- **Single point of failure:** docker-host VM 200 disk. If the VM disk fails and NFS backups are intact, full restore is possible. If NFS is also down, data loss occurs.
- **Firefly transaction count:** 508+ as of 2026-01-13
- **Paperless document count:** 32+ as of 2026-01-13

## Known Issues

| Issue | Impact | Mitigation |
|-------|--------|------------|
| Backup is DISABLED in spine `backup.inventory.yaml` | Spine-governed backup monitoring doesn't cover finance | Enable `app-firefly` in P2 |
| No backup verification/integrity check | Silent corruption possible | Add `pg_restore --list` validation step |
| Ghostfolio backup is tar of data dir, not DB dump | Restore may fail if Ghostfolio version changes | Consider switching to proper DB dump |
| Paperless uses SQLite | `.dump` may miss in-flight writes | Stop Paperless before backup (acceptable at 02:00) |

## Secrets (Paths Only)

| Secret | Infisical Path | Usage |
|--------|---------------|-------|
| PostgreSQL password | `/finance-stack/prod/POSTGRES_PASSWORD` | Database access for pg_dump |
| NFS credentials | System-level (fstab mount) | Backup destination access |
