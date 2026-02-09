---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-08
scope: app-backup-restore
---

# Authentik Backup + Restore (App-Level)

Purpose: define a human-runnable, app-level backup/restore procedure for Authentik
even when VM-level `vzdump` exists.

Host + stack:
- Host: `infra-core` (VM 204)
- Compose: `/opt/stacks/caddy-auth/docker-compose.yml`
- Containers (expected): `authentik-server`, `authentik-worker`, `authentik-postgres`, `authentik-redis`

## Backup

Backup artifact: a compressed Postgres dump (`.sql.gz`) for the Authentik database.

1. Create a DB dump on `infra-core` (reads the stack `.env` on-host; does not print secrets):

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/caddy-auth

# Host-local env file (not in git). Contains AUTHENTIK_DB_PASSWORD.
set -a
source .env
set +a

ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/authentik-db-${ts}.sql.gz"

docker exec -e PGPASSWORD="$AUTHENTIK_DB_PASSWORD" authentik-postgres \
  pg_dump -U authentik authentik | gzip > "$out"

ls -lh "$out"
'
```

2. Move the artifact to the NAS backup area (create the directory if needed):

```bash
ssh infra-core '
set -euo pipefail
ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
src="$(ls -1t /tmp/authentik-db-*.sql.gz | head -n 1)"
dst_dir="/volume1/backups/apps/authentik"
sudo mkdir -p "$dst_dir"
sudo mv "$src" "$dst_dir/"
sudo ls -lt "$dst_dir" | head
'
```

Notes:
- If `/volume1/...` is not mounted on `infra-core`, copy the file to `nas` via `scp`/`rsync` instead.
- Secrets of record live in Infisical (spine namespace); do not copy `.env` off-host.

## Restore (Disaster Recovery)

Restore goal: replace the Authentik Postgres DB content with a known-good dump.

1. Pick a dump file on NAS (or wherever you stored it), and copy it to `infra-core:/tmp/`.

2. Stop Authentik application containers (leave Postgres running):

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/caddy-auth
docker compose stop authentik-server authentik-worker
'
```

3. Restore into Postgres (drops and recreates the DB):

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/caddy-auth
set -a; source .env; set +a

dump="/tmp/AUTHENTIK_DUMP.sql.gz"   # replace

docker exec -e PGPASSWORD="$AUTHENTIK_DB_PASSWORD" authentik-postgres \
  psql -U authentik -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS authentik;"

docker exec -e PGPASSWORD="$AUTHENTIK_DB_PASSWORD" authentik-postgres \
  psql -U authentik -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE authentik OWNER authentik;"

gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$AUTHENTIK_DB_PASSWORD" authentik-postgres \
  psql -U authentik -d authentik -v ON_ERROR_STOP=1
'
```

4. Start Authentik application containers:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/caddy-auth
docker compose up -d authentik-server authentik-worker
'
```

5. Validate:
- `./bin/ops cap run services.health.status` should show `authentik` OK.
- Log into `https://auth.ronny.works` and confirm flows/users are present.

## Restore Test (Required)

Minimum: quarterly restore test into a scratch environment (or after any major Authentik upgrade).
Record evidence as a spine receipt + note in the relevant loop/gap.

