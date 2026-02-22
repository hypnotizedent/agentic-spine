# Legacy Delta Audit — ronny-ops → Mint Migration Gap Analysis

> **Generated:** 2026-02-22
> **Mode:** Read-only audit (no edits, no commits, no loops opened)
> **Legacy root:** `/Users/ronnyworks/ronny-ops` (mounted at `/sessions/lucid-epic-ride/mnt/ronnyworks/ronny-ops`)
> **Mint refs:** `mint-modules`, `agentic-spine/docs/planning/MINT_PRINTS_FLOW_REPLACEMENT_ROADMAP_20260222.md`

---

## 1. Executive Delta

**What is still legacy-critical (cannot be turned off without breaking production):**

1. **Authentication & session management** — Customer JWT, admin sessions, employee PIN auth all live in legacy `dashboard-server.cjs`. No replacement exists in mint-modules. Turning it off locks out every user.

2. **Stripe payment lifecycle** — Checkout creation, deposit collection, webhook reconciliation (`stripe-webhooks.cjs`, `order-payments.cjs`, `lib/stripe.cjs`). No webhook receiver or payment module exists in mint-modules. Revenue stops without it.

3. **Order/job full lifecycle** — `v2-jobs.cjs` (4,347 lines) handles order CRUD, line items, tax, status transitions. `order-intake` in Mint only validates pre-order contracts; it does not manage post-creation lifecycle.

4. **Customer management** — `v2-customers.cjs` + `customers-legacy.cjs` power all dashboard search, filtering, and customer 360 views. No replacement in mint-modules.

5. **Notifications** — `lib/email.cjs` (Resend), `lib/twilio.cjs` (SMS), `notifications.cjs` coordinator. Communications-agent exists at spine level but is not wired into mint-modules transactional flow.

6. **Production portal** — PIN-login, job queue, time clock, SOPs for shop floor workers. Zero equivalent in mint-modules. Operations stop without it.

7. **n8n workflow orchestration** — 40 active workflows covering order management, payment fulfillment, data syncs, media, reporting. No replacement strategy defined.

8. **Cloudflare tunnel routing** — Single external routing layer mapping `admin.mintprints.co`, API endpoints, finance dashboard. No equivalent in mint-modules infra.

9. **Secrets management** — Infisical sync with 9 service-scoped `.env` files, daily verification, drift detection via launchd agents. Services cannot start without it.

10. **30+ database tables** — Core tables (orders, customers, imprints, expenses, production_steps, pricing tables, time_entries, dashboard_admins) remain solely in legacy `mint_os` DB. Only artwork (7 tables), shipping_labels (1), and finance_event_map (1) are in mint-modules DBs.

---

## 2. Folder Coverage Table

### 2a. Top-Level Legacy Structure

