---
status: historical
owner: "@ronny"
last_verified: 2026-02-13
verification_method: table inventory reconciliation (#460)
scope: mint-os
github_issue: "#460"
sources: []
---

<!-- Reviewed 2026-02-13: structure confirmed current. -->

> **⚠️ Historical Capture (Mint OS)**
>
> This document is a **point-in-time reference** of the Mint OS infrastructure schema,
> imported from the workbench monolith for historical context. It is **not spine-governed**
> and may be stale. The spine does not own Mint OS database tables, MinIO buckets, or
> Mint OS container configs.
>
> **Do not execute commands or act on paths in this document from a spine session.**
> If you need current Mint OS answers, treat workbench as **read-only reference**
> and search by path using the canonical pattern in
> [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md) (no RAG, no CWD change).
>
> If the result influences spine work, record a receipt:
> `./bin/ops run --inline "External reference consulted: <what> (paths + findings)"`.
>
> **Current authority:** See [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) for spine-native
> SSOTs. See [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) for external reference policy.

# Mint OS Infrastructure Map (Historical Reference)

> **⚠️ Historical Context Only**
>
> The claims below were accurate when imported from workbench. They describe
> workbench-owned infrastructure, not spine authority. For current truth,
> query workbench RAG or check workbench docs directly.
>
> This document is preserved for reference during audits and migrations.

---

# Mint OS Infrastructure Map

> **Last Updated:** January 14, 2026

---

## ⚠️ CRITICAL SOPs - READ BEFORE ACTING

| Task | SOP Document | Summary |
|------|--------------|---------|
| **Creating Quotes** | _(historical: was `docs/SOPs/QUOTE_CREATION_SOP.md` in legacy mint-os)_ | Orders + line_items + imprints + junction + mockups - ALL REQUIRED |
| **Artwork/Files** | _(historical: was `docs/SOPs/QUOTE_CREATION_SOP.md` in legacy mint-os)_ | See ARTWORK FILE CLASSIFICATION section |
| **Ronny's Actual Workflow** | `docs/ARTWORK_WORKFLOW.md` | How files ACTUALLY move: OneDrive → MinIO mapping, folder structure, naming |

**Common Agent Failures:**
- Creating quotes without imprints/mockups - SOP is MANDATORY
- Putting all files in `production_files` - USE CORRECT TABLE per SOP

---

## File Storage Policy (2026-01-13)

**Database table = classification. URL/bucket = just storage location.**

| Table | Purpose | URL Allowed |
|-------|---------|-------------|
| `customer_artwork` | Files customer sent us | Any URL |
| `line_item_mockups` | Garment images (SanMar CDN, etc.) | Any URL |
| `imprint_mockups` | Decoration previews (stitch PNG, spec PDF) | Any URL |
| `production_files` | Machine files only (DST, EMB, AI) | Any URL |

**❌ DEPRECATED:** URL pattern CHECK constraints from `2026-01-10-file-storage-governance.sql`
- These were documented but never applied
- Do NOT enforce bucket ↔ table coupling
- Agents can reclassify files by moving DB records without MinIO operations

---

## Visual ID Format

| Range | Purpose | Format |
|-------|---------|--------|
| 1-13999 | Legacy Printavo orders | Numeric |
| 20000-29999 | Reserved (test/dev) | Numeric |
| **30000+** | **New Mint OS orders** | **Numeric (30001, 30002, ...)** |

**❌ DEPRECATED:** `J-2026-XXXX` format - DO NOT USE (Issue #206)

**Next available:** Query `SELECT MAX(CAST(visual_id AS INTEGER)) + 1 FROM orders WHERE visual_id ~ '^[0-9]+$';`

---

## Quick Reference

| What | Where | How to Check |
|------|-------|--------------|
| PostgreSQL | `docker-host:mint-os-postgres` | `ssh docker-host "docker exec mint-os-postgres psql -U mint_os_admin -d mint_os"` |
| MinIO | `docker-host:minio` | `ssh docker-host "docker exec minio mc ls local/"` |
| Redis | `docker-host:mint-os-redis` | `ssh docker-host "docker exec mint-os-redis redis-cli ping"` |
| API | `docker-host:mint-os-dashboard-api` | `curl https://mintprints-api.ronny.works/health` |
| Admin UI | Cloudflare Pages | `https://admin.mintprints.co` |

> ⚠️ **Note:** MinIO is now standalone infrastructure in `infrastructure/storage/`. Container name changed from `mint-os-minio` to `minio`. For current service topology, see `docs/governance/SERVICE_REGISTRY.yaml`.

---

## APP ECOSYSTEM

> **Updated:** January 21, 2026 - Added artwork app, fixed deploy methods

### Docker Apps (via Cloudflare Tunnel)

| App | Repo Path | Container | Deploy Method | URL |
|-----|-----------|-----------|---------------|-----|
| **API** | `apps/api/` | `mint-os-dashboard-api` | GitHub Actions → rsync → docker | `https://mintprints-api.ronny.works` |
| **Job Estimator** | `apps/job-estimator/` | `mint-os-job-estimator` | GitHub Actions → rsync → docker | Internal :3001 |
| **Admin UI** | `apps/admin/` | `mint-os-admin` | GitHub Actions → build → rsync → docker | `https://admin.mintprints.co` |
| **Customer Portal** | `mint-modules/quote-page` | `quote-page` | Manual compose (docker-host) | `https://customer.mintprints.co` |
| **Production Portal** | `apps/production/` | `mint-os-production` | GitHub Actions → build → rsync → docker | `https://production.mintprints.co` |
| **Supplier Sync** | `scripts/suppliers/` | - | Manual rsync | Cron (disabled) |

### Cloudflare Pages Apps (static hosting)

| App | Repo Path | Pages Project | URL | Status |
|-----|-----------|---------------|-----|--------|
| **Artwork Browser** | `apps/artwork/` | `mint-os-artwork` | `https://artwork.mintprints.co` | ✅ LIVE (read-only browser, no upload) |
| **Shipping** | `apps/shipping/` | `mint-os-shipping` | `https://shipping.mintprints.co` | ✅ LIVE |
| **Suppliers** | `apps/suppliers/` | `mint-os-suppliers` | `https://suppliers.mintprints.co` | ✅ LIVE |

### MinIO / File Storage URLs

| URL | Points To | Status | Notes |
|-----|-----------|--------|-------|
| `files.ronny.works/{bucket}/` | MinIO (via Cloudflare Tunnel) | ✅ Working | Root `/` returns AccessDenied (expected MinIO behavior) |
| `files.mintprints.co/{bucket}/` | MinIO (via Cloudflare Tunnel) | ✅ Working | Same — must include bucket path |

**Working bucket URLs (read-only public access):**
```
https://files.ronny.works/client-assets/          ← WIP + customer folders
https://files.ronny.works/customer-artwork/       ← Customer uploads
https://files.ronny.works/production-files/       ← Machine-ready files (DST, AI)
https://files.ronny.works/line-item-mockups/      ← Garment mockups
https://files.ronny.works/imprint-mockups/        ← Print previews
https://files.ronny.works/invoice-pdfs/           ← Generated invoices
https://files.ronny.works/suppliers/              ← Product images
```

> **Uploads:** files-api (mint-modules/artwork) provides presigned upload URLs via
> `POST /api/v1/upload/presigned`. Direct browser uploads to MinIO. See SERVICE_REGISTRY.yaml.

### Extracted Modules (mint-modules)

| App | Source | Container | URL | Status |
|-----|--------|-----------|-----|--------|
| **files-api** | `mint-modules/artwork` | `files-api` | `docker-host:3500` | ✅ ACTIVE |
| **quote-page** | `mint-modules/quote-page` | `quote-page` | `https://customer.mintprints.co` | ✅ ACTIVE |

**Deploy Cloudflare Pages Apps:**

> **Legacy example:** These commands reference the old ronny-ops layout. The spine uses `ops cap run secrets.exec` instead. See [SECRETS_POLICY.md](SECRETS_POLICY.md).

```bash
export CLOUDFLARE_API_TOKEN=$(./ops/tools/infisical-agent.sh get infrastructure prod CLOUDFLARE_API_TOKEN)
export CLOUDFLARE_ACCOUNT_ID=$(./ops/tools/infisical-agent.sh get infrastructure prod CLOUDFLARE_ACCOUNT_ID)
cd mint-os/apps/artwork && pnpm build && npx wrangler pages deploy dist/ --project-name=mint-os-artwork
```

### Sync Commands

> **Legacy example:** These commands reference the old ronny-ops layout. The spine uses `ops cap run secrets.exec` instead. See [SECRETS_POLICY.md](SECRETS_POLICY.md).

```bash
# Sync job-estimator code to docker-host
rsync -avz --exclude 'node_modules' --exclude 'build' \
  /Users/ronnyworks/code/workbench/mint-os/apps/job-estimator/ \
  docker-host:~/stacks/mint-os/job-estimator/

# Sync supplier scripts to docker-host
rsync -avz --delete \
  /Users/ronnyworks/code/workbench/mint-os/scripts/suppliers/ \
  docker-host:~/stacks/mint-os/scripts/suppliers/

# Rebuild after sync
ssh docker-host "cd ~/stacks/mint-os && docker compose up -d --build job-estimator"
```

### Container Health Check

```bash
ssh docker-host "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep mint-os"
```

### ❌ Deleted/Legacy (DO NOT USE)

- `apps/dashboard-kanban/` - Deleted Jan 11, 2026
- Container `mint-os-kanban` - Killed Jan 11, 2026
- Old scripts: `sanmar-import.py`, `sanmar-sync.py`

---

## ARCHITECTURE DEEP DIVES

> These architecture docs are workbench-scoped (mint-os application layer).
> They do not exist in agentic-spine. See workbench repo if needed.

| Doc | Purpose | Related Issues |
|-----|---------|----------------|
| MONEY_FLOWS.md | Pricing, finance, supplier costs (workbench) | #416, #417, #418 |
| PRICING_DATA_LAYER.md | Schema & data flow (workbench) | #417 |
| PRICING_UI_INTEGRATION.md | UI touchpoints (workbench) | #417 |
| DATABASE_SCHEMA.md | Full schema reference (workbench) | All |

---

## Secrets

**Single Source of Truth:** Infisical at `secrets.ronny.works`

```bash
# Get a secret (canonical path from spine; vendored at scripts/agents/ in workbench)
./ops/tools/infisical-agent.sh get mint-os-api prod SECRET_NAME

# List all secrets
./ops/tools/infisical-agent.sh list mint-os-api prod
```

---

## DATABASE SCHEMA (65 Tables)

> **Cleaned:** January 11, 2026 - Reduced from 79 to 38 tables (Issue #271)
> **Updated:** January 25, 2026 - Table inventory reconciled (#460, #608)
> **Evidence:** `docs/governance/evidence/608_db_inventory_2026-01-25.md`
> **Live count:** 65 tables (verified via `psql \dt`)
> **Updated:** January 14, 2026 - Added quote_templates, customer_tag_types, customer_tags, companies (Issues #177, #344, #324)
> **Updated:** January 21, 2026 - Added shipping_labels table (#465)
> **Updated:** January 22, 2026 - Added job_photos, pending_jobs tables (#538, #539)

### Core Business

| Table | Rows | Purpose |
|-------|------|---------|
| `orders` | 12,918 | All orders and quotes |
| `customers` | 3,332 | Customer records |
| `line_items` | 43,098 | Order line items (garments) |
| `imprints` | 6,394 | Decoration specifications |
| `imprints_line_item_lnk` | 20,855 | Junction: imprints ↔ line_items |
| `payments` | 12,705 | Payment records |
| `fees` | 5,490 | Order fees |

### File Storage

| Table | Rows | Purpose |
|-------|------|---------|
| `production_files` | 13,727 | Print-ready artwork |
| `line_item_mockups` | 18,112 | Garment visualizations |
| `imprint_mockups` | 3,852 | Print close-ups |
| `customer_artwork` | 356 | Customer uploads |

### Production

| Table | Rows | Purpose |
|-------|------|---------|
| `production_steps` | ~23 | Workflow steps |
| `stations` | ~5 | Production stations |

### Time/Payroll

| Table | Rows | Purpose |
|-------|------|---------|
| `employees` | ~14 | Staff records |
| `time_entries` | ~639 | Timesheets |
| `time_entry_breaks` | ~5 | Break tracking |
| `pay_periods` | ~26 | Payroll periods |

### Products/Pricing

| Table | Rows | Purpose |
|-------|------|---------|
| `products` | 3,844 | Curated product catalog |
| `sanmar_products` | 156,063 | SanMar supplier catalog |
| `price_matrices` | ~3 | Pricing tables |
| `customer_pricing_rules` | ~6 | Customer discounts |

### Financials

| Table | Rows | Purpose |
|-------|------|---------|
| `expenses` | 292 | Expense records |
| `expense_categories` | ~13 | Expense types |
| `vendors` | ~5 | Vendor records |
| `suppliers` | ~4 | Supplier records |

### Leads/CRM

| Table | Rows | Purpose |
|-------|------|---------|
| `leads` | 1,191 | Lead records |
| `lead_activities` | 68 | Lead interactions |
| `quote_requests` | 5 | Quote submissions |

### Customer Management (NEW - Jan 14, 2026)

| Table | Rows | Purpose |
|-------|------|---------|
| `companies` | 0 | Parent companies/organizations (#324) |
| `customer_tag_types` | 22 | Tag category lookup (customer_type, industry, payment, shipping, volume) (#344) |
| `customer_tags` | 0 | Junction: customers ↔ tag_types (#344) |
| `quote_templates` | 0 | Reusable quote templates (#177) |

**New Column:** `customers.company_id` - FK to companies(id), nullable

### Shipping (NEW - Jan 21, 2026)

| Table | Rows | Purpose |
|-------|------|---------|
| `shipping_labels` | 0 | Outbound shipping labels via EasyPost (#465) |

**Schema:** (legacy reference — original module docs archived with mint-os)

**Key Columns:**
- `order_id` - FK to orders (nullable for standalone shipments)
- `tracking_number` - Carrier tracking code
- `carrier` - usps/ups/fedex
- `cost_cents` - Label cost in cents
- `recipient_address` - JSONB {street1, city, state, zip}
- `created_by` - Employee name from PIN auth

### Files Module (NEW - Jan 22, 2026)

| Table | Rows | Purpose |
|-------|------|---------|
| `job_photos` | 0 | Finished job photos for reorder reference (#538) |
| `pending_jobs` | 0 | Pre-quote job IDs (JIRA model) (#539) |

**Schema:** (legacy reference — original module docs archived with mint-os)

**job_photos:**
- `order_id` - FK to orders (required)
- `url` - MinIO URL
- `filename` - Original filename
- `description` - Optional caption
- `taken_at` - Photo timestamp

**pending_jobs:**
- `visual_id` - Unique job ID (30000+ range)
- `nickname` - Slugified job name
- `customer_hint` - Customer name before linking
- `customer_id` - FK to customers (nullable until linked)
- `source` - 'email', 'form', 'manual', 'portal'
- `source_ref` - External reference (email ID, etc.)
- `converted_to_order_id` - FK to orders (when quote created)
- `status` - 'pending', 'converted', 'abandoned'

**job_files:** ✅ Created 2026-01-22
- `bucket` - MinIO bucket name
- `object_key` - Full path in bucket
- `url` - Public URL
- `original_filename` - Original filename
- `kind` - 'original', 'proof', 'production', 'photo', 'invoice'
- `status` - 'uploaded', 'needs-review', 'approved', 'archived'
- `order_id` / `pending_job_id` - Job linkage (one required)

**mint_visual_id_seq:** ✅ Created 2026-01-22 (current value: 30016)

### Lookup Tables

| Table | Rows | Purpose |
|-------|------|---------|
| `printavo_statuses` | 10 | Valid status values |
| `decoration_types` | 18 | Valid decoration types |
| `line_item_categories` | 20 | Valid categories |

### Tasks

| Table | Rows | Purpose |
|-------|------|---------|
| `tasks` | 1,287 | Order tasks |

### AI

| Table | Rows | Purpose |
|-------|------|---------|
| `ai_sessions` | ~1 | AI chat sessions |
| `ai_messages` | ~1 | AI messages |
| `ai_knowledge` | ~14 | AI context |

### RAG / AnythingLLM

| Item | Details |
|------|---------|
| API URL | `http://100.71.17.29:3002` (AnythingLLM on `ai-consolidation` VM 207). |
| Workspace | `workbench` |
| Scripts | `~/code/workbench/scripts/root/rag/index.sh`, `~/code/workbench/scripts/root/rag/cleanup-duplicates.sh`, `~/code/workbench/scripts/root/rag/health-check.sh`, `~/code/workbench/scripts/root/rag/full-resync.sh`. |
| Storage | VM 207: `/opt/stacks/ai-consolidation/anythingllm_storage/` (plus Qdrant at `/opt/stacks/ai-consolidation/qdrant_storage/`). |
| Health | `curl -s http://100.71.17.29:3002/api/ping` (returns `{"online":true}`). |

### Admin/System

| Table | Rows | Purpose |
|-------|------|---------|
| `admin_users` | ~1 | Strapi admin (legacy) |
| `dashboard_admins` | ~1 | Dashboard auth |
| `_migrations` | ~2 | Schema migrations |

---

## FILE STORAGE GOVERNANCE

> **MinIO Infrastructure:** See `infrastructure/storage/` for compose. (File operations spec was in mint-os module docs, now archived.)
> ⚠️ **MinIO extracted (2026-01-23):** Container renamed `mint-os-minio` → `minio`. Location: `infrastructure/storage/`.
> **Note:** `artwork-module/` contains historical extraction notes only, not current state.

### The Rules

```
┌────────────────────────────────────────────────────────────────────┐
│  BEFORE uploading ANY file or inserting ANY record:               │
│                                                                    │
│  1. Query existing records to see the EXACT pattern               │
│  2. Match that pattern EXACTLY                                     │
│  3. If patterns don't exist, STOP and ask                         │
│                                                                    │
│  NO INVENTING NEW PATTERNS. NO "artwork/" BUCKET. NO SHORTCUTS.   │
└────────────────────────────────────────────────────────────────────┘
```

### File Type → Bucket → Table → URL Pattern

| File Type | MinIO Bucket | Database Table | URL Pattern |
|-----------|--------------|----------------|-------------|
| Production artwork | `production-files` | `production_files` | `https://files.ronny.works/production-files/{filename}` |
| Line item mockups | `line-item-mockups` | `line_item_mockups` | `https://files.ronny.works/line-item-mockups/{filename}` |
| Imprint mockups | `imprint-mockups` | `imprint_mockups` | `https://files.ronny.works/imprint-mockups/{filename}` |
| Customer artwork | `customer-artwork` | `customer_artwork` | `https://files.ronny.works/customer-artwork/{filename}` |
| Invoice PDFs | `invoice-pdfs` | `orders.invoice_pdf_url` | `https://files.ronny.works/invoice-pdfs/{visual_id}.pdf` |
| Client assets (job folders) | `client-assets` | N/A (folder-based) | `https://files.ronny.works/client-assets/{path}` |
| Supplier product images | `suppliers` | `products.image_url` | `https://files.ronny.works/suppliers/{supplier}/{filename}` |

> **Note:** `client-assets` uses folder-based organization (`## wip/{visual_id} {nickname}/`) instead of database records. See `docs/ARTWORK_WORKFLOW.md` for details.

### Database Schema for File Records

**production_files** (linked to orders via `order_id`)
```sql
INSERT INTO production_files (order_id, url, filename, mime_type, created_at, updated_at)
VALUES (
  {order_id},
  'https://files.ronny.works/production-files/{filename}',
  '{filename}',
  '{mime_type}',
  NOW(), NOW()
);
```

**line_item_mockups** (linked to line_items via `line_item_id`)
```sql
INSERT INTO line_item_mockups (line_item_id, order_id, url, filename, content_type, created_at, updated_at)
VALUES (
  {line_item_id},  -- REQUIRED
  {order_id},      -- Optional but recommended
  'https://files.ronny.works/line-item-mockups/{filename}',
  '{filename}',
  '{content_type}',
  NOW(), NOW()
);
```

**imprint_mockups** (linked to imprints via `imprint_id`)
```sql
INSERT INTO imprint_mockups (imprint_id, order_id, url, filename, content_type, created_at, updated_at)
VALUES (
  {imprint_id},
  {order_id},
  'https://files.ronny.works/imprint-mockups/{filename}',
  '{filename}',
  '{content_type}',
  NOW(), NOW()
);
```

**customer_artwork** (linked to orders via `order_id`, or quote requests via `quote_request_id`)
```sql
-- For quote requests (before order exists):
INSERT INTO customer_artwork (quote_request_id, url, filename, file_type, file_size, created_at, updated_at)
VALUES (
  {quote_request_id},
  'https://files.ronny.works/customer-artwork/quotes/{filename}',
  '{filename}',
  '{file_type}',
  {file_size},
  NOW(), NOW()
);

-- For orders:
INSERT INTO customer_artwork (order_id, url, filename, file_type, file_size, created_at, updated_at)
VALUES (
  {order_id},
  'https://files.ronny.works/customer-artwork/orders/{order_id}/{filename}',
  '{filename}',
  '{file_type}',
  {file_size},
  NOW(), NOW()
);

-- When quote converts to order, link artwork:
UPDATE customer_artwork
SET order_id = {order_id}, updated_at = NOW()
WHERE quote_request_id = {quote_request_id};
```

**shipments** (standalone shipping history - no Mint OS dependency)
```sql
INSERT INTO shipments (
  easypost_shipment_id, tracking_code, label_url, label_pdf_url,
  carrier, service, rate_cents,
  to_name, to_street1, to_city, to_state, to_zip,
  order_id, created_at
)
VALUES (
  '{easypost_id}',     -- EasyPost shipment ID
  '{tracking_code}',   -- Carrier tracking number
  '{label_url}',       -- Label image URL
  '{label_pdf_url}',   -- Label PDF URL
  '{carrier}',         -- e.g., 'USPS', 'UPS', 'FedEx'
  '{service}',         -- e.g., 'Priority', 'Ground'
  {rate_cents},        -- Cost in cents (e.g., 850 = $8.50)
  '{to_name}',         -- Recipient name
  '{to_street1}',      -- Street address
  '{to_city}',         -- City
  '{to_state}',        -- State code
  '{to_zip}',          -- ZIP code
  {order_id},          -- Optional: link to orders table (NULL for standalone)
  NOW()
);
```

### Find IDs Before Inserting

```sql
-- Find line_item_ids for an order by visual_id
SELECT 
  o.visual_id,
  o.id as order_id,
  li.id as line_item_id,
  li.description,
  li.style_number
FROM orders o
JOIN line_items li ON li.order_id = o.id
WHERE o.visual_id = '{visual_id}';

-- Find imprint_ids for an order (use junction table for complete results)
SELECT DISTINCT
  o.visual_id,
  o.id as order_id,
  i.id as imprint_id,
  i.description as imprint_details,
  i.location,
  i.decoration_type
FROM imprints i
JOIN imprints_line_item_lnk lnk ON lnk.imprint_id = i.id
JOIN line_items li ON li.id = lnk.line_item_id
JOIN orders o ON o.id = li.order_id
WHERE o.visual_id = '{visual_id}';
```

---

## IMPRINTS (DECORATION SPECS)

### What is an Imprint?

An **imprint** defines HOW a decoration is applied to a garment:
- Location (Front Chest, Full Back, Left Sleeve, etc.)
- Size (width, height in inches)
- Decoration type (Screen Print, Embroidery, DTG, etc.)
- Colors/inks used

### Data Model

```
orders
  └── line_items (garments)
        └── imprints (decoration specs) ←── via imprints_line_item_lnk junction table
              └── imprint_mockups (visual of the print)
```

### The `description` Field

The `imprints.description` field contains the full decoration spec:

```
{Location}
{Size}
{Colors/Inks}
```

**Examples:**
```
Left Chest Screen Print
4" W
288 Navy + Gold Shimmer
```

```
Full Back Screen Print
12" W
White Underbase + 306C Cyan + 232C Fuscia
```

### Finding Imprint Details

**ALWAYS use junction table for complete results:**

```sql
SELECT DISTINCT
  o.visual_id,
  i.id as imprint_id,
  i.description,
  i.location,
  i.decoration_type,
  li.id as line_item_id,
  li.description as product
FROM imprints i
JOIN imprints_line_item_lnk lnk ON lnk.imprint_id = i.id
JOIN line_items li ON li.id = lnk.line_item_id
JOIN orders o ON o.id = li.order_id
WHERE o.visual_id = '{visual_id}';
```

---

## Complete Relationship Chain

```
orders (visual_id: "13714")
  │
  ├── payments (order_id → orders.id)
  ├── fees (order_id → orders.id)
  ├── tasks (order_id → orders.id)
  ├── assigned_employee_id → employees.id (nullable)
  │
  ├── production_files (order_id → orders.id)
  │     └── Print-ready artwork files
  │
  ├── customer_artwork (order_id → orders.id)
  │     └── Original files from customer
  │
  └── line_items (order_id → orders.id)
        │
        ├── assigned_employee_id → employees.id (nullable)
        ├── line_item_mockups (line_item_id → line_items.id)
        │     └── "How the garment will look with print"
        │
        └── imprints (via imprints_line_item_lnk)
              │
              ├── description: "Front Chest\n11\" W\nWhite + Cyan"
              │
              └── imprint_mockups (imprint_id → imprints.id)
                    └── "Close-up of the print itself"
```

---

## Database Connection

```
Host: 100.92.156.118 (docker-host via Tailscale)
Port: 15432
User: mint_os_admin
Pass: (check Infisical)
DB:   mint_os
```

---

## Lookup Tables

**Query valid values before inserting:**

```sql
SELECT name FROM printavo_statuses;    -- 10 values
SELECT name FROM line_item_categories; -- 20 values
SELECT name FROM decoration_types;     -- 18 values
```

---

## DOCKER-HOST DATA LAYOUT

> **Location:** `docker-host:/mnt/docker/`
> **Purpose:** Persistent data for all Docker stacks
> **Mirrors:** ronny-ops pillar structure

### /mnt/docker/ Structure

| Folder | Size | Purpose | Stack | Status |
|--------|------|---------|-------|--------|
| `mint-os/` | ~160GB | Mint OS business data | mint-os, mint-os-data | ACTIVE |
| `finance/` | - | Finance stack data | finance | ACTIVE |
| `mail-archive-import/` | ~200GB | Email import staging | mail-archiver | ACTIVE |
| `as-colour-images/` | 3.1GB | Product image import | mint-os | ACTIVE |
| `ml-infrastructure/` | 12MB | ML training data | - | ACTIVE |

### /mnt/docker/mint-os/ Structure

| Folder | Size | Purpose | Status |
|--------|------|---------|--------|
| `vault/` | 80GB | Active production data (MinIO, uploads) | ACTIVE - Primary |
| `printavo-archive/` | 79GB | Legacy Printavo recovery (#217) | READ-ONLY |
| `postgres/` | 136MB | PostgreSQL data | ACTIVE |
| `backups/` | 17MB | Database backups | ACTIVE |

### printavo-archive/ Contents (Legacy Reference)

> **Source:** Printavo API extraction (Jan 7-8, 2026) - Issue #217
> **Files:** 37,546 total
> **Status:** READ-ONLY. Do not write here. Reference only.
```
/mnt/docker/mint-os/printavo-archive/
├── production-files/      (33GB) - Production assets
├── line-item-mockups/     (41GB) - Line item mockups
├── imprint-mockups/       (6.1GB) - Imprint mockups
├── manual-import-mockups/ (13MB) - Manual imports
└── manifests/             (3.9MB) - Data manifests
```

### Governance Rules

- **Pillar alignment:** Data folders mirror ronny-ops pillars
- **No root-level junk:** All data in pillar folders or explicitly documented
- **Active vs Archive:** `vault/` = active, `*-archive/` = read-only legacy
- **Document changes:** Update this section when adding/moving data
- **Backups:** Critical data backed up per 3-2-1 strategy

### Deleted (v1/v2 Remnants) - Jan 16, 2026

The following were removed during #401 audit:

- `alertmanager/`, `grafana/`, `prometheus/` - orphaned monitoring (no containers)
- `strapi/`, `minio/`, `redis/` - v1/v2 remnants (no containers)
- `printshop-os/`, `printshop-*` - legacy v1/v2 data
- `GraphQL/output/` - stale cache (32GB)

---

## File Locations on docker-host

| Path | Contents |
|------|----------|
| `/mnt/docker/printavo-recovery/production-files/` | 12,026 production files |
| `/mnt/docker/printavo-recovery/line-item-mockups/` | 21,405 mockup files |
| `/mnt/docker/printavo-recovery/imprint-mockups/` | 4,088 imprint files |

---

## Docker Compose

Location: `docker-host:~/stacks/mint-os/docker-compose.yml`

| Container | Image | Ports |
|-----------|-------|-------|
| `mint-os-postgres` | postgres:15 | 15432:5432 |
| `mint-os-redis` | redis:7 | 16379:6379 |
| `minio` | minio/minio | 9000, 9001 |
| `mint-os-dashboard-api` | (built) | 3456 |
| `mint-os-job-estimator` | (built) | 3001 |

> ⚠️ **MinIO extracted (2026-01-23):** Now lives in `infrastructure/storage/docker-compose.yml`, not mint-os stack. Joins `storage-network` + `mint-os-network` for backward compat.

```bash
# Restart API
ssh docker-host "cd ~/stacks/mint-os && docker compose restart dashboard-api"

# Restart Job Estimator
ssh docker-host "cd ~/stacks/mint-os && docker compose restart job-estimator"

# Full stack restart
ssh docker-host "cd ~/stacks/mint-os && docker compose down && docker compose up -d"
```

---

## Job Estimator Service

**Container:** `mint-os-job-estimator` (port 3001)
**Location:** `mint-os/apps/job-estimator/`
**Version:** 1.2.0
**Tests:** 85+ passing
**Status:** ✅ LIVE AND WORKING

### Endpoints

| Endpoint | Method | Purpose | Data Source |
|----------|--------|---------|-------------|
| `/pricing/calculate` | POST | Full quote calculation | DB (fallback: JSON) |
| `/pricing/screen-print` | POST | Screen print price lookup | DB |
| `/pricing/embroidery` | POST | Embroidery price lookup | DB |
| `/pricing/laser` | POST | Laser etching price lookup | DB |
| `/pricing/transfer` | POST | Transfer price lookup | DB |
| `/products/:sku/price` | GET | Garment cost lookup | DB |
| `/health` | GET | Health check | - |

### Pricing Rules (CONFIGURED)

| Rule | Value | Notes |
|------|-------|-------|
| Base margin | 35% | Auto-applied to all quotes |
| Volume discount 100+ | 10% | Automatic |
| Volume discount 500+ | 20% | Automatic |
| Embroidery base | $1.50/1000 stitches | Multiplied by quantity |
| Location surcharges | Front +$2, Back +$3, Sleeve +$1.50 | Per unit |
| Color multiplier | 1.3x for 2+ colors | Screen print only |

### Database Tables

| Table | Records | Purpose |
|-------|---------|---------|
| `screen_print_prices` | ~3,719 | Screen print pricing matrix |
| `embroidery_prices` | 240 | Embroidery by stitch count |
| `laser_prices` | 80 | Laser etching by size |
| `transfer_prices` | 49 | DTF/vinyl transfers |
| `pricing_quantity_tiers` | 16 | Quantity break definitions |

### Architecture

```
Admin UI → V2 API (dashboard-server.cjs) → Job Estimator → PostgreSQL
                                                 ↓
                                          pricing tables
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/api-server.ts` | Express server, endpoints |
| `lib/pricing-api.ts` | PricingAPIService class |
| `lib/db-pricing-provider.ts` | Database pricing lookups |
| `lib/pricing-rules-engine.ts` | Margin/discount rules |
| `data/pricing-tables.json` | Fallback static pricing |

### Test Pricing Calculation

```bash
# Screen print (3 colors, qty 50)
curl -X POST http://100.92.156.118:3001/pricing/calculate \
  -H "Content-Type: application/json" \
  -d '{"quantity": 50, "service": "screen_print", "print_size": "M", "color_count": 3}'

# Embroidery (5000 stitches, qty 25)
curl -X POST http://100.92.156.118:3001/pricing/calculate \
  -H "Content-Type: application/json" \
  -d '{"quantity": 25, "service": "embroidery", "stitch_count": 5000}'
```

### Integration Status

| Integration | Status | Notes |
|-------------|--------|-------|
| Admin UI quote builder | ❌ NOT WIRED | Needs frontend hook |
| n8n workflows | ❌ NOT WIRED | Can call via HTTP |
| MCP tool | ❌ NOT WRAPPED | Should expose as `calculate_quote` |

---

## Stitch Estimator (ML)

**Script:** `mint-os/tools/stitch-estimator/stitch_estimator.py`
**ML Model:** `/mnt/data/mint-os/production/embroidery/ml-training/stitch_model_gb.pkl`
**Status:** ✅ WORKING

### Capabilities

| Input Type | Method | Confidence |
|------------|--------|------------|
| DST, PES, EXP, JEF, VP3, HUS files | Exact parsing via pyembroidery | 100% |
| PNG, JPG, GIF, BMP, WebP images | ML estimation (Gradient Boosting) | 50-70% |

### Output

```json
{
  "method": "exact|ml_estimate",
  "source": "embroidery_file|image",
  "stitch_count": 12500,
  "stitch_range": {"low": 6250, "high": 22500},  // ML only
  "color_changes": 3,                             // DST only
  "width_inches": 4.5,                            // DST only
  "height_inches": 3.2,                           // DST only
  "complexity": "medium",                         // simple|medium|complex|detailed
  "confidence": 0.7,
  "est_time_minutes": 15                          // @ 800 SPM
}
```

### Usage

```bash
# Single file
python stitch_estimator.py design.dst

# Directory scan
python stitch_estimator.py --dir /path/to/artwork/

# JSON output
python stitch_estimator.py design.png --json
```

### Integration with Job Estimator

```
Customer sends artwork
       ↓
stitch_estimator.py analyzes file
       ↓
Returns: stitch_count
       ↓
Job Estimator /pricing/calculate receives stitch_count
       ↓
Returns: embroidery pricing with accurate stitch-based costs
```

---

## Supplier Integration

**Status:** ✅ APIS WORKING, CREDENTIALS IN INFISICAL
**Schema Doc:** `mint-os/apps/web/docs/supplier-sync-schema.md`

### Supplier Status

| Supplier | API Client | Products | Inventory | Images | Pricing | Credentials |
|----------|-----------|----------|-----------|--------|---------|-------------|
| S&S Activewear | ✅ REST | 211K+ SKUs | ✅ Real-time | ✅ CDN | ✅ Wholesale | `mint-os-api/prod` |
| AS Colour | ✅ REST | 500+ styles | ❌ No auth | ✅ Downloaded | ❌ No auth | `mint-os-api/prod` |
| SanMar | ⚠️ SFTP | 415K+ SKUs | ⚠️ CSV | ✅ CSV | ✅ CSV | `mint-os-api/prod` |

### API Endpoints (Dashboard API)

| Endpoint | Purpose | Status |
|----------|---------|--------|
| `GET /api/products` | Unified product search | ⚠️ Defined, needs wiring |
| `GET /api/products/:sku` | Single product + inventory | ⚠️ Defined, needs wiring |
| `POST /api/inventory/check` | Real-time stock check | ⚠️ Defined, needs wiring |

### Quick Test Commands

```bash
# S&S - Get Gildan 2000 info
curl -u "31810:$SS_API_KEY" "https://api.ssactivewear.com/v2/products/?style=39" | jq '.[0]'

# AS Colour - Get product list
curl -H "Subscription-Key: $ASCOLOUR_KEY" "https://api.ascolour.co.nz/v1/catalog/products?pageSize=5"

# SanMar - Connect to SFTP
sftp -P 2200 180164@ftp.sanmar.com
```

### AS Colour Images (PENDING UPLOAD)

**Location:** `docker-host:/tmp/ascolour-assets/`
**Backup:** `docker-host:/home/docker-host/ascolour-assets/`
**Count:** 10,621 files
**Status:** ⏳ Waiting for MinIO upload

```bash
# Upload to MinIO (run on docker-host)
mc mirror /tmp/ascolour-assets/ mintminio/suppliers/as-colour/

# Verify
mc ls mintminio/suppliers/as-colour/ | wc -l
# Expected: ~10,621
```

**URL Pattern (after upload):**
```
https://files.ronny.works/suppliers/as-colour/{filename}.jpg
```

### Unified Product Schema

All suppliers map to this structure (see `supplier-sync-schema.md` for full spec):

```typescript
interface UnifiedProduct {
  supplier: 'ss_activewear' | 'as_colour' | 'sanmar';
  supplier_sku: string;
  style_code: string;
  brand: string;
  title: string;
  category: string;
  base_price: number;
  colors: Color[];
  sizes: string[];
  image_url: string;
  inventory: { total: number; warehouses: Warehouse[] };
}
```

### Database Tables

| Table | Rows | Purpose |
|-------|------|---------|
| `products` | 3,844 | Curated catalog (S&S, AS Colour) |
| `sanmar_products` | 156,063 | SanMar full catalog |

### Integration Status

| Integration | Status | Notes |
|-------------|--------|-------|
| Quote builder product picker | ❌ NOT WIRED | Can search, UI doesn't use it |
| Inventory check before order | ❌ NOT WIRED | API exists, not called |
| Scheduled sync | ❌ NOT RUNNING | n8n workflow needed |
| AS Colour images in MinIO | ⏳ PENDING | 10K files waiting |

---

## Firefly III Integration (Finance Stack)

**Base URL:** `https://firefly.ronny.works/api/v1`  
**API Version:** v6.4.x (see finance stack for exact)  

### Auth (Infisical)
- **mint-os-api/prod:** `FIREFLY_III_BASE_URL`, `FIREFLY_III_PAT`, `FIREFLY_DEFAULT_SOURCE_ACCOUNT`
- **finance-stack/prod:** `FIREFLY_API_URL`, `FIREFLY_ACCESS_TOKEN`
- **infrastructure/prod:** `FIREFLY_PAT` (source for mint-os-api PAT)

### Sync Directions
- **Firefly → Mint OS:** Webhook → n8n → `expenses` table (finance runbook)
- **Mint OS → Firefly:** `POST /api/expenses` or `/api/expenses/:id/sync` → Firefly `/transactions`

### Category Mapping
- File: `mint-os/config/firefly-category-map.json`

### Idempotency
- `expenses.firefly_transaction_id` (unique) prevents duplicate sync entries

### Status
- **Integration:** ✅ COMPLETE (2026-01-17)
- **Verified Endpoints:** POST /api/expenses, GET /api/vendors?sync=true, POST /api/expenses/:id/sync
- **Issue:** #418 (closed)

---

## Data Integrity Status

**Last Verified:** January 11, 2026

### Invoice PDFs
- **12,864 orders** have valid `invoice_pdf_url` pointing to MinIO
- **54 orders** have `invoice_pdf_url = NULL` (unrecoverable legacy quotes)
- **12,863 PDFs** in MinIO `invoice-pdfs/` bucket

### Line Item Mockups  
- **All post-migration orders (13710-13721)** have 100% mockup coverage
- **17 line items, 17 mockups** - no gaps

### Orders Complete (Post-Migration)
| visual_id | Order | Line Items | Mockups |
|-----------|-------|------------|---------|
| 13710 | what matters | 1 | 1 ✅ |
| 13714 | Players Alliance Jerseys | 3 | 3 ✅ |
| 13715 | Miami ACS | 3 | 3 ✅ |
| 13716 | Cove Brewery Merch Reorder | 5 | 5 ✅ |
| 13717 | Merci Deity | 1 | 1 ✅ |
| 13718 | Expansion Church | 1 | 1 ✅ |
| 13719 | Expansion Church EMS | 1 | 1 ✅ |
| 13720 | i heart ellii | 1 | 1 ✅ |
| 13721 | 2026 Bandit | 1 | 1 ✅ |

### Check Database Integrity

```sql
-- Files with URLs that should exist in MinIO
SELECT
  'production_files' as table_name, COUNT(*) as records_with_url
FROM production_files WHERE url IS NOT NULL
UNION ALL
SELECT
  'line_item_mockups', COUNT(*)
FROM line_item_mockups WHERE url IS NOT NULL
UNION ALL
SELECT
  'imprint_mockups', COUNT(*)
FROM imprint_mockups WHERE url IS NOT NULL
UNION ALL
SELECT
  'invoice_pdfs', COUNT(*)
FROM orders WHERE invoice_pdf_url IS NOT NULL;
```

---

## Common Issues

### "Files not in MinIO"

1. Check if files exist on disk: `ls /mnt/docker/printavo-recovery/{bucket}/`
2. If on disk but not in MinIO → upload with `mc cp`
3. If not on disk → check if Filestack URL still works

### "DB credentials mismatch"

1. Check running container: `docker exec CONTAINER env | grep DB`
2. Compare with Infisical: `./scripts/agents/infisical-agent.sh get ...`
3. Update Infisical to match container OR restart container with Infisical values

### "API not responding"

1. Check container running: `docker ps | grep dashboard-api`
2. Check logs: `docker logs mint-os-dashboard-api --tail 50`
3. Check health: `curl https://mintprints-api.ronny.works/health`

### "Can't find imprint details"

1. **Always use junction table** - it's the source of truth (per #270)
2. Query: `SELECT i.* FROM imprints i JOIN imprints_line_item_lnk lnk ON i.id = lnk.imprint_id JOIN line_items li ON lnk.line_item_id = li.id WHERE li.order_id = X`
3. The `imprints.order_id` column is convenience only - 4,420 imprints are shared across multiple orders

---

## Schema Summary (Post Issue #271)

**65 tables total** as of January 25, 2026 (#608 reconciliation)
> Note: Count increased from 38 due to new tables added Jan 14-22 (shipping, files module, customer management, pricing support tables)

### Core Tables (Column Counts)

| Table | Columns | Notes |
|-------|---------|-------|
| `orders` | 63 | Dropped 10 garbage columns |
| `line_items` | 40 | Dropped 3 Strapi columns |
| `customers` | 40 | Dropped 9 columns (incl. `fax`, duplicate notes) |
| `imprints` | 17 | Clean - junction table is source of truth |
| `imprints_line_item_lnk` | 4 | 17,787 records (cleaned 3,068 orphans) |

### Source of Truth Map

| Domain | Table(s) | Notes |
|--------|----------|-------|
| Products - SanMar | `sanmar_products` | 157K products, SFTP sync |
| Products - S&S/AS | `products` | Filter by `supplier` column |
| Pricing | `screen_print_prices`, `embroidery_prices`, `laser_prices`, `transfer_prices` | #272 |
| Suppliers | `suppliers` | Single table (enhanced with contact fields) |
| Status | `printavo_status_name` | Primary field, `printavo_statuses` for lookup |
| Imprints | `imprints_line_item_lnk` | Junction table (NOT `imprints.order_id`) |

### Dropped in #271

- `vendors` table (use `suppliers`)
- 22 garbage columns across core tables
- 3,068 orphan junction records

### Agent Query Patterns

```sql
-- Products by supplier
SELECT * FROM sanmar_products WHERE ...;  -- SanMar
SELECT * FROM products WHERE supplier = 'ss_activewear';  -- S&S
SELECT * FROM products WHERE supplier = 'as_colour';  -- AS Colour

-- Imprints for an order (ALWAYS use junction)
SELECT DISTINCT i.*
FROM imprints i
JOIN imprints_line_item_lnk lnk ON lnk.imprint_id = i.id
JOIN line_items li ON li.id = lnk.line_item_id
WHERE li.order_id = {order_id};

-- Pricing lookup (Issue #272)
SELECT sp.unit_price FROM screen_print_prices sp
JOIN pricing_quantity_tiers pqt ON pqt.id = sp.qty_tier_id
WHERE sp.print_size = 'M' AND sp.color_count = 3 AND sp.print_type = 'LIGHT'
  AND pqt.min_qty <= 50 AND (pqt.max_qty >= 50 OR pqt.max_qty IS NULL);
```

---

## Update Policy

**Update this file after:**
- New bucket created
- Database schema change
- New container added
- Credentials rotated
- URL pattern changed
- Data integrity issue resolved
- New service deployed (add full section)
- New integration working (add to relevant section)

---

## Archive Policy

**⚠️ DO NOT archive REF_* docs without updating this file first.**

The `/docs/.archive/` folder contains genuinely obsolete plans. However, some REF_* (reference) docs describe LIVE systems and were archived incorrectly.

**Before archiving ANY doc:**
1. Check if it describes a LIVE service/integration
2. If yes → Extract key info into INFRASTRUCTURE_MAP.md FIRST
3. Then archive with note: "Consolidated into INFRASTRUCTURE_MAP.md on [date]"

**Currently archived but still relevant (extracted Jan 15, 2026):**
- `REF_JOB_ESTIMATOR.md` → Now in "Job Estimator Service" section above
- `REF_SUPPLIER_APIS.md` → Now in "Supplier Integration" section above
- `REF_SUPPLIER_DATA_MAPPING.md` → Now in "Supplier Integration" section above

**Genuinely obsolete (safe to ignore):**
- `old-plans/*` - Superseded implementation plans
- `PLAN_*` files - Completed or abandoned plans
- `DIAG_*` files - One-time diagnostic outputs
- `SESSION_*` files - Historical session logs

---

## STRIPE PAYMENT FLOW

> **Updated:** January 11, 2026 - Issue #287 Complete

### Overview
```
Customer Checkout → Stripe Payment → Webhook → Database Update
```

### Flow Diagram
```
┌─────────────────┐     ┌─────────────┐     ┌──────────────────────────────┐     ┌─────────────┐
│ customer.mint   │────▶│   Stripe    │────▶│ /api/webhooks/stripe         │────▶│  Database   │
│ /checkout       │     │  Checkout   │     │ (checkout.session.completed) │     │  orders +   │
│                 │     │             │     │                              │     │  payments   │
└─────────────────┘     └─────────────┘     └──────────────────────────────┘     └─────────────┘
     Creates order         Collects            Verifies signature,               Updates order,
     status=PAYMENT_NEEDED payment             processes event                   creates payment
```

### Files
| File | Purpose |
|------|---------|
| `apps/api/routes/stripe-webhooks.cjs` | Webhook handler |
| `apps/api/routes/v2-checkout.cjs` | Creates checkout session |
| `apps/api/lib/stripe.cjs` | Stripe SDK wrapper |

### Database Constraints (CRITICAL)
The webhook updates two status fields with DIFFERENT constraints:

| Column | Constraint Type | Valid Values | Used For |
|--------|----------------|--------------|----------|
| `orders.status` | CHECK constraint | `PAID`, `QUOTE`, `INVOICE`, `PAYMENT_NEEDED`, etc. | Internal status |
| `orders.printavo_status_name` | FK to `printavo_statuses` | `Quote Approved`, `PAYMENT NEEDED`, etc. | Display status |

**When deposit is paid:**
- `status = 'PAID'` (CHECK constraint)
- `printavo_status_name = 'Quote Approved'` (FK constraint)
- `deposit_paid = true`

**Valid CHECK constraint values for `orders.status`:**
```
draft, quote, invoice, paid, cancelled,
DRAFT, QUOTE, INVOICE, PAID, CANCELLED,
DTG - PRODUCTION, SP - PRODUCTION, EMB - PRODUCTION, IN_PRODUCTION,
COMPLETE, READY_FOR_PICKUP, READY FOR PICK UP, SHIPPED,
PAYMENT_NEEDED, PAYMENT NEEDED, ART - WIP, ART_WIP
```

### Secrets
| Secret | Location | Purpose |
|--------|----------|---------|
| `STRIPE_SECRET_KEY` | Infisical: `mint-os-api/prod` | API authentication |
| `STRIPE_WEBHOOK_SECRET` | Infisical: `mint-os-api/prod` | Webhook signature verification |

### Stripe Dashboard Configuration
- **Endpoint URL:** `https://mintprints-api.ronny.works/api/webhooks/stripe`
- **Events:** `checkout.session.completed`
- **Endpoint Name:** `Mintosapi`
- **Dashboard:** https://dashboard.stripe.com/webhooks

### Testing Webhooks
1. Make a test purchase through checkout
2. Go to Stripe Dashboard → Webhooks → Mintosapi → Event deliveries
3. Find the `checkout.session.completed` event
4. Click "Resend" to retry failed webhooks

### Debugging
```bash
# Check webhook secret in container
ssh docker-host "docker exec mint-os-dashboard-api env | grep STRIPE_WEBHOOK_SECRET"

# Watch webhook logs
ssh docker-host "cd ~/stacks/mint-os && docker compose logs -f dashboard-api 2>&1 | grep -i webhook"

# Verify order was updated
psql -h 100.92.156.118 -p 15432 -U mint_os_admin -d mint_os -c \
  "SELECT visual_id, status, printavo_status_name, deposit_paid FROM orders WHERE visual_id = 'XXXXX';"

# Check payment was recorded
psql -h 100.92.156.118 -p 15432 -U mint_os_admin -d mint_os -c \
  "SELECT * FROM payments WHERE order_id = (SELECT id FROM orders WHERE visual_id = 'XXXXX');"
```

### Common Errors
| Error | Cause | Fix |
|-------|-------|-----|
| `Webhook signature verification failed` | Wrong secret in container | Update Infisical, `docker compose up -d --force-recreate dashboard-api` |
| `violates foreign key constraint "orders_status_fk"` | Invalid `printavo_status_name` | Use value from `SELECT name FROM printavo_statuses` |
| `violates check constraint "orders_status_check"` | Invalid `status` value | Use CHECK constraint values (PAID, QUOTE, etc.) |
| `value too long for type character varying(N)` | Column too small for data | `ALTER TABLE ... ALTER COLUMN ... TYPE varchar(255)` |

### Important: Container Environment
`docker compose restart` does NOT reload `.env` - environment is cached.

To pick up new secrets:
```bash
ssh docker-host "cd ~/stacks/mint-os && docker compose up -d --force-recreate dashboard-api"
```

### Checkout Endpoint
- **URL:** `POST /api/v2/checkout`
- **Auth:** None (guest checkout)
- **File:** `apps/api/routes/v2-checkout.cjs`

**Database Records Created:**
1. `customers` - find or create by email
2. `orders` - status='PAYMENT_NEEDED', deposit_amount=50%
3. `line_items` - linked to order

**Stripe Integration:**
- **Function:** `createCheckoutSession()` in `lib/stripe.cjs`
- **Success URL:** `https://customer.mintprints.co/portal?payment=success&order={visual_id}`
- **Cancel URL:** `https://customer.mintprints.co/checkout?payment=cancelled`

### Manual Payment Link Generation

If customer needs a payment link for an approved quote (workaround for #387):

```bash
curl -X POST "https://admin.mintprints.co/api/orders/{visual_id}/pay" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "success": true,
  "checkout_url": "https://checkout.stripe.com/...",
  "amount": 825.04,
  "payment_type": "full"
}
```

Send `checkout_url` to customer.

---

## FILE ARCHITECTURE (Current State)

> **Files Module:** (Bucket inventory and file operations spec was in mint-os module docs, now archived. See `modules/files-api/` for active implementation.)
> **Updated:** 2026-01-26
> ⚠️ **MinIO extracted:** Now standalone in `infrastructure/storage/`. See `modules/files-api/` for active implementation.

### Current Structure (ACTIVE)

```
files.ronny.works/
├── client-assets/              ← PRIMARY: OneDrive replacement
│   ├── ## wip/{visual_id} {nickname}/  ← Active jobs (44 folders synced)
│   │   ├── 1. Originals/
│   │   ├── 2. Proofs/
│   │   ├── 3. Production Files/
│   │   └── 4. Photos/
│   ├── ## template/            ← Folder template (7 items)
│   └── {Customer Name}/        ← Completed customer folders (223 pending sync)
│
├── line-item-mockups/          ← Garment visualizations (27K files)
├── imprint-mockups/            ← Print close-ups (6K files)
├── production-files/           ← Print-ready files (7K files)
├── invoice-pdfs/               ← Generated invoices (13K files)
├── customer-artwork/           ← Customer uploads (low volume)
└── suppliers/                  ← S&S/AS Colour catalog images
```

### Bucket Status (Verified 2026-01-22)

> Counts verified via `mc ls -r` + DB queries

| Bucket | Files | Legacy | Renamed | % Complete |
|--------|-------|--------|---------|------------|
| `client-assets` | ~225 folders | N/A | N/A | N/A (folder-based) |
| `line-item-mockups` | 27,303 | 6,741 | 20,562 | **75%** |
| `production-files` | 7,016 | 1,318 | 5,698 | **81%** |
| `imprint-mockups` | 6,001 | 2,166 | 3,835 | **64%** |
| `invoice-pdfs` | 12,863 | — | — | **100%** ✅ |
| `customer-artwork` | 3 | N/A | N/A | N/A |
| `suppliers` | ~4K | N/A | N/A | N/A |
| ~~`artwork/`~~ | — | — | — | ✅ **DELETED** |

**See:** (legacy reference — rename status and scripts were in mint-os module docs, now archived)

### ❌ DEPRECATED: `jobs/` bucket structure

The old plan for a unified `jobs/` bucket was abandoned. Current strategy: **rename in place + virtual folder view via API** (see #537, #539).

**DO NOT create a `jobs/` bucket.**
