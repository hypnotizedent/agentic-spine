---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-n8n-workflows
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
extraction: Move A (doc-only snapshot)
---

# Finance: n8n Workflow Architecture

> Operational knowledge for the n8n-based automation workflows connecting Firefly III, Paperless-ngx, and Mint OS.

## Overview

Two n8n workflows automate finance data flow. They run on the automation-stack (VM 202, Tailscale 100.98.70.70). n8n is accessible at `https://n8n.ronny.works`.

| Workflow | ID | Trigger | Status |
|----------|-----|---------|--------|
| Firefly Expense to Mint OS | `upgFmdx32jnsW30J` | Webhook (Firefly STORE_TRANSACTION) | ACTIVE |
| Receipt to Firefly Transaction | `8ldgXKtdfcPJcAxB` | Schedule (every 5 min) | BLOCKED (IF node bug) |

## Workflow 1: Firefly Expense to Mint OS (ACTIVE)

### Dataflow

```
Firefly III (finance-stack)
  ↓ webhook POST on STORE_TRANSACTION
n8n webhook trigger (VM 202)
  ↓ parse + filter (24 business categories only)
  ↓ idempotency check (Postgres: firefly_transaction_id exists?)
  ↓ vendor lookup (Postgres: vendors table)
  ↓ prepare insert payload
Mint OS database (Postgres on docker-host)
  ↓ INSERT into expenses table
n8n respond (HTTP 200 + expense_id)
```

### Node Pipeline

1. **Webhook Trigger** — Receives POST from Firefly III at `/webhook/firefly/expense`
2. **Parse & Filter** — JavaScript code node that:
   - Extracts transaction fields (amount, description, category, date, payee)
   - Checks if the Firefly category is in the 24-item `SYNC_CATEGORIES` list
   - Maps Firefly category names to Mint OS category names via `CATEGORY_MAP`
   - Resolves vendor name via `VENDOR_MAP` (10 static entries)
   - Sets `skip = true` for non-syncable categories
3. **Should Sync?** — IF node: skip if `skip === true`
4. **Idempotency Check** — SQL query: `SELECT id FROM expenses WHERE firefly_transaction_id = $1`
5. **Not Yet Synced?** — IF node: proceed only if `existing_id === -1` (not found)
6. **Vendor Lookup** — SQL: `SELECT id FROM vendors WHERE name ILIKE $1`
7. **Prepare Insert** — Combines parsed data with vendor lookup result
8. **Insert Expense** — Conditional INSERT (with or without `vendor_id`)
9. **Respond Success** — Returns `{ expense_id, action, synced_at }`

### Syncable Categories (24)

These Firefly III categories sync to Mint OS. All others are skipped.

| Firefly Category | Mint OS Category | Notes |
|-----------------|------------------|-------|
| Blank Apparel | Blanks/Garments | Core business |
| Subcontracted Work | Outsourced Work | Embroidery vendors |
| Shipping & Freight | Shipping | UPS/FedEx/USPS |
| Equipment & Supplies | Equipment | Production equipment |
| Software & Subscriptions | Software | SaaS tools |
| Advertising & Marketing | Marketing | Ads, signage |
| Auto - Gas | Vehicle/Gas | Fuel |
| Auto - Insurance | Vehicle/Insurance | Auto coverage |
| Auto - Maintenance | Vehicle/Maintenance | Repairs |
| Bank & Finance Fees | Bank Fees | Service charges |
| Rent & Lease | Rent | Shop lease |
| Utilities | Utilities | Electric, water, internet |
| Insurance - Business | Insurance | General business |
| Office Supplies | Office | Paper, ink, misc |
| Phone & Internet | Communications | Cell, ISP |
| Professional Services | Professional | Legal, accounting |
| Taxes & Licenses | Taxes | Business taxes |
| Travel & Meals | Travel | Business travel |
| Contract Labor | Contract Labor | 1099 workers |
| Repairs & Maintenance | Maintenance | Building/equipment |
| Interest - Loans | Interest | Loan payments |
| Depreciation | Depreciation | Asset depreciation |
| Miscellaneous | Other | Uncategorized |
| Owner's Draw | Owner's Draw | Distributions |

### Vendor Mapping (Static in n8n)