| legacy_path | capability | status | replacement_target | evidence |
|---|---|---|---|---|
| `mint-os/apps/api/` | Dashboard API server — Express.js backend with 36 route files, auth, payments, notifications | PARTIALLY_REPLACED | `mint-modules/{order-intake,quote-page,artwork,shipping,pricing,suppliers}` cover ~25% of routes | `dashboard-server.cjs` mounts all routes; only shipping + pricing have mint equivalents |
| `mint-os/apps/admin/` | Management dashboard — React/Vite admin portal for orders, customers, analytics, calendar | PARTIALLY_REPLACED | `mint-modules/quote-page` (HTML form only) | No full admin React portal in mint-modules |
| `mint-os/apps/web/` | Customer-facing ecommerce — AI order composer, product catalog, designer, checkout, portal | PARTIALLY_REPLACED | `mint-modules/quote-page` (landing capture only) | No designer, checkout, or customer portal in mint |
| `mint-os/apps/production/` | Shop floor portal — PIN login, job queue, time clock, quality checklists, SOPs | NOT_REPLACED | none found | Dedicated README for 65+ workers; no equivalent anywhere in mint |
| `mint-os/apps/shipping/` | Label builder + rate shopping UI — 4×6 label customization, carrier comparison, templates | PARTIALLY_REPLACED | `mint-modules/shipping` (backend only, no UI) | mint shipping = Node.js service; legacy = full React UI |
| `mint-os/apps/job-estimator/` | Pricing engine REST API — JSON rules, supplier cost integration, 85+ tests | PARTIALLY_REPLACED | `mint-modules/pricing` (backend service, scope unclear) | Legacy has OpenAPI spec + test suite; mint pricing README is empty |
| `mint-os/apps/suppliers/` | Supplier product browser (stub) | UNKNOWN | `mint-modules/suppliers` | Legacy app is minimal React template; unclear if functional |
| `mint-os/packages/types/` | Shared TypeScript types (`@mint-os/types`) | UNKNOWN | `mint-modules/packages/shared-types` | Need comparison of type coverage |
| `mint-os/packages/config/` | Shared config (`@mint-os/config`) | UNKNOWN | none found | May need porting |
| `mint-os/packages/api-client/` | API client library (`@mint-os/api-client`) | NOT_REPLACED | none found | All legacy frontends depend on this |
| `artwork-module/` | Artwork intake + processing | ALREADY_REPLACED | `mint-modules/artwork` | 7 greenfield tables, full CRUD in mint |
| `scripts/suppliers/` | Python supplier sync — SanMar, AS Colour, SS Activewear hourly cron | PARTIALLY_REPLACED | `mint-modules/suppliers` (backend exists, Python runtime unclear) | `base_supplier.py` + 3 plugins; mint has no Python runtime on fresh-slate |
| `scripts/` (file ops) | Artwork file management — rename, sync, validate, recover, OneDrive→MinIO | PARTIALLY_REPLACED | `mint-modules/artwork` (partial) | 14 active scripts; 12K files pending rename |
| `scripts/deploy-*.sh` | Deployment automation — rsync + remote npm build | NOT_REPLACED | none found | No CI/CD equivalent in mint-modules |
| `scripts/load-secrets.sh` | Infisical secrets sync | NOT_REPLACED | none found | Services cannot start without this |
| `config/firefly-category-map.json` | Expense category → Firefly III mapping | UNKNOWN | `mint-modules/finance-adapter` may consume | 7.6KB static JSON |
| `tools/embroidery/` | Embroidery estimator React app | UNKNOWN | none found | May be integrated or deprecated |
| `tools/stitch-estimator/` | Stitch calculator React app | UNKNOWN | none found | May be integrated or deprecated |
| `infrastructure/cloudflare/tunnel/` | Cloudflare tunnel routing | NOT_REPLACED | none found | Maps all external URLs to services |
| `infrastructure/` (docker-compose files) | Docker orchestration — 11 compose files, 8 Dockerfiles | NOT_REPLACED | `mint-modules/deploy/` (minimal) | Legacy has monitoring, storage, tunnel stacks |
| `infrastructure/` (launchd agents) | 9 macOS launchd agents — backup, secrets drift, paperless, offsite sync | NOT_REPLACED | none found | Critical ops automation |

### 2b. Legacy API Routes Detail

