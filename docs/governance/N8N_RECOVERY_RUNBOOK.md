---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: n8n-recovery
---

# n8n Recovery Runbook

> Recovery procedures for n8n workflow automation on automation-stack (VM 202).
> Related: DR_RUNBOOK.md (site-level), n8n-agent.contract.md (agent governance).

## Service Summary

| Property | Value |
|----------|-------|
| Host | automation-stack (VM 202) |
| Container | n8n |
| URL | https://n8n.ronny.works |
| Port | 5678 |
| Database | automation-postgres (local) |
| Secrets | Infisical `n8n` project (N8N_API_KEY, N8N_ENCRYPTION_KEY) |
| VM Backup | vzdump daily 02:00 (pve) |
| Workflow Snapshots | `/home/automation/backups/n8n-workflows/` daily 03:00, 7-day retention |

## 1. Export Workflows

### Export All (VM-side, no API key needed)

```bash
# On automation-stack (or via SSH):
ssh automation@100.98.70.70

# Export all workflows to a timestamped directory
docker exec n8n n8n export:workflow --backup --output=/tmp/n8n-export/
docker cp n8n:/tmp/n8n-export/. ~/backups/n8n-manual-export/
docker exec n8n rm -rf /tmp/n8n-export
```

### Export All (Spine capability, API-based)

```bash
# From MacBook (requires Infisical auth):
./bin/ops cap run n8n.workflows.list          # List all workflow IDs
./bin/ops cap run n8n.workflows.export <id>   # Export single workflow
```

### Scheduled Snapshots

Daily at 03:00 UTC via cron on automation-stack:
- Script: `/home/automation/scripts/n8n-snapshot-cron.sh`
- Output: `/home/automation/backups/n8n-workflows/<YYYYMMDD-HHMMSS>/`
- Retention: 7 days (auto-pruned)
- Log: `/home/automation/logs/n8n-snapshot.log`
- Status check: `./bin/ops cap run n8n.workflows.snapshot.status`

## 2. Import / Restore Workflows

### Restore All from Snapshot

```bash
ssh automation@100.98.70.70

# Find latest snapshot
ls -1d /home/automation/backups/n8n-workflows/*/ | sort | tail -1

# Copy snapshot into container
SNAPSHOT="/home/automation/backups/n8n-workflows/<YYYYMMDD-HHMMSS>"
docker cp "$SNAPSHOT/." n8n:/tmp/n8n-restore/

# Import all workflows (overwrites existing by ID match)
docker exec n8n n8n import:workflow --separate --input=/tmp/n8n-restore/

# Clean up
docker exec n8n rm -rf /tmp/n8n-restore
```

### Restore Single Workflow (API)

```bash
# From MacBook:
echo "yes" | ./bin/ops cap run n8n.workflows.import /path/to/workflow.json
```

### Restore from vzdump (Full VM Recovery)

If the automation-stack VM is lost:

1. Restore VM 202 from vzdump: `qmrestore /tank/backups/vzdump/dump/vzdump-qemu-202-<latest>.vma.zst 202`
2. Start VM: `qm start 202`
3. Verify n8n: `curl -s http://100.98.70.70:5678/healthz`
4. All workflows and credentials are restored (they live in postgres on the same VM)

## 3. Activate / Deactivate Workflows

### Via Spine Capability

```bash
# List all workflows (shows active/inactive status)
./bin/ops cap run n8n.workflows.list

# Activate a workflow
echo "yes" | ./bin/ops cap run n8n.workflows.activate <workflow_id>

# Deactivate a workflow
echo "yes" | ./bin/ops cap run n8n.workflows.deactivate <workflow_id>
```

### Via n8n CLI (on VM)

```bash
ssh automation@100.98.70.70

# Activate
docker exec n8n n8n update:workflow --id=<workflow_id> --active=true

# Deactivate
docker exec n8n n8n update:workflow --id=<workflow_id> --active=false
```

## 4. Rollback

### Scenario: Bad Workflow Update

1. Find pre-change snapshot: `ls /home/automation/backups/n8n-workflows/`
2. Extract the specific workflow JSON by ID
3. Restore it: `docker exec n8n n8n import:workflow --input=/tmp/<file>.json`

### Scenario: Corrupted Database

1. Stop n8n: `cd /home/automation/stacks/automation && docker compose stop n8n`
2. Restore postgres from vzdump or snapshot:
   - **Option A (vzdump):** Restore full VM from pve backup
   - **Option B (workflow import):** Drop and recreate n8n tables, then import workflows from snapshot
3. Start n8n: `docker compose start n8n`
4. Re-import workflows from latest snapshot (section 2)
5. Re-enter credentials via n8n UI (credentials are encrypted with N8N_ENCRYPTION_KEY)

### Scenario: Accidental Workflow Deletion

1. Identify deleted workflow ID from snapshot manifest
2. Restore single workflow from snapshot JSON (section 2)
3. Re-activate if needed (section 3)
4. Re-enter credentials if they were deleted with the workflow

## 5. Verification Checklist

After any recovery action:

- [ ] `curl -s http://100.98.70.70:5678/healthz` returns 200
- [ ] `./bin/ops cap run n8n.workflows.list` shows expected workflow count (35 as of 2026-02-12)
- [ ] Active workflows are firing (check n8n execution log in UI)
- [ ] `./bin/ops cap run n8n.workflows.snapshot.status` shows fresh snapshot
- [ ] Cron job is installed: `ssh automation@100.98.70.70 'crontab -l | grep n8n'`

## 6. Key Workflows

| Workflow | ID | Status | Purpose |
|----------|------|--------|---------|
| Firefly Expense to Mint OS | upgFmdx32jnsW30J | ACTIVE | Sync expenses from Firefly III |
| Mint OS - Payment Needed SMS | fnLn8rbbqlywELDH | ACTIVE | SMS notifications |
| Mint OS - Quote Sent SMS | hvaELCVzJOtzjan2 | ACTIVE | SMS notifications |
| Mint OS - Ready for Pickup SMS | iTeh76ein7LTnLL4 | ACTIVE | SMS notifications |
| A01 - New Quote Alert | KhuG0MpQ8DZes8q4 | ACTIVE | Internal alerts |
| MintOS/Quotes/QuoteCreated | g8rjjU4hLGVjUQV1 | ACTIVE | Quote event routing |
| Mint OS - Event Router | 3TPTDi1xzs0PXuqX | ACTIVE | Central event routing |
