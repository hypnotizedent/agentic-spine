---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: app-backup-restore
canonical_doctrine: docs/governance/FINANCE_STACK_DOCTRINE_V1.md
---

# Finance Stack Backup + Restore (App-Level)

**Canonical Doctrine**: See `docs/governance/FINANCE_STACK_DOCTRINE_V1.md` for non-negotiable finance stack governance rules.

Purpose: define the authoritative backup, restore, and destructive-safety
contract for finance-stack (VM 211) services: Firefly III, Ghostfolio, and
Paperless-ngx.

Host + stack:
- Host: `finance-stack` (VM 211)
- Compose: `/opt/stacks/finance/docker-compose.yml`
- Runtime script: `/usr/local/bin/finance-stack-backup.sh`
- Cron: `20 6 * * * /usr/local/bin/finance-stack-backup.sh >> /var/log/finance-stack-backup.log 2>&1`
- Live data root: `/mnt/data/finance`
- Local guarded staging: `/mnt/backups/finance/staging`
- Local last-good archive: `/mnt/backups/finance/last-good`

## Automated Backup Contract

The backup script creates four artifacts in a single run:
1. Firefly DB dump: `firefly-db-<ts>.sql.gz`
2. Ghostfolio DB dump: `ghostfolio-db-<ts>.sql.gz`
3. Paperless DB dump: `paperless-db-<ts>.sql.gz`
4. Paperless export zip via `document_exporter`: `paperless-export-<ts>.zip`
5. Finance backup sanity manifest: `finance-backup-manifest-<ts>.txt`

Destination (730XD canonical plane):
- `/md1400/backup-cold/apps/finance/firefly/`
- `/md1400/backup-cold/apps/finance/ghostfolio/`
- `/md1400/backup-cold/apps/finance/paperless/`
- `/md1400/backup-cold/apps/finance/finance-backup-manifest-<ts>.txt`

Success criteria:
- Local artifact creation succeeds.
- 730XD connectivity succeeds.
- Every artifact is copied offsite.
- Every copied artifact is verified on 730XD before staging cleanup.
- Sanity checks do not indicate empty-state or severe regression unless explicit
  break-glass override is set with `FINANCE_BACKUP_ALLOW_REGRESSION=1`.

Failure behavior:
- If offsite copy fails, the run fails and staging is preserved.
- If sanity checks fail, the run fails before promoting new artifacts.
- `last-good` is only updated after verified offsite success.

Retention: 14 days (730XD-side prune after verification).

Tracked in `ops/bindings/backup.inventory.yaml`:
- `app-firefly`
- `app-ghostfolio`
- `app-paperless-db`
- `app-paperless-export`

## Manual Backup (On-Demand)

Run immediately on VM 211:

```bash
ssh finance-stack 'sudo /usr/local/bin/finance-stack-backup.sh'
```

Verify newest artifacts:

```bash
ssh pve 'ls -lt /md1400/backup-cold/apps/finance/firefly | head'
ssh pve 'ls -lt /md1400/backup-cold/apps/finance/ghostfolio | head'
ssh pve 'ls -lt /md1400/backup-cold/apps/finance/paperless | head'
ssh pve 'ls -lt /md1400/backup-cold/apps/finance/finance-backup-manifest-*.txt | head'
ssh finance-stack 'ls -lt /mnt/backups/finance/last-good | head'
```

Break-glass backup override:

```bash
ssh finance-stack 'sudo FINANCE_BACKUP_ALLOW_REGRESSION=1 /usr/local/bin/finance-stack-backup.sh'
```

Use the override only when an operator has already validated that the apparent
regression is expected and has recorded a receipt.

## Restore (Disaster Recovery)

Prereqs:
- VM 211 restored/rebuilt.
- Stack present at `/opt/stacks/finance`.
- `.env` reconstructed from Infisical (`/spine/services/finance` and `/spine/services/paperless`).
- Restore artifacts copied from the 730XD canonical plane to `/tmp/` on `finance-stack`.
- Confirm the destructive guard contract before any compose mutation:

```bash
./ops/plugins/infra/docker/bin/docker-compose-up finance-stack finance
./ops/plugins/infra/docker/bin/docker-compose-down finance-stack finance
```

Both commands should block protected empty-state/destructive actions unless
break-glass is explicitly acknowledged.

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
./bin/ops cap run finance.backup.status
./bin/ops cap run finance.stack.status
```

Confirm `app-firefly`, `app-ghostfolio`, `app-paperless-db`, and
`app-paperless-export` are fresh in `backup.status`, and confirm the newest
finance manifest aligns with expected row/document counts before treating the
run as a new recovery baseline.