| route file | capability | status | replacement_target | evidence |
|---|---|---|---|---|
| `routes/auth.cjs` | Customer login/logout, JWT generation | NOT_REPLACED | none | 50+ frontend calls depend on this |
| `routes/admin-auth.cjs` | Admin dashboard access control | NOT_REPLACED | none | Guards all staff operations |
| `routes/v2-jobs.cjs` | Order CRUD, line items, tax, calculations (4,347 lines) | PARTIALLY_REPLACED | `order-intake` (pre-order only) | Full lifecycle management missing in mint |
| `routes/v2-checkout.cjs` | Order creation + 50% deposit initiation | NOT_REPLACED | none | New online orders impossible without this |
| `routes/order-payments.cjs` | Payment CRUD, refunds, balance tracking | NOT_REPLACED | none | Revenue collection blocked |
| `routes/stripe-webhooks.cjs` | Stripe webhook reconciliation | NOT_REPLACED | none | Payment status sync breaks |
| `routes/v2-customers.cjs` | Customer management + search | NOT_REPLACED | none | Dashboard search broken without |
| `routes/customers-legacy.cjs` | Legacy customer endpoints | NOT_REPLACED | none | Backward compatibility |
| `routes/customer-portal.cjs` | Self-serve order history, tracking, payment | NOT_REPLACED | none | Portal features gone |
| `routes/v2-communications.cjs` | Communication history CRM (21K lines) | NOT_REPLACED | none | Customer interaction tracking lost |
| `routes/dashboard-stats.cjs` | Real-time metrics (revenue, orders, pending) | NOT_REPLACED | none | Staff visibility gone |
| `routes/notifications.cjs` | Email/SMS dispatch coordinator | NOT_REPLACED | none | No customer comms |
| `routes/file-management.cjs` | MinIO file upload/management | NOT_REPLACED | `artwork` (partial) | File uploads broken |
| `routes/quotes.cjs` | Quote CRUD and management | PARTIALLY_REPLACED | `quote-page` (rendering only) | No dedicated quote API in mint |
| `routes/shipping.cjs` | Shipping rate + label purchase | ALREADY_REPLACED | `mint-modules/shipping` | Drop-in replacement confirmed |
| `routes/pricing.cjs` | Pricing calculation endpoints | ALREADY_REPLACED | `mint-modules/pricing` | pricing-engine.ts + job-estimator.ts |
| `routes/sanmar-routes.cjs` | SanMar-specific integration | UNKNOWN | none found | No equivalent in mint |
| `routes/timekeeping.cjs` | Employee time clock + payroll | NOT_REPLACED | none | Workers can't clock in |
| `routes/employee-*.cjs` | Employee management endpoints | NOT_REPLACED | none | Production portal depends on these |
| `lib/stripe.cjs` | Stripe client library | NOT_REPLACED | none | All payment routes depend on this |
| `lib/email.cjs` | Resend email client | NOT_REPLACED | none | All transactional email |
| `lib/twilio.cjs` | Twilio SMS client | NOT_REPLACED | none | All SMS notifications |

### 2c. Legacy Data Layer

| table group | tables | status | replacement_target | evidence |
|---|---|---|---|---|
| Order/Product (7) | orders, imprints, mockups, customers, purchase_orders, purchase_order_items, order_status_history | NOT_REPLACED | none | Every route queries these; core business data |
| Financial (5) | expenses, expense_categories, vendors, fees, finance_event_map | PARTIALLY_REPLACED | `finance-adapter` (new events only) | Legacy expenses need ETL for historical |
| Production (6) | production_steps, stations, imprint_assignments, step_history, receiving_logs, job_step_logs | NOT_REPLACED | none | Production scheduling depends on these |
| Pricing (9+) | screen_print_prices, embroidery_prices, pricing_quantity_tiers, laser_prices, transfer_prices, customer_pricing_rules, service_addons, setup_fees, price_matrices | NOT_REPLACED | `pricing` reads legacy; no migration schema | Quote accuracy depends on these |
| Timekeeping (5) | time_entries, time_entry_breaks, pay_periods, employee_timekeeping_settings, time_entry_corrections | NOT_REPLACED | none | Payroll broken without |
| Admin/Auth (2) | dashboard_admins, dashboard_admin_sessions | NOT_REPLACED | none | Access control |
| Communication (2) | message_templates, communication_log | NOT_REPLACED | none | CRM feature |
| AI (3) | ai_sessions, ai_messages, ai_knowledge | NOT_REPLACED | none | AI chat history |
| Supplier (2) | supplier_sync_runs, supplier_price_changes | PARTIALLY_REPLACED | `suppliers` (reads legacy) | Sync tracking |
| Artwork (7) | artwork_seeds, artwork_jobs, artwork_assets, artwork_asset_links, artwork_contacts, artwork_job_gates, artwork_job_seed_links | ALREADY_REPLACED | `mint-modules/artwork` | Greenfield; zero legacy dependency |
| Shipping (1) | shipping_labels | PARTIALLY_REPLACED | `mint-modules/shipping` | ETL may be needed if schema differs |

### 2d. Integrations & Automations

