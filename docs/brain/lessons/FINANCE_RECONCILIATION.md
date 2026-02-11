---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-reconciliation
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: Reconciliation Procedures

> Operational knowledge for reconciling Firefly III transactions with Mint OS, detecting sync gaps, and performing historical backfills.

## Overview

Three reconciliation workflows exist, all running on docker-host (VM 200) as bash scripts that call the Firefly III and Mint OS APIs.

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `reconciliation-report.sh` | Generate discrepancy report: Firefly vs Mint OS | Monthly (manual) |
| `sync-missing.sh` | Sync only missing Firefly transactions to Mint OS | As-needed |
| `backfill-all.sh` | Bulk historical sync with pagination | One-time or recovery |

## Reconciliation Report

### What It Does

1. Fetches all Firefly transactions for a date range (default: current month)
2. Fetches all Mint OS expenses for the same range
3. Compares by `firefly_transaction_id`
4. Produces:
   - **Matched count** — transactions in both systems
   - **Firefly-only count** — transactions missing from Mint OS
   - **Mint-OS-only count** — transactions missing from Firefly (manual entries)
   - **Category breakdown** — syncable vs non-syncable categories
   - **Amount discrepancies** — matching IDs with different amounts

### Syncability Analysis

The report classifies each Firefly transaction as:
- **Syncable** — category is in the 24-item SYNC_CATEGORIES list (see FINANCE_N8N_WORKFLOWS.md)
- **Non-syncable** — personal categories, transfers, etc.
- **Discrepant** — synced but amounts don't match (rare; usually currency rounding)

### Usage

```bash
# Current month
./scripts/firefly/reconciliation-report.sh

# Specific date range
./scripts/firefly/reconciliation-report.sh --start 2026-01-01 --end 2026-01-31

# Output as JSON (for automation)
./scripts/firefly/reconciliation-report.sh --json
```

### Required Environment

| Variable | Source | Purpose |
|----------|--------|---------|
| `FIREFLY_PAT` | Infisical | Firefly API auth |
| `MINTOS_API_URL` | Hardcoded (`https://mint.ronny.works/api`) | Mint OS API base |
| `MINTOS_API_KEY` | Infisical | Mint OS API auth |

## Sync Missing Transactions

### What It Does

1. Fetches all Firefly transactions for a date range
2. For each, checks if `firefly_transaction_id` exists in Mint OS
3. If missing AND category is syncable, triggers the n8n webhook to create it
4. Reports: created count, skipped count, error count

### Usage

```bash
# Sync missing from last 30 days
./scripts/firefly/sync-missing.sh --days 30

# Sync missing for specific month
./scripts/firefly/sync-missing.sh --start 2026-01-01 --end 2026-01-31

# Dry run (check what would be synced)
./scripts/firefly/sync-missing.sh --dry-run
```

### Idempotency

- The n8n workflow checks for existing `firefly_transaction_id` before inserting
- Running `sync-missing.sh` multiple times is safe — duplicates are skipped
- The script also pre-checks before calling the webhook to reduce unnecessary API calls

## Bulk Historical Backfill

### What It Does

1. Fetches ALL Firefly transactions with pagination (50 per page)
2. Filters to syncable categories only
3. For each, calls the n8n webhook endpoint
4. Tracks progress: page number, total processed, created, skipped, errors
5. Respects rate limits with configurable delay between requests

### Usage

```bash
# Full backfill (all time)
./scripts/firefly/backfill-all.sh

# Backfill with rate limiting (500ms between requests)
./scripts/firefly/backfill-all.sh --delay 500

# Backfill specific date range
./scripts/firefly/backfill-all.sh --start 2025-01-01 --end 2025-12-31
```

### When to Use

- After initial Firefly setup (bulk import of historical data)
- After fixing a sync outage (n8n was down, webhook was disabled)
- After adding new syncable categories (existing transactions need backfill)
- After database restore (Mint OS expenses table was reset)

### Pagination Details

- Firefly API returns 50 transactions per page by default
- Script follows `meta.pagination.total_pages` to iterate all pages
- Progress is logged: `Page X/Y: processed N, created M, skipped S, errors E`

## Failure Modes

| Failure | Symptom | Recovery |
|---------|---------|----------|
| n8n webhook down | sync-missing/backfill return 502/503 | Wait for n8n restart; re-run |
| Firefly API rate limit | 429 responses | Increase `--delay` parameter |
| Category mapping mismatch | Transaction synced with wrong category | Fix category in n8n Parse & Filter node; re-sync affected transactions |
| Duplicate detection failure | Duplicate expenses in Mint OS | Query `SELECT * FROM expenses WHERE firefly_transaction_id = X`; delete duplicate |
| Mint OS API down | sync operations fail silently | Check Mint OS container health; re-run after recovery |

## Reconciliation Schedule

| Task | Frequency | Trigger |
|------|-----------|---------|
| Run reconciliation report | Monthly (1st of month) | Manual |
| Sync missing transactions | After reconciliation report shows gaps | Manual |
| Full backfill | After major outage or DB restore | Manual (rare) |
| Verify opening balances | Quarterly | Manual (Firefly still needs opening balances set) |

## Known Issues

| Issue | Impact | Status |
|-------|--------|--------|
| Opening balances not set in Firefly | Account balance reports are incorrect | Pending manual setup |
| Reconciliation script doesn't handle pagination for Mint OS | May miss expenses if Mint OS has > 100 entries | Low priority (current volume is manageable) |
| No automated reconciliation scheduling | Relies on manual execution | Could add to cron in future |
