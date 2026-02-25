---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-25
scope: app-backup-restore
---

# Finance Stack Backup + Restore (App-Level)

Purpose: define a repeatable app-level backup/restore procedure for finance-stack
(VM 211) services: Firefly III, Ghostfolio, and Paperless-ngx.

Host + stack:
- Host: `finance-stack` (VM 211)
- Compose: `/opt/stacks/finance/docker-compose.yml`
- Runtime script: `/usr/local/bin/finance-stack-backup.sh`
- Cron: `20 6 * * * /usr/local/bin/finance-stack-backup.sh >> /var/log/finance-stack-backup.log 2>&1`

## Automated Backup Contract

The backup script performs four artifacts in a single run:
1. Firefly DB dump: `firefly-db-<ts>.sql.gz`
2. Ghostfolio DB dump: `ghostfolio-db-<ts>.sql.gz`
3. Paperless DB dump: `paperless-db-<ts>.sql.gz`
4. Paperless export zip via `document_exporter`: `paperless-export-<ts>.zip`

Destination (NAS):
- `/volume1/backups/apps/finance/`
- `/volume1/backups/apps/ghostfolio/`
- `/volume1/backups/apps/paperless/`

Retention: 14 days (script-side prune).

Tracked in `ops/bindings/backup.inventory.yaml`:
- `app-firefly`
- `app-ghostfolio`
- `app-paperless-db`
- `app-paperless-export`

## Manual Backup (On-Demand)

Run immediately on VM 211:

```bash
ssh finance-stack '/usr/local/bin/finance-stack-backup.sh'
```

Verify newest artifacts:

```bash
ssh ronadmin@nas 'ls -lt /volume1/backups/apps/finance | head'
ssh ronadmin@nas 'ls -lt /volume1/backups/apps/ghostfolio | head'
ssh ronadmin@nas 'ls -lt /volume1/backups/apps/paperless | head'
```

## Restore (Disaster Recovery)

Prereqs:
- VM 211 restored/rebuilt.
- Stack present at `/opt/stacks/finance`.
- `.env` reconstructed from Infisical (`/spine/services/finance` and `/spine/services/paperless`).

### Firefly III restore (Postgres)

```bash
ssh finance-stack '
set -euo pipefail
cd /opt/stacks/finance
set -a; source .env; set +a
dump="/tmp/FIREFLY_DB.sql.gz"   # replace
gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" firefly-postgres \
  psql -U "${POSTGRES_USER:-firefly}" -d "${POSTGRES_DB:-firefly}" -v ON_ERROR_STOP=1
'
```

### Ghostfolio restore (Postgres)

```bash
ssh finance-stack '
set -euo pipefail
cd /opt/stacks/finance
set -a; source .env; set +a
dump="/tmp/GHOSTFOLIO_DB.sql.gz"   # replace
gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" firefly-postgres \
  psql -U "${POSTGRES_USER:-firefly}" -d ghostfolio -v ON_ERROR_STOP=1
'
```

### Paperless restore (DB + documents)

```bash
ssh finance-stack '
set -euo pipefail
cd /opt/stacks/finance
set -a; source .env; set +a
dump="/tmp/PAPERLESS_DB.sql.gz"   # replace
gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$PAPERLESS_DB_PASS" firefly-postgres \
  psql -U paperless -d paperless -v ON_ERROR_STOP=1
'
```

Paperless document export import (if needed):

```bash
ssh finance-stack '
set -euo pipefail
zip="/tmp/PAPERLESS_EXPORT.zip"   # replace
docker exec -i paperless-ngx document_importer "$zip"
'
```

## Validation

After backup or restore:

```bash
./bin/ops cap run backup.status
./bin/ops cap run finance.stack.status
```

Confirm `app-firefly`, `app-ghostfolio`, `app-paperless-db`, and
`app-paperless-export` are fresh in `backup.status`.