| integration | legacy_path | status | replacement | evidence |
|---|---|---|---|---|
| Stripe payments | `lib/stripe.cjs`, `routes/order-payments.cjs`, `routes/stripe-webhooks.cjs` | NOT_REPLACED | none | No webhook receiver in mint |
| Resend email | `lib/email.cjs` | PARTIALLY_REPLACED | communications-agent (spine level) | Not wired into mint transactional flow |
| Twilio SMS | `lib/twilio.cjs` | PARTIALLY_REPLACED | communications-agent (spine level) | Not wired into mint transactional flow |
| EasyPost shipping | `routes/shipping.cjs` + `lib/easypost.cjs` | ALREADY_REPLACED | `mint-modules/shipping` | Backend replacement confirmed |
| EasyPost webhooks | webhook handler in shipping routes | NOT_REPLACED | none | Tracking updates break |
| n8n workflows (40) | n8n instance on docker-host | PARTIALLY_REPLACED | no defined strategy | 8 order, 6 payment, 12 data sync, 6 media, 3 reporting workflows |
| n8n MCP integration | n8n → Claude Code bridge | NOT_REPLACED | none | AI automation capability lost |
| Printavo sync | `routes/printavo-*.cjs` | NOT_REPLACED | none | Legacy PSM bridge |
| Firefly III | `finance-adapter` | PARTIALLY_REPLACED | `mint-modules/finance-adapter` | New events OK; historical ETL needed |
| Supplier APIs | `scripts/suppliers/*.py` | PARTIALLY_REPLACED | `mint-modules/suppliers` | Python runtime not on fresh-slate |
| MinIO storage | `lib/minio.cjs` + file routes | PARTIALLY_REPLACED | `artwork` uses MinIO | Other file ops not covered |
| Shopify | referenced in codebase | UNKNOWN | none | Likely inactive |

### 2e. Infrastructure & Runtime

| component | legacy_path | status | replacement | evidence |
|---|---|---|---|---|
| Core docker-compose (postgres, redis, dashboards) | `infrastructure/docker-compose.yml` | NOT_REPLACED | `mint-modules/deploy/` (minimal) | Legacy stack still runs production |
| Monitoring (prometheus, alertmanager, cAdvisor) | `infrastructure/monitoring/` | NOT_REPLACED | none | No observability in mint |
| Cloudflare tunnel | `infrastructure/cloudflare/tunnel/` | NOT_REPLACED | none | External routing breaks |
| 9 macOS launchd agents | `infrastructure/launchd/` | NOT_REPLACED | none | Backup verification, secrets drift, paperless intake |
| MinIO compose | `infrastructure/storage/` | PARTIALLY_REPLACED | mint-data VM has MinIO | Config may differ |
| Deployment scripts | `scripts/deploy-*.sh` | NOT_REPLACED | none | No CI/CD in mint |
| Secrets sync (Infisical) | `scripts/load-secrets.sh`, `scripts/sync-secrets-to-env.sh` | NOT_REPLACED | none | Services fail to start |

---

## 3. Roadmap Additions Table

Items below are NOT in the existing `MINT_PRINTS_FLOW_REPLACEMENT_ROADMAP_20260222.md` or `MINT_MODULE_EXECUTION_QUEUE.md` as explicit work items.

