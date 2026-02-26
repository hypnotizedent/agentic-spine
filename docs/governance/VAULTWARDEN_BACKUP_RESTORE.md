---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-26
scope: app-backup-restore
---

# Vaultwarden Backup + Restore (App-Level)

Purpose: define a human-runnable, app-level backup/restore procedure for Vaultwarden
even when VM-level `vzdump` exists.

Host + stack:
- Host: `infra-core` (VM 204)
- Compose: `/opt/stacks/vaultwarden/docker-compose.yml`
- Container: `vaultwarden`
- Data volume: `./vw-data:/data/`

## Backup

Backup artifact: a compressed tar.gz of the `vw-data/` directory (SQLite DB + attachments + config).

Automated: cron on infra-core runs daily at 02:45, dumps to local, rsync to NAS.

Manual backup:

1. Create a tar.gz archive on `infra-core`:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/vaultwarden

ts="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="/tmp/vaultwarden-backup-${ts}.tar.gz"

tar -czf "$out" -C . vw-data/

ls -lh "$out"
'
```

2. Copy the artifact to the NAS:

```bash
ssh infra-core '
set -euo pipefail
src="$(ls -1t /tmp/vaultwarden-backup-*.tar.gz | head -n 1)"
rsync -avz "$src" ronadmin@nas:/volume1/backups/apps/vaultwarden/
'
```

If `nas` is unreachable from infra-core, pull the dump to the MacBook first:
```bash
scp infra-core:/tmp/vaultwarden-backup-*.tar.gz /tmp/
scp /tmp/vaultwarden-backup-*.tar.gz ronadmin@nas:/volume1/backups/apps/vaultwarden/
```

Notes:
- The automated cron (02:45 daily) handles this rsync automatically.
- Vaultwarden uses SQLite (inside `vw-data/db.sqlite3`), not Postgres.
- The tar.gz includes attachments, icon cache, and RSA keys alongside the DB.

## Restore (Disaster Recovery)

Restore goal: replace the Vaultwarden data directory with a known-good backup.

Prerequisites:
- A working `infra-core` VM (restored from vzdump or fresh-provisioned).
- The Vaultwarden compose stack deployed at `/opt/stacks/vaultwarden/`.
- The `.env` file populated (ADMIN_TOKEN from Infisical at `/spine/vm-infra/vaultwarden/`).

1. Pick a backup file on NAS and copy it to `infra-core:/tmp/`.

2. Stop Vaultwarden:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/vaultwarden
docker compose down
'
```

3. Replace the data directory with the backup:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/vaultwarden

backup="/tmp/VAULTWARDEN_BACKUP.tar.gz"   # replace with actual filename

# Move current data aside (safety net)
mv vw-data vw-data.pre-restore.$(date +%s)

# Extract backup
tar -xzf "$backup" -C .

ls -la vw-data/
'
```

4. Start Vaultwarden:

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/vaultwarden
docker compose up -d
'
```

5. Validate:
- `./bin/ops cap run services.health.status` should show `vaultwarden` OK.
- Browse to `https://vault.ronny.works` (through Authentik) and confirm vault access.
- Check `docker logs vaultwarden --tail 20` for startup errors.

## Secrets Recovery

The `ADMIN_TOKEN` is stored in Infisical at `/spine/vm-infra/vaultwarden/VAULTWARDEN_ADMIN_TOKEN`.

To reconstruct the `.env` file:

```bash
# From MacBook (requires Infisical credentials at ~/.config/infisical/credentials)
source ~/.config/infisical/credentials

TOKEN=$(curl -s -X POST "${INFISICAL_API_URL}/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\": \"$INFISICAL_UNIVERSAL_AUTH_CLIENT_ID\", \"clientSecret\": \"$INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET\"}" \
  | jq -r ".accessToken")

ADMIN_TOKEN=$(curl -s "http://100.92.91.128:8088/api/v3/secrets/raw/VAULTWARDEN_ADMIN_TOKEN?workspaceId=01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9&environment=prod&secretPath=/spine/vm-infra/vaultwarden" \
  -H "Authorization: Bearer $TOKEN" | jq -r ".secret.secretValue")

# Write .env on infra-core
ssh infra-core "cat > /opt/stacks/vaultwarden/.env" <<ENVEOF
ADMIN_TOKEN=${ADMIN_TOKEN}
DOMAIN=https://vault.ronny.works
LOG_LEVEL=warn
SIGNUPS_ALLOWED=false
TZ=America/New_York
WEBSOCKET_ENABLED=true
WEB_VAULT_ENABLED=true
ENVEOF
```

## Break-Glass: Vaultwarden Down, Need Credentials

If Vaultwarden is completely unavailable:

1. Check the NAS for the most recent backup: `ssh ronadmin@nas 'ls -lt /volume1/backups/apps/vaultwarden/'`
2. If infra-core is dead, restore the VM from vzdump first, then apply the app-level restore above.
3. Critical accounts may also be recoverable from browser password managers or mobile apps that cache vault data offline.
4. The Vaultwarden admin panel (`/admin`) requires `ADMIN_TOKEN` — retrieve from Infisical or cached credentials.

## Restore Test (Required)

Minimum: quarterly restore test into a scratch environment (or after any major Vaultwarden upgrade).
Record evidence as a spine receipt + note in the relevant loop/gap.

## Vault Hygiene Policy (Trash Disposition)

Purpose: define when an elevated Vaultwarden trash ratio is a policy-accepted carry-forward vs an incident that requires immediate cleanup.

Disposition policy:

1. `vaultwarden.backup.verify` MUST be `PASS` before any destructive cleanup of trashed entries.
2. If forensic reconciliation reports no high-confidence missing records, elevated trash ratio is treated as hygiene debt (not incident) until a scheduled owner cleanup window.
3. Escalate to a new high-severity gap if either condition is true:
   - `trash_ratio >= 50%` for two consecutive audits, or
   - `ciphers_trashed >= 400`.
4. During cleanup windows, retain recovery candidates in folder `98-forensic-recovery` first, then permanently delete only confirmed stale entries.

Current disposition (2026-02-26):

- Latest audit: `ciphers_trashed=368`, `trash_ratio=46%` (`CAP-20260226-020813__vaultwarden.vault.audit__R9elc7799`)
- Backup verification: `PASS` (`CAP-20260226-020813__vaultwarden.backup.verify__Rb3lc7800`)
- Status: policy-accepted carry-forward with weekly monitoring until owner cleanup session.
