---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: app-backup-restore
---

# Infisical Backup + Restore (App-Level)

Purpose: define a human-runnable, app-level backup/restore procedure for Infisical
even when VM-level `vzdump` exists.

Host + stack:
- Host: `infra-core` (VM 204)
- Compose: `/opt/stacks/secrets/docker-compose.yml`
- Containers (expected): `infisical`, `infisical-postgres`, `infisical-redis`

## Backup

Backup artifact: a compressed Postgres dump (`.sql.gz`) for the Infisical database.

Automated: cron on infra-core runs daily at 02:50, dumps to local, rsync to NAS.

Manual backup:

1. Create a DB dump on `infra-core`:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets

set -a
source .env
set +a

ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/infisical-db-${ts}.sql.gz"

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  pg_dump -U infisical infisical | gzip > "$out"

ls -lh "$out"
'
```

2. Copy the artifact to the NAS backup area via rsync (NAS is not locally mounted on infra-core):

```bash
ssh infra-core '
set -euo pipefail
src="$(ls -1t /tmp/infisical-db-*.sql.gz | head -n 1)"
rsync -avz "$src" nas:/volume1/backups/apps/infisical/
'
```

If `nas` is unreachable from infra-core, pull the dump to the MacBook first:
```bash
scp infra-core:/tmp/infisical-db-*.sql.gz /tmp/
scp /tmp/infisical-db-*.sql.gz nas:/volume1/backups/apps/infisical/
```

Notes:
- The automated cron (02:50 daily) handles this rsync automatically.
- Secrets of record live in Infisical itself; the `.env` on-host contains DB credentials only.

## Restore (Disaster Recovery)

Restore goal: replace the Infisical Postgres DB content with a known-good dump.

Prerequisites:
- A working `infra-core` VM (restored from vzdump or fresh-provisioned).
- The Infisical compose stack deployed at `/opt/stacks/secrets/`.
- The `.env` file populated (from spine bootstrap or manual secret injection).

1. Pick a dump file on NAS (or wherever you stored it), and copy it to `infra-core:/tmp/`.

2. Stop Infisical application containers (leave Postgres running):

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
docker compose stop infisical infisical-redis
'
```

3. Restore into Postgres (drops and recreates the DB):

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
set -a; source .env; set +a

dump="/tmp/INFISICAL_DUMP.sql.gz"   # replace with actual filename

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS infisical;"

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE infisical OWNER infisical;"

gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d infisical -v ON_ERROR_STOP=1
'
```

4. Start Infisical application containers:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
docker compose up -d infisical infisical-redis
'
```

5. Validate:
- `./bin/ops cap run services.health.status` should show `infisical` OK.
- Log into `https://secrets.ronny.works` (through Authentik) and confirm projects/secrets are present.
- Run `./bin/ops cap run secrets.projects.status` to verify project parity.

## Break-Glass: Infisical Down, Need Secrets

If Infisical is completely unavailable and you need secrets to bootstrap:

1. Check `~/.config/infisical/credentials` on the MacBook for cached universal auth tokens.
2. Check `~/.cache/infisical/` for any cached secret values from previous runs.
3. The spine's `secrets.exec` wrapper caches injected env vars — recent receipt outputs in
   `receipts/sessions/` may contain non-secret metadata that helps identify which secrets are needed.
4. Critical bootstrap secrets (DB passwords, API tokens) should also exist in the Vaultwarden
   vault at `https://vault.ronny.works` as a secondary source.

## Restore Test (Required)

Minimum: quarterly restore test into a scratch environment (or after any major Infisical upgrade).
Record evidence as a spine receipt + note in the relevant loop/gap.