| item_id | title | priority | impact_area | dependency | acceptance_criteria | source_evidence_paths |
|---|---|---|---|---|---|---|
| LEG-001 | Auth module extraction (JWT + PIN + admin sessions) | P0 | auth/portal/ops | Blocks all portal + API access | 1) JWT issuance + validation works for customers 2) PIN auth works for production employees 3) Admin session management functional | `routes/auth.cjs`, `routes/admin-auth.cjs`, `dashboard_admins` table |
| LEG-002 | Stripe webhook receiver module | P0 | payment | Blocks payment reconciliation | 1) Receives + verifies Stripe webhook signatures 2) Idempotent event processing 3) Updates order payment status | `routes/stripe-webhooks.cjs`, `lib/stripe.cjs` |
| LEG-003 | Payment management module (checkout + deposits + refunds) | P0 | payment | Depends on LEG-001 (auth), LEG-002 (webhooks) | 1) Create checkout session with 50% deposit 2) Process refunds 3) Track payment balance per order | `routes/v2-checkout.cjs`, `routes/order-payments.cjs` |
| LEG-004 | Order full lifecycle management | P0 | quote/pricing/ops | Depends on LEG-001, LEG-003; extends existing `order-intake` | 1) Order CRUD beyond intake validation 2) Line item management 3) Status transitions | `routes/v2-jobs.cjs` (4,347 lines) |
| LEG-005 | Customer management module | P1 | portal/ops | Depends on LEG-001 | 1) Customer CRUD + search 2) Customer 360 view data 3) Filtering + pagination | `routes/v2-customers.cjs`, `routes/customers-legacy.cjs` |
| LEG-006 | Notifications module (transactional email + SMS) | P1 | ops/portal | Partially addressed in roadmap as "Resend live cutover"; needs explicit module scope | 1) Resend email sends for quote/payment/status events 2) Twilio SMS for critical alerts 3) Template management | `lib/email.cjs`, `lib/twilio.cjs`, `routes/notifications.cjs` |
| LEG-007 | Production portal replacement | P1 | ops | Depends on LEG-001 (PIN auth), LEG-004 (jobs) | 1) PIN login works 2) Job queue displays 3) Time clock in/out functional | `apps/production/` entire app |
| LEG-008 | Admin portal replacement (or API-first migration) | P1 | portal/ops | Depends on LEG-004, LEG-005 | 1) Order list + detail views 2) Customer search 3) Dashboard analytics | `apps/admin/` entire app |
| LEG-009 | Customer portal module | P2 | portal | Depends on LEG-001, LEG-004 | 1) Self-serve order history 2) Tracking view 3) Payment initiation | `routes/customer-portal.cjs` |
| LEG-010 | Timekeeping/payroll module | P1 | ops | Depends on LEG-001, LEG-007 | 1) Clock in/out 2) Break tracking 3) Pay period management | `routes/timekeeping.cjs`, 5 timekeeping tables |
| LEG-011 | Communication history / CRM module | P2 | ops | Depends on LEG-005 | 1) Log customer interactions 2) Search history 3) Template management | `routes/v2-communications.cjs` (21K lines), `communication_log` table |
| LEG-012 | EasyPost webhook handler | P1 | shipping | Extends existing `mint-modules/shipping` | 1) Receives EasyPost tracking webhooks 2) Updates shipment status 3) Triggers notification | Webhook handling in legacy shipping routes |
| LEG-013 | n8n workflow replacement strategy | P1 | ops/automation | Cross-cutting; 40 workflows | 1) Inventory all 40 workflows with input/output 2) Decide: keep n8n / rebuild in event bus / hybrid 3) Migrate legacy-endpoint-dependent workflows | n8n instance, 8 order + 6 payment + 12 sync workflows |
| LEG-014 | Cloudflare tunnel migration | P0 | infra | Blocks external access to mint-apps | 1) Tunnel routes to mint-apps VM 213 2) All public URLs resolve 3) Legacy tunnel can be decommissioned | `infrastructure/cloudflare/tunnel/` |
| LEG-015 | Secrets management for mint-modules | P0 | infra | Blocks service startup | 1) Infisical projects for each mint module 2) Secret sync scripts 3) Drift detection | `scripts/load-secrets.sh`, `scripts/sync-secrets-to-env.sh` |
| LEG-016 | Database migration strategy for 30+ legacy tables | P1 | data | Cross-cutting; blocks full cutover | 1) Migration scripts for core tables (orders, customers, pricing) 2) ETL plan for historical data 3) Dual-write strategy during transition | 18 SQL migration files in `apps/api/migrations/` |
| LEG-017 | Monitoring + observability stack | P2 | infra/ops | Nice-to-have but important for production confidence | 1) Prometheus config for mint-apps 2) Alertmanager rules 3) Health dashboard | `infrastructure/monitoring/` |
| LEG-018 | Launchd ops agents migration | P2 | infra/ops | 9 agents for backup, secrets, paperless | 1) Backup verification runs on schedule 2) Secrets drift detected 3) Paperless receipt ingestion works | `infrastructure/launchd/` |
| LEG-019 | Supplier sync Python runtime on fresh-slate | P1 | suppliers | Blocks `LOOP-MINT-SUPPLIERS-PHASE0-CONTRACT` | 1) Python 3 runtime containerized on mint-apps 2) base_supplier.py + 3 plugins run 3) Hourly cron operational | `scripts/suppliers/`, noted in MINT_MODULE_EXECUTION_QUEUE.md as blocker |
| LEG-020 | File management / MinIO integration beyond artwork | P2 | ops | Depends on LEG-004 | 1) General file upload for orders 2) Production file management 3) File integrity validation | `routes/file-management.cjs`, `scripts/validate-artwork-integrity.sh` |
| LEG-021 | 12K file rename completion | P1 | ops/data | Blocks clean mint takeover | 1) All production files renamed from UUID to visual_id 2) Integrity validation passes 3) OneDrive sync confirmed | `scripts/rename-production-files.sh` |
| LEG-022 | Dashboard stats / reporting module | P2 | ops | Depends on LEG-004, LEG-005 | 1) Revenue metrics 2) Order status counts 3) Pending work visibility | `routes/dashboard-stats.cjs` |
| LEG-023 | Shared packages port (@mint-os/types, config, api-client) | P1 | cross-cutting | Blocks frontend migration | 1) Type definitions ported or replaced 2) Config patterns equivalent 3) API client updated for mint endpoints | `mint-os/packages/` |
| LEG-024 | Pricing data migration (9+ tables) | P1 | pricing | Blocks `pricing` module going live | 1) All pricing tables migrated to mint-modules ownership 2) Historical pricing preserved 3) A/B test confirms parity | 9+ pricing tables in `016_pricing_engine_schema.sql` |
| LEG-025 | Web storefront replacement (product catalog + designer + checkout) | P2 | portal/revenue | Depends on LEG-001, LEG-003, LEG-004 | 1) Product browsing works 2) Design tool functional 3) Checkout flow end-to-end | `apps/web/` entire app |

