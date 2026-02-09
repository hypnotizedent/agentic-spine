---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: app-backup-restore
---

# Gitea Backup + Restore (App-Level)

Purpose: define a human-runnable, app-level backup/restore procedure for Gitea
even when VM-level `vzdump` exists.

Host + stack:
- Host: `dev-tools` (VM 206)
- Compose: `/opt/stacks/gitea/docker-compose.yml`
- Containers (expected): `gitea`, `gitea-postgres`, `gitea-runner`

## Automated Backup

An automated backup script is staged at `ops/staged/dev-tools/gitea-backup.sh`.
Once deployed to `/usr/local/bin/gitea-backup.sh` on dev-tools with cron `55 2 * * *`,
it runs daily producing both a gitea dump (zip) and pg_dump (sql.gz), then rsyncs to
the NAS at `/volume1/backups/apps/gitea/` with 7-day retention.

Tracked in `backup.inventory.yaml` as `app-gitea`. Loop: LOOP-DEV-TOOLS-GITEA-STANDARDIZATION-20260209.

## Manual Backup

Backup artifacts:
1. Gitea application dump (`gitea dump` zip) covering repos + attachments + config snapshot.
2. Postgres dump (`.sql.gz`) for the DB (belt-and-suspenders).

1. Create a Gitea app dump on `dev-tools`:

```bash
ssh dev-tools '
set -euo pipefail
ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/gitea-dump-${ts}.zip"

docker exec gitea gitea dump --file "$out"
ls -lh "$out"
'
```

2. Create a Postgres dump (reads stack `.env` on-host; does not print secrets):

```bash
ssh dev-tools '
set -euo pipefail
cd /opt/stacks/gitea
set -a
source .env
set +a

ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/gitea-db-${ts}.sql.gz"

docker exec -e PGPASSWORD="$GITEA_DB_PASSWORD" gitea-postgres \
  pg_dump -U gitea gitea | gzip > "$out"

ls -lh "$out"
'
```

3. Move artifacts to NAS backup area:

```bash
ssh dev-tools '
set -euo pipefail
dst_dir="/volume1/backups/apps/gitea"
sudo mkdir -p "$dst_dir"
sudo mv /tmp/gitea-dump-*.zip "$dst_dir/" || true
sudo mv /tmp/gitea-db-*.sql.gz "$dst_dir/" || true
sudo ls -lt "$dst_dir" | head
'
```

Notes:
- If `/volume1/...` is not mounted on `dev-tools`, copy the files to `nas` via `scp`/`rsync` instead.
- Secrets of record live in Infisical (spine namespace); do not copy `.env` off-host.

## Restore (Disaster Recovery)

Restore goal: restore DB + repos/config, then bring Gitea back up.

1. Copy the selected backup artifacts to `dev-tools:/tmp/`:
- `gitea-dump-<ts>.zip`
- `gitea-db-<ts>.sql.gz`

2. Stop Gitea (leave Postgres running):

```bash
ssh dev-tools '
set -euo pipefail
cd /opt/stacks/gitea
docker compose stop gitea gitea-runner
'
```

3. Restore Postgres:

```bash
ssh dev-tools '
set -euo pipefail
cd /opt/stacks/gitea
set -a; source .env; set +a

dump="/tmp/GITEA_DB_DUMP.sql.gz"  # replace

docker exec -e PGPASSWORD="$GITEA_DB_PASSWORD" gitea-postgres \
  psql -U gitea -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS gitea;"

docker exec -e PGPASSWORD="$GITEA_DB_PASSWORD" gitea-postgres \
  psql -U gitea -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE gitea OWNER gitea;"

gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$GITEA_DB_PASSWORD" gitea-postgres \
  psql -U gitea -d gitea -v ON_ERROR_STOP=1
'
```

4. Restore repo/config/attachments from the Gitea dump:

```bash
ssh dev-tools '
set -euo pipefail
zip="/tmp/GITEA_DUMP.zip"  # replace

# gitea restore expects to run inside the container.
docker exec gitea gitea restore --from "$zip"
'
```

5. Start Gitea:

```bash
ssh dev-tools '
set -euo pipefail
cd /opt/stacks/gitea
docker compose up -d gitea gitea-runner
'
```

6. Validate:
- `./bin/ops cap run services.health.status` should show `gitea` OK.
- Visit `https://git.ronny.works` and confirm login + a repo clone works.

## Restore Test (Required)

Minimum: quarterly restore test into a scratch instance (or after any major Gitea upgrade).
Record evidence as a spine receipt + note in the relevant loop/gap.