| Firefly Payee | Vendor ID | Mint OS Vendor |
|---------------|-----------|----------------|
| Embroidery Monkeys | 1 | Embroidery Monkeys |
| UPS | 2 | UPS |
| S&S Activewear | 3 | S&S Activewear |
| FedEx | 4 | FedEx |
| SanMar | 5 | SanMar |
| USPS | 6 | USPS |
| Adobe | 7 | Adobe |
| Intuit | 8 | Intuit |
| Shopify | 9 | Shopify |
| Google | 10 | Google |

> Additional vendors are resolved via database lookup (`vendors` table). If no match, `vendor_id` is NULL.

### Firefly Webhook Configuration

- **Webhook URL:** `https://n8n.ronny.works/webhook/firefly/expense`
- **Trigger:** `STORE_TRANSACTION` (fires on every new transaction)
- **Auth:** No additional auth (n8n webhook is public but URL is secret)
- **Configured in:** Firefly III Admin → Webhooks

## Workflow 2: Receipt to Firefly Transaction (BLOCKED)

### Dataflow (Intended)

```
Paperless-ngx (finance-stack)
  ↓ schedule trigger (every 5 min)
n8n (VM 202) polls Paperless API for unprocessed receipts
  ↓ fetch document details + OCR content
  ↓ Claude API extracts structured data (vendor, amount, date, category)
  ↓ parse response + confidence check
  ↓ route: auto-create OR needs-manual-review
Firefly III (finance-stack)
  ↓ create transaction via API
Paperless-ngx: tag as "linked" or "needs-review"
```

### Current Status: BLOCKED

**Root cause:** n8n IF node routing bug — all conditions route to the TRUE path regardless of the actual condition value. This means receipts that should be flagged for manual review are auto-created instead.

**Impact:** Workflow is disabled to prevent incorrect transaction creation.

**Resolution path:** Awaiting n8n IF node fix or workaround (replace IF with Code node for routing logic).

### Key Integration Points

- **Paperless API:** `https://docs.ronny.works/api/documents/`
- **Tag filtering:** `tags__id__all=1` (receipt tag), `tags__id__none=11,12` (exclude linked, needs-review)
- **Claude API:** `claude-sonnet-4-20250514` for receipt OCR extraction
- **Confidence threshold:** Auto-create if vendor recognized + amount > $0.01 + date valid

## Category Mapping Configuration

The canonical category mapping lives in a JSON config file deployed with Mint OS:

**Location:** `mint-os/config/firefly-category-map.json` (v1.1, updated 2026-01-13)

**Structure:**
```json
{
  "version": "1.1",
  "syncable_categories": 25,
  "skip_categories": 17,
  "mappings": [ { "firefly": "...", "mintOS": "...", "syncable": true } ],
  "vendor_map": { "static": [...], "database_fallback": true },
  "sync_rules": {
    "min_amount_threshold": 0.01,
    "auto_link_date_range_days": 14
  }
}
```

## Secrets (Paths Only)

| Secret | Infisical Path | Usage |
|--------|---------------|-------|
| n8n Encryption Key | `/n8n/prod/N8N_ENCRYPTION_KEY` | Workflow credential encryption |
| Paperless API Token | `/finance-stack/prod/PAPERLESS_API_TOKEN` | Paperless document access |
| Firefly PAT | `/finance-stack/prod/FIREFLY_ACCESS_TOKEN` | Transaction creation |
| Anthropic API Key | `/n8n/prod/ANTHROPIC_API_KEY` | Claude receipt extraction |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Expenses not syncing to Mint OS | Webhook disabled in Firefly | Re-enable in Firefly Admin → Webhooks |
| Duplicate expenses in Mint OS | Idempotency check failed | Check `firefly_transaction_id` column in expenses table |
| Wrong category mapping | Category not in SYNC_CATEGORIES | Add to n8n Parse & Filter code node |
| Vendor shows as NULL | Payee name doesn't match vendor table | Add to static VENDOR_MAP or vendors DB table |
| Receipt workflow creating bad transactions | IF node bug | Keep workflow disabled; use manual receipt entry |

## Governance Notes

- **n8n workflow exports** must be saved to repo after any change (per n8n CONTRACT.md)
- The workflow JSON is the only portable backup — running n8n stores workflows in its database, but that's a single point of failure
- 10 additional live workflows in n8n are NOT yet exported to any repo (see n8n CONTRACT.md for list)