---

## 4. Contradictions & Unknowns

### Contradictions

1. **Pricing module scope ambiguity** — `MINT_MODULE_EXECUTION_QUEUE.md` lists pricing as "Rank 1, lowest coupling, ready to extract" but the legacy `job-estimator` app has 85+ tests, an OpenAPI spec, and covers laser/DTF/embroidery tiers. The mint-modules `pricing` README is empty. The queue doc also flags "job-estimator deprecation decision — MUST be answered before Phase 0." This is unresolved.

2. **Suppliers module dual-existence** — Both legacy `scripts/suppliers/*.py` (Python) and `mint-modules/suppliers` (TypeScript) exist. The execution queue says suppliers is "Rank 3, highest complexity" and notes "no Python runtime on fresh-slate." Yet the suppliers module in mint-modules appears to have TypeScript sync handlers. Unclear which is authoritative or if both run concurrently.

3. **Notifications vs. communications-agent** — The spine-level `communications-agent` MCP exists with Resend/Twilio/Graph capabilities. The roadmap says "Resend live cutover" is P0. But the legacy `lib/email.cjs` and `lib/twilio.cjs` are not simply Resend/Twilio calls — they include templating, per-event routing, and retry logic. The communications-agent may not cover the full transactional notification flow.

4. **Shipping UI gap** — The roadmap treats shipping as a backend extraction (`LOOP-MINT-SHIPPING-PHASE0-CONTRACT`), but the legacy `apps/shipping/` is a full React UI for label building and rate shopping. The backend module won't replace the operator-facing UI.

### Unknowns Requiring Verification

| # | What's unknown | How to verify | Why it matters |
|---|---|---|---|
| U-1 | Is `apps/suppliers/` a functional app or a stub? | Check if it's used in production docker-compose | May not need migration at all |
| U-2 | Does `mint-modules/pricing` implement the same rule engine as legacy `job-estimator`? | Compare test suites and API surface | Pricing parity is revenue-critical |
| U-3 | Are all 40 n8n workflows still active? | Query n8n API for execution counts in last 30 days | Some may be decommissionable |
| U-4 | Does the Shopify integration still run? | Check for recent Shopify API calls in logs | May be dead code |
| U-5 | What's the status of the 12K file rename? How many remain? | Run `rename-production-files.sh --dry-run` | Blocks clean mint data handoff |
| U-6 | Do `@mint-os/types` and `@mint/shared-types` overlap? | Diff exported type definitions | Determines porting effort |
| U-7 | Is the Printavo sync still needed? | Check if Printavo is still used operationally | May be fully deprecated |
| U-8 | Which launchd agents are still firing successfully? | Check `~/Library/LaunchAgents/` + system logs | Some may have silently failed |
| U-9 | What's the actual table-by-table write frequency in legacy DB? | Query `pg_stat_user_tables` for last 30 days | Prioritizes migration order |
| U-10 | Does SanMar route (`routes/sanmar-routes.cjs`) need its own module? | Check call frequency and whether suppliers module covers it | May be redundant |

