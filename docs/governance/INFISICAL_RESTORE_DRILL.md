---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: infisical-restore-drill
---

# Infisical Restore Drill Procedure

Purpose: executable quarterly restore test for Infisical. Run this procedure to
validate that INFISICAL_BACKUP_RESTORE.md is accurate, backups are restorable,
and RTO/RPO targets (2h/24h) are achievable.

Cadence: **quarterly** or after any major Infisical upgrade.

Reference: `INFISICAL_BACKUP_RESTORE.md` (app-level backup/restore),
`DR_RUNBOOK.md` (Scenario 4), `RTO_RPO.md` (Tier 1 objectives).

## Pre-Drill Checklist

Before starting the drill, confirm all prerequisites:

- [ ] **Backup freshness**: Run `./bin/ops cap run backup.status` — `app-infisical` must show `ok` (not `stale`).
- [ ] **Dump artifact exists**: Verify a recent `.sql.gz` on NAS:
  ```bash
  ssh nas 'ls -lht /volume1/backups/apps/infisical/ | head -5'
  ```
- [ ] **infra-core healthy**: Run `./bin/ops cap run services.health.status` — `infisical` endpoint must respond.
- [ ] **No active incidents**: Confirm no open P0/P1 loops touching infra-core or secrets.
- [ ] **Scratch DB name chosen**: Use `infisical_drill` (never overwrite production `infisical` DB).

## Drill Execution

### Step 1: Copy Latest Dump to infra-core

```bash
ssh infra-core '
set -euo pipefail
# Pull latest dump from NAS
latest="$(ssh nas "ls -1t /volume1/backups/apps/infisical/*.sql.gz | head -1")"
scp "nas:${latest}" /tmp/infisical-drill-restore.sql.gz
ls -lh /tmp/infisical-drill-restore.sql.gz
'
```

If NAS is unreachable from infra-core, relay through MacBook:
```bash
latest="$(ssh nas 'ls -1t /volume1/backups/apps/infisical/*.sql.gz | head -1')"
scp "nas:${latest}" /tmp/infisical-drill-restore.sql.gz
scp /tmp/infisical-drill-restore.sql.gz infra-core:/tmp/
```

### Step 2: Create Scratch Database

This creates a parallel database — production `infisical` DB is NOT touched.

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
set -a; source .env; set +a

# Create scratch DB (drop if leftover from previous drill)
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS infisical_drill;"

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE infisical_drill OWNER infisical;"

echo "Scratch DB infisical_drill created."
'
```

### Step 3: Restore Into Scratch Database

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
set -a; source .env; set +a

dump="/tmp/infisical-drill-restore.sql.gz"
START_TS=$(date +%s)

gunzip -c "$dump" | docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d infisical_drill -v ON_ERROR_STOP=1 2>&1 | tail -5

END_TS=$(date +%s)
echo "Restore completed in $((END_TS - START_TS)) seconds."
'
```

Record the restore duration — this contributes to RTO validation.

### Step 4: Validate Restored Data

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
set -a; source .env; set +a

echo "=== Table count ==="
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d infisical_drill -t \
  -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = '"'"'public'"'"';"

echo "=== Project count ==="
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d infisical_drill -t \
  -c "SELECT count(*) FROM projects;" 2>/dev/null || echo "(projects table not found — check schema)"

echo "=== Secret folder count ==="
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d infisical_drill -t \
  -c "SELECT count(*) FROM secret_folders;" 2>/dev/null || echo "(secret_folders table not found — check schema)"

echo "=== Recent audit log entries ==="
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d infisical_drill -t \
  -c "SELECT count(*) FROM audit_logs;" 2>/dev/null || echo "(audit_logs table not found — check schema)"
'
```

**Validation criteria (all must pass):**
- [ ] Table count > 0 (schema restored)
- [ ] Project count matches expected (compare with `./bin/ops cap run secrets.projects.status`)
- [ ] No ERROR output from psql restore step
- [ ] Restore duration < 120 minutes (RTO target: 2h, includes full stack restart overhead)

### Step 5: Cleanup Scratch Database

```bash
ssh infra-core '
set -euo pipefail
cd /opt/stacks/secrets
set -a; source .env; set +a

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" infisical-postgres \
  psql -U infisical -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS infisical_drill;"

rm -f /tmp/infisical-drill-restore.sql.gz
echo "Scratch DB and temp dump cleaned up."
'
```

### Step 6: Cross-Validate Production Health

Confirm production was not affected by the drill:

```bash
./bin/ops cap run services.health.status
./bin/ops cap run secrets.projects.status
```

Both must return clean results.

## Post-Drill: Record Evidence

After completing the drill, create a receipt:

```bash
mkdir -p receipts/dr
cat > receipts/dr/INFISICAL_DR_RECERT_$(date -u +%Y%m%d).md << 'RECEIPT'
---
type: dr-recertification
service: infisical
date: YYYY-MM-DD
operator: @ronny
---

# Infisical DR Recertification

## Drill Results

| Check | Result | Notes |
|-------|--------|-------|
| Backup freshness (backup.status) | PASS/FAIL | |
| Dump artifact on NAS | PASS/FAIL | filename: |
| Scratch DB restore | PASS/FAIL | duration: Xs |
| Table count validation | PASS/FAIL | count: |
| Project count validation | PASS/FAIL | count: |
| No psql errors | PASS/FAIL | |
| Restore < 120min (RTO) | PASS/FAIL | actual: |
| Production unaffected | PASS/FAIL | |

## RTO/RPO Assessment

- **RTO target**: 2 hours | **Measured**: ___
- **RPO target**: 24 hours | **Backup age**: ___

## Certification

- **DR procedure accurate**: YES/NO
- **RTO achievable**: YES/NO
- **RPO achievable**: YES/NO
- **Next recert due**: YYYY-MM-DD (quarterly)

## Notes

(Any issues, deviations, or recommendations)
RECEIPT
```

Fill in the template with actual drill results, then commit the receipt.

## Failure Modes

| Failure | Resolution |
|---------|------------|
| NAS unreachable | Relay dump through MacBook (Step 1 fallback) |
| Scratch DB restore errors | Check pg_dump version parity (Postgres container vs dump version) |
| Table count = 0 | Dump may be empty or corrupt — check dump file size, re-dump from production |
| Production health degraded post-drill | Scratch DB is isolated — no production impact expected. Check for resource contention. |
| Restore exceeds 2h | RTO at risk — document and consider: larger VM, SSD storage, parallel restore |
