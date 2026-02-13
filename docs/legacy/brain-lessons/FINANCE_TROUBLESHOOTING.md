---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-troubleshooting
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: Troubleshooting Guide

> Quick diagnostics and resolution procedures for finance stack issues on finance-stack (VM 211).

## Quick Diagnostics

Run these first to assess overall health:

```bash
# Check all containers
docker compose -f /opt/stacks/finance/docker-compose.yml ps

# Check logs (last 50 lines)
docker compose -f /opt/stacks/finance/docker-compose.yml logs --tail=50

# Check disk usage
df -h /opt/stacks/finance/data/

# Check Firefly API
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $FIREFLY_PAT" \
  https://firefly.ronny.works/api/v1/about

# Check Paperless API
curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Token $PAPERLESS_TOKEN" \
  https://docs.ronny.works/api/documents/

# Check PostgreSQL
docker exec finance-postgres pg_isready

# Check Redis
docker exec finance-redis redis-cli ping
```

## Common Issues

### 1. SimpleFIN Sync Failures

**Symptom:** No new transactions appearing in Firefly after daily sync.

| Check | Command | Expected |
|-------|---------|----------|
| Cron running | `crontab -l \| grep simplefin` | Entry at `0 6 * * *` |
| Last cron run | `tail -20 /var/log/simplefin-sync.log` | Recent run with transaction count |
| SimpleFIN API | `curl -s $SIMPLEFIN_ACCESS_URL/accounts` | JSON with account data |
| Firefly API | `curl -H "Auth..." .../api/v1/about` | 200 OK |

**Fixes:**
- **403 from SimpleFIN:** Access URL expired. Re-claim token (see FINANCE_SIMPLEFIN_PIPELINE.md → Token Lifecycle)
- **Connection timeout:** SimpleFIN service may be down. Check status at simplefin.org. Retry in 1 hour.
- **No new transactions:** Normal if all transactions in lookback period already imported (dedup by `external_id`)
- **Cron not firing:** `systemctl status cron` on finance-stack; verify cron daemon is active

### 2. Paperless OCR Quality

**Symptom:** Scanned documents have garbled text, wrong extraction, or missing fields.

**Root causes:**
- **Thermal receipts** — low contrast ink fades quickly; Tesseract OCR struggles with degraded thermal paper
- **Rotated/skewed images** — Paperless auto-rotates but sometimes fails
- **Low resolution** — phone camera scans below 300 DPI

**Fixes:**
- Scan at 300+ DPI in good lighting
- For thermal receipts: photograph immediately (before fading); consider flatbed scanner
- Re-OCR: `docker exec paperless-ngx document_retagger --inbox-only`
- Manual tag: add `needs-review` tag for receipts that fail OCR

### 3. Firefly Connection / Performance Issues

**Symptom:** Firefly III web UI slow, 500 errors, or API timeouts.

| Check | Command | Expected |
|-------|---------|----------|
| Container status | `docker compose ps firefly-iii` | "Up" |
| Container logs | `docker compose logs --tail=100 firefly-iii` | No PHP fatal errors |
| PostgreSQL | `docker exec finance-postgres pg_isready` | "accepting connections" |
| Redis | `docker exec finance-redis redis-cli ping` | "PONG" |
| Memory | `docker stats --no-stream` | Firefly < 512MB |

**Fixes:**
- **APP_KEY missing/wrong:** `docker compose logs firefly-iii | grep APP_KEY` — must be exactly 32 characters. Regenerate: `docker exec firefly-iii php artisan key:generate --show`
- **Database connection refused:** `docker compose restart postgres` → wait 10s → `docker compose restart firefly-iii`
- **Redis connection refused:** `docker compose restart redis` → `docker compose restart firefly-iii`
- **Out of memory:** Check `docker stats`; may need to increase VM memory or stop unused containers
- **Slow queries:** `docker exec finance-postgres psql -U firefly -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"` — look for long-running queries

### 4. n8n Workflow Issues

**Symptom:** Expenses not appearing in Mint OS after Firefly transaction creation.

| Check | Command | Expected |
|-------|---------|----------|
| Webhook active | Firefly Admin → Webhooks | STORE_TRANSACTION webhook enabled |
| n8n reachable | `curl -s https://n8n.ronny.works/healthz` | 200 OK |
| Workflow active | n8n UI → Firefly Expense to Mint OS | Toggle ON |
| Execution log | n8n UI → Executions | Recent successful executions |

**Fixes:**
- **Webhook disabled in Firefly:** Re-enable in Firefly Admin → Webhooks
- **n8n down:** SSH to VM 202; `docker compose -f ~/stacks/automation/docker-compose.yml restart n8n`
- **Category not syncing:** Check if category is in SYNC_CATEGORIES list in the Parse & Filter code node
- **Duplicate expense:** Check Mint OS DB: `SELECT * FROM expenses WHERE firefly_transaction_id = N` — idempotency check should prevent this

### 5. Data Importer Issues

**Symptom:** CSV import fails or produces wrong transaction data.

**Fixes:**
- **401 Unauthorized:** Firefly PAT expired or wrong. Update in `.env` from Infisical.
- **Import mapping wrong:** Access Data Importer UI at `http://100.76.153.100:8091` (local only); adjust column mapping
- **Duplicate imports:** Data Importer uses `error_if_duplicate_hash` — duplicates are rejected. Check Firefly logs for "duplicate" messages.

## Service Restart Commands

```bash
# Restart single service
docker compose -f /opt/stacks/finance/docker-compose.yml restart <service-name>

# Restart all services (graceful)
docker compose -f /opt/stacks/finance/docker-compose.yml restart

# Full stop and start (if restart doesn't fix)
docker compose -f /opt/stacks/finance/docker-compose.yml down
docker compose -f /opt/stacks/finance/docker-compose.yml up -d

# Nuclear option: recreate containers from scratch
docker compose -f /opt/stacks/finance/docker-compose.yml down
docker compose -f /opt/stacks/finance/docker-compose.yml up -d --force-recreate
```

> **Warning:** `down` stops containers but preserves volumes. Data in `/opt/stacks/finance/data/` is safe. Only `down -v` would remove volumes (NEVER use `-v` in production).

## API Quick Reference

### Firefly III

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/about` | GET | Bearer PAT | Health check |
| `/api/v1/transactions` | GET | Bearer PAT | List transactions |
| `/api/v1/transactions` | POST | Bearer PAT | Create transaction |
| `/api/v1/accounts` | GET | Bearer PAT | List accounts |
| `/api/v1/categories` | GET | Bearer PAT | List categories |

Base URL: `https://firefly.ronny.works`

### Paperless-ngx

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/documents/` | GET | Token | List documents |
| `/api/documents/{id}/` | GET | Token | Get document |
| `/api/documents/post_document/` | POST | Token | Upload document |
| `/api/tags/` | GET | Token | List tags |

Base URL: `https://docs.ronny.works`

## Escalation

If the above steps don't resolve the issue:

1. Check Grafana for finance-stack metrics (if observability is configured)
2. SSH to finance-stack and check system resources: `htop`, `df -h`, `free -h`
3. Check Docker daemon: `systemctl status docker`
4. Review recent changes: was compose file modified? Was a container updated?
5. Last resort: restore from backup (see FINANCE_BACKUP_RESTORE.md)