---

## 5. Recommended Next 3 Execution Loops

### Loop 1: `LOOP-LEG-AUTH-PAYMENT-EXTRACTION-CONTRACT` (P0)

**Why first:** Auth and payments are the two capabilities where zero replacement exists AND absence blocks revenue. The roadmap mentions "Payment extraction strategy" as a gap but has no contract or execution plan.

**Scope:**
- Define auth boundary contract (JWT issuance, PIN auth, admin sessions)
- Define payment boundary contract (Stripe client, checkout, webhooks, refunds)
- Determine if these are 1 module or 2
- Produce acceptance criteria + 5-gate plan per MINT_MODULE_EXECUTION_QUEUE template

**Inputs:** `routes/auth.cjs`, `routes/admin-auth.cjs`, `lib/stripe.cjs`, `routes/stripe-webhooks.cjs`, `routes/order-payments.cjs`, `routes/v2-checkout.cjs`

**Outputs:** `MINT_AUTH_CONTRACT_V1.md`, `MINT_PAYMENT_CONTRACT_V1.md`, updated `MINT_MODULE_EXECUTION_QUEUE.md`

---

### Loop 2: `LOOP-LEG-NOTIFICATION-WIRING` (P0/P1)

**Why second:** The roadmap already flags "Resend live cutover" as P0. But the gap is larger than just Resend — it's the entire notification coordinator that routes events → templates → channels. This loop closes the gap between the spine-level communications-agent and the mint-modules transactional flow.

**Scope:**
- Audit all notification trigger points in legacy (quote created, payment received, order status change, etc.)
- Map each to communications-agent capabilities
- Identify gaps (templating, per-event routing, retry)
- Produce wiring contract: event → template → channel → delivery

**Inputs:** `lib/email.cjs`, `lib/twilio.cjs`, `routes/notifications.cjs`, communications-agent MCP tools

**Outputs:** `MINT_NOTIFICATIONS_CONTRACT_V1.md`, event→channel mapping table, integration test plan

---

### Loop 3: `LOOP-LEG-LEGACY-TABLE-OWNERSHIP-AUDIT` (P1)

**Why third:** Every module extraction (pricing, shipping, suppliers, order) is blocked by unclear table ownership. The execution queue's 5-gate template requires "table ownership transfer" at the SCHEMA gate. This loop produces the definitive table ownership map.

**Scope:**
- Query `pg_stat_user_tables` on production DB for write frequency per table
- Classify every table as: mint-module-owned, legacy-only, shared, or deprecated
- For shared tables, define dual-write strategy and cutover sequence
- Produce migration dependency graph

**Inputs:** 18 legacy migration files, mint-modules migration files, production DB stats

**Outputs:** `MINT_TABLE_OWNERSHIP_MAP.md`, migration dependency DAG, recommended extraction order

---

## Appendix: Items Already on Roadmap (Cross-Reference)

These are already planned in `MINT_PRINTS_FLOW_REPLACEMENT_ROADMAP_20260222.md` or `MINT_MODULE_EXECUTION_QUEUE.md` and do NOT need new roadmap items:

| existing item | status | notes |
|---|---|---|
| Deploy pricing module (Phase A) | Planned, Rank 1 | Blocked by job-estimator deprecation decision |
| Deploy shipping module (Phase A) | Planned, Rank 2 | Blocked by table ownership + PIN auth replacement |
| Deploy suppliers module (Phase A) | Planned, Rank 3 | Blocked by Python runtime + AS Colour images (#525) |
| Cross-module integration gate (Rank 4) | Planned | Depends on Ranks 1-3 |
| Finance adapter parallel track | Planned, in-progress | GAP-OP-802 (missing key) is P0 |
| Resend live cutover (Phase B) | Planned, P0 | Scope needs expansion (see Loop 2) |
| Order/payment extraction (Phase C) | Planned, P2 | Needs contract (see Loop 1) |
| Portal replacement (Phase D) | Planned, P2 | Needs scope definition |
| Legacy decommission (Phase E) | Planned | Depends on all above |
