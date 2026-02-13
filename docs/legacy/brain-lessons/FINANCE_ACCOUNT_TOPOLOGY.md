---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-account-topology
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: Account Topology

> Master inventory of financial accounts tracked in Firefly III, their business function, and import method.

## Account Summary

| Type | Count | Import Method |
|------|-------|---------------|
| Bank accounts (asset) | 3 | SimpleFIN auto-sync |
| Credit cards (liability) | 8 | SimpleFIN auto-sync (6) + manual CSV (2) |
| Loans (liability) | 4 | Manual entry |
| Payment processors | 2 | Manual CSV export |
| Fixed assets | 4 | Manual entry (depreciation) |
| **Total** | **21** | |

## Bank Accounts (Assets)

| Account | Last 4 | Institution | Firefly Type | Import | Business Use |
|---------|--------|-------------|-------------|--------|--------------|
| Business Checking | 7057 | Chase | asset | SimpleFIN | Primary operating account; payroll, vendor payments, revenue deposits |
| Business Savings | 8659 | Chase | asset | SimpleFIN | Reserve fund |
| Checking | 8256 | American Express | asset | SimpleFIN | Secondary operating; AmEx ecosystem |

## Credit Cards (Liabilities)

| Account | Last 4 | Institution | Firefly Type | Import | Business Use |
|---------|--------|-------------|-------------|--------|--------------|
| Chase CC | 1664 | Chase | liability | Manual CSV | Mixed personal/business; requires category filtering |
| Chase CC | 0121 | Chase | liability | Manual CSV | Mixed personal/business |
| Platinum | 01001 | American Express | liability | SimpleFIN | Business travel, large purchases |
| Platinum | 02003 | American Express | liability | SimpleFIN | Business supplementary |
| Gold | 41002 | American Express | liability | SimpleFIN | Everyday business expenses |
| Blue Business Plus | 61005 | American Express | liability | SimpleFIN | 2x points on business purchases |
| Costco | 8693 | Citi | liability | SimpleFIN | Warehouse supplies, fuel |
| Spark | 0062 | Capital One | liability | SimpleFIN | Cash-back business card |

> **Note:** Chase CCs (1664, 0121) are not in SimpleFIN — these require manual CSV download from chase.com monthly.

## Loans (Liabilities)

| Account | Lender | Balance (approx) | Firefly Type | Import | Notes |
|---------|--------|-------------------|-------------|--------|-------|
| Equipment Loan | Lotus Holland | ~$1,200 | liability | Manual | Embroidery machine financing; near payoff |
| SBA EIDL | SBA | ~$94,700 | liability | Manual | COVID-era disaster loan; 30-year term, 3.75% |
| Car Note | Lender TBD | ~$17,900 | liability | Manual | Business vehicle |
| Line of Credit | American Express | Variable | liability | Manual | Revolving; draw as needed |

> Loan balances are checked via: caweb.sba.gov (EIDL), lender portals (equipment, auto), AmEx online (LOC).

## Payment Processors

| Processor | Import Method | Business Use |
|-----------|---------------|-------------|
| Square | Manual CSV from squareup.com | Point-of-sale transactions, in-person sales |
| PayPal Business | Manual CSV from paypal.com | Online payments, invoicing |

> Neither Square nor PayPal has a SimpleFIN connector. Import is monthly CSV download.

## Fixed Assets (for Depreciation Tracking)

| Asset | Value | Firefly Type | Notes |
|-------|-------|-------------|-------|
| Geo Knight Heat Press | $374 | asset | Production equipment |
| M&R Challenger 11 | ~$15,000 | asset | 6-head embroidery machine |
| Computer Equipment | ~$3,600 | asset | Workstations, servers |

> Fixed assets are tracked for depreciation schedule purposes. No transaction import needed.

## Statement Import Schedule

| Frequency | Source | Accounts | Method |
|-----------|--------|----------|--------|
| Daily (auto) | SimpleFIN | 12 accounts (3 bank + 6 CC + 3 other) | Cron job at 06:00 |
| Monthly (manual) | chase.com | Chase CCs (1664, 0121) | CSV download → Data Importer |
| Monthly (manual) | squareup.com | Square | CSV download → Data Importer |
| Monthly (manual) | paypal.com | PayPal Business | CSV download → Data Importer |
| Quarterly (manual) | caweb.sba.gov | SBA EIDL | Balance check, manual entry |
| As-needed | Lender portals | Equipment loan, car note | Balance update |

## Reconciliation Notes

- **Opening balances** are not yet set in Firefly III — this causes discrepancies in account balance reports
- **Business vs personal** separation: Chase CCs (1664, 0121) contain mixed transactions; only business-category transactions should be synced to Mint OS
- **Mint OS sync** covers 24 business expense categories via n8n webhook (see FINANCE_N8N_WORKFLOWS.md)
- **Reconciliation cadence:** Monthly, using `reconciliation-report.sh` (see FINANCE_RECONCILIATION.md)

## Secrets (Paths Only)

| Secret | Infisical Path | Usage |
|--------|---------------|-------|
| SimpleFIN Access URL | `/finance-stack/prod/SIMPLEFIN_ACCESS_URL` | Auto-sync for 12 accounts |
| Firefly PAT | `/finance-stack/prod/FIREFLY_ACCESS_TOKEN` | API access for all import methods |
| Data Importer client ID | `/finance-stack/prod/DATA_IMPORTER_CLIENT_ID` | OAuth for manual CSV import |
