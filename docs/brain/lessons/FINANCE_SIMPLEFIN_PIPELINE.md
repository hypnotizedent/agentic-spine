---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-simplefin-pipeline
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: SimpleFIN Bank Sync Pipeline

> Operational knowledge for the SimpleFIN-to-Firefly III bank transaction import pipeline running on docker-host (VM 200).

## Overview

SimpleFIN Bridge provides read-only bank data access for 16 accounts across 5 institutions. A daily cron job on docker-host runs a Python importer that fetches transactions from SimpleFIN and creates them in Firefly III via its API.

**Cost:** $1.50/month per connected account (or $15/year flat).

## Architecture

```
SimpleFIN Bridge API (HTTPS)
    ↓ (Basic Auth, Access URL)
simplefin-to-firefly.py (Python CLI on docker-host)
    ↓ (REST API, PAT auth)
Firefly III (port 8090 on docker-host)
    ↓ (webhook: STORE_TRANSACTION)
n8n (VM 202) → Mint OS database
```

## Cron Schedule

- **When:** Daily at 06:00 (docker-host local time)
- **Runner:** `simplefin-daily-sync.sh` wrapper script
- **Lookback:** 7 days by default (configurable via `--days` flag)
- **Notifications:** Microsoft Teams webhook on completion/failure

## Importer Logic (Python CLI)

The importer (`simplefin-to-firefly.py`, ~140 lines) performs:

1. **Fetch** — GET `{SIMPLEFIN_ACCESS_URL}/accounts` with Basic Auth (Access URL encodes credentials)
2. **Filter** — Process only accounts present in the mapping table
3. **Map** — Convert SimpleFIN account IDs to Firefly III account IDs
4. **Classify** — Positive amounts = deposits (revenue), negative = withdrawals (expense)
5. **Deduplicate** — Uses Firefly's `error_if_duplicate_hash` flag; transactions with matching `external_id` (SimpleFIN transaction ID) are skipped
6. **Create** — POST to Firefly III `/api/v1/transactions` with PAT auth

**CLI options:**
- `--days N` — lookback period (default: 7)
- `--dry-run` — fetch and map but don't create transactions
- `--json` — output structured JSON results

## Account Mapping (16 Accounts)

| Institution | Account | SimpleFIN ID Prefix | Firefly ID | Type |
|-------------|---------|---------------------|------------|------|
| Chase | Checking ...7057 | `ACT-chase-checking` | 1 | asset |
| Chase | Savings ...8659 | `ACT-chase-savings` | 2 | asset |
| AmEx | Checking ...8256 | `ACT-amex-checking` | 3 | asset |
| AmEx | Platinum ...01001 | `ACT-amex-plat-01001` | 4 | liability |
| AmEx | Platinum ...02003 | `ACT-amex-plat-02003` | 5 | liability |
| AmEx | Gold ...41002 | `ACT-amex-gold` | 6 | liability |
| AmEx | Blue Biz+ ...61005 | `ACT-amex-bbp` | 7 | liability |
| Citi | Costco ...8693 | `ACT-citi-costco` | 8 | liability |
| Capital One | Spark ...0062 | `ACT-capone-spark` | 9 | liability |
| TD | Checking | `ACT-td-checking` | 10 | asset |
| Chase | CC ...1664 | `ACT-chase-cc-1664` | 11 | liability |
| Chase | CC ...0121 | `ACT-chase-cc-0121` | 12 | liability |

> **Note:** Account IDs above are illustrative. Actual SimpleFIN IDs are opaque strings assigned by the bridge. The mapping is maintained in the importer script's `ACCOUNT_MAP` dictionary.

### Accounts NOT in SimpleFIN (Manual Tracking)

- Square (payment processor — no SimpleFIN connector)
- PayPal Business (use PayPal export instead)
- SBA EIDL loan (check via caweb.sba.gov)
- Equipment loans (statement from lender)

## Secrets (Paths Only)

| Secret | Infisical Path | Usage |
|--------|---------------|-------|
| SimpleFIN Access URL | `/finance-stack/prod/SIMPLEFIN_ACCESS_URL` | Basic Auth for SimpleFIN API |
| Firefly PAT | `/finance-stack/prod/FIREFLY_ACCESS_TOKEN` | API auth for transaction creation |
| Teams Webhook URL | `/finance-stack/prod/TEAMS_WEBHOOK_URL` | Notification delivery |

> Credentials are injected at runtime via Infisical CLI. The sync script calls `infisical run` to populate environment variables before invoking the Python importer.

## Token Lifecycle

SimpleFIN uses a **one-time claim** flow:
1. Generate a setup token on simplefin.org dashboard
2. POST the token to `https://beta-bridge.simplefin.org/simplefin/create` — returns an Access URL
3. The setup token is consumed; the Access URL is permanent (until revoked)
4. Store the Access URL in Infisical (not the setup token)

**If the Access URL expires or is revoked:** Generate a new setup token, re-claim, update Infisical.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| 403 from SimpleFIN | Access URL expired/revoked | Re-claim token (see Token Lifecycle) |
| Duplicate transactions | Lookback overlap with existing | Normal — Firefly deduplicates via `error_if_duplicate_hash` |
| Missing transactions | Account not in mapping | Add to `ACCOUNT_MAP` in importer script |
| Cron not running | docker-host cron service | `systemctl status cron` on docker-host |
| Teams notification missing | Webhook URL expired | Update in Infisical |

## Known Limitations

- SimpleFIN provides 90-day rolling history only — older transactions require manual CSV import
- Balance data is point-in-time, not historical — cannot reconstruct past balances
- No real-time sync — daily batch only (6 AM)
- Some institutions have delayed posting (1-3 business days)
