---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-table-ownership-map-gate1
loop_id: LOOP-MINT-TABLE-OWNERSHIP-AUDIT-20260222
---

# MINT Table Ownership Map (Gate 1)

Contract-only artifact. No schema/runtime mutation.

Evidence set:
- Existing ownership SSOT: `/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/DATABASE_OWNERSHIP.md:20-60`
- Legacy migrations: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/migrations/*.sql`
- Mint migrations: `/Users/ronnyworks/code/mint-modules/*/migrations/*.sql`
- Legacy order/auth/payment runtime writes: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/v2-jobs.cjs`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/auth.cjs`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/admin-auth.cjs`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/employee.cjs`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/stripe-webhooks.cjs`, `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/v2-checkout.cjs`
- Artwork legacy-compat writes: `/Users/ronnyworks/code/mint-modules/artwork/src/services/db.ts:186-446`

Classification legend:
- `mint-owned`: migration exists in mint-modules and module is designated writer
- `legacy-only`: only legacy currently writes; mint replacement migration missing
- `shared`: both legacy and mint read; one side is writer by contract
- `deprecated`: legacy artifact targeted for retirement
- `UNKNOWN`: cannot be proven from files alone

## 1) Tables Already In DATABASE_OWNERSHIP.md (confirm/drift)

| table | current SSOT claim | observed from code/migrations | classification | note |
|---|---|---|---|---|
| `finance_event_map` | finance-adapter owned | Created in mint migration (`finance-adapter/migrations/20260212_finance_event_map.sql:8`) | mint-owned | confirmed |
| `orders` | legacy-owned writer | Legacy writes throughout `v2-jobs` and payment routes (`v2-jobs.cjs:1105`, `stripe-webhooks.cjs:174`, `v2-checkout.cjs:167`) | legacy-only | conflict candidate for Rank 6/7 |
| `line_items` | legacy-owned writer | Legacy inserts/updates/deletes in `v2-jobs.cjs:1185`, `v2-jobs.cjs:1364`, `v2-jobs.cjs:1410` | legacy-only | conflict candidate for Rank 7 |
| `imprints` | legacy-owned writer | Legacy inserts/updates/deletes in `v2-jobs.cjs:2021`, `v2-jobs.cjs:2179`, `v2-jobs.cjs:2258` | legacy-only | confirmed |
| `imprints_line_item_lnk` | legacy-owned writer | Legacy inserts/deletes in `v2-jobs.cjs:2050`, `v2-jobs.cjs:2252` | legacy-only | confirmed |
| `payments` | legacy-owned writer | Legacy inserts in `v2-jobs.cjs:1562` and `stripe-webhooks.cjs:188` | legacy-only | conflict candidate for Rank 6/7 |
| `shipping_labels` | legacy-owned writer | Also created in mint shipping migration (`shipping/migrations/001_create_shipping_labels.sql:6`) | shared | SSOT drift; needs cutover writer lock |
| `job_files` | artwork owned | No mint migration for `job_files`; artwork service still writes legacy table (`db.ts:279`) | shared | SSOT drift |
| `customer_artwork` | artwork owned | No mint migration or active writer evidence in artwork module | UNKNOWN | SSOT drift |
| `production_files` | legacy-owned | Legacy writes from `v2-jobs.cjs:3069` and artwork module reads (`db.ts:390`) | shared | single writer legacy |
| `line_item_mockups` | legacy-owned | Legacy writes (`v2-jobs.cjs:2900`) and artwork reads (`db.ts:394`) | shared | single writer legacy |
| `imprint_mockups` | legacy-owned | Legacy writes (`v2-jobs.cjs:3177`) and artwork reads (`db.ts:398`) | shared | single writer legacy |
| `employees` | legacy-owned | PIN auth and timekeeping read/write (`employee.cjs:141`, `employee.cjs:1216`) | legacy-only | auth/timekeeping dependency |
| `time_entries` | legacy-owned | PIN timekeeping writes (`employee.cjs:831`, `employee.cjs:922`) | legacy-only | auth/timekeeping dependency |
| `production_steps`, `stations`, `tasks`, `fees`, `expenses` | legacy-owned | Legacy-only route/migration evidence | legacy-only | confirmed |
| `decoration_types`, `printavo_statuses`, `line_item_categories`, `customer_tag_types` | shared lookup (read-only) | Read/validation only in routes (`v2-jobs.cjs:139-142`, `v2-jobs.cjs:1070`) | shared | confirmed |

## 2) New Classifications (tables not listed in DATABASE_OWNERSHIP.md)

### 2.1 Legacy migrations / runtime tables

| table | evidence | classification | owning/writing surface today |
|---|---|---|---|
| `dashboard_admins` | `migrations/004_admin_users.sql:7`, `admin-auth.cjs:49` | legacy-only | legacy admin auth route |
| `dashboard_admin_sessions` | `migrations/004_admin_users.sql:23` | legacy-only | legacy admin/session path |
| `admin_users` | `auth.cjs:393` | UNKNOWN | referenced by legacy auth only; migration not found |
| `communication_log` | `migrations/021_communication_system.sql:173`, `v2-communications.cjs:379` | legacy-only | legacy communications route |
| `message_templates` | `migrations/021_communication_system.sql:46`, `v2-communications.cjs:90` | legacy-only | legacy communications route |
| `supplier_products` | `migrations/001_feature_tables.sql:231`, `migrations/019_supplier_integration_framework.sql:80` | legacy-only | legacy suppliers sync |
| `suppliers` | `migrations/001_feature_tables.sql:208` | legacy-only | legacy suppliers sync |
| `supplier_sync_runs` | `migrations/019_supplier_integration_framework.sql:159` | legacy-only | legacy suppliers sync |
| `supplier_price_changes` | `migrations/018_supplier_sync_tracking.sql:18` | legacy-only | legacy suppliers sync |
| `price_matrices` | `migrations/001_feature_tables.sql:308` | legacy-only | legacy pricing stack |
| `customer_pricing_rules` | `migrations/013_customer_pricing_tiers.sql:19` | legacy-only | legacy pricing stack |
| `pricing_quantity_tiers` | `migrations/016_pricing_engine_schema.sql:8` | legacy-only | legacy pricing stack |
| `screen_print_prices` | `migrations/016_pricing_engine_schema.sql:39` | legacy-only | legacy pricing stack |
| `embroidery_stitch_tiers` | `migrations/016_pricing_engine_schema.sql:54` | legacy-only | legacy pricing stack |
| `embroidery_prices` | `migrations/016_pricing_engine_schema.sql:82` | legacy-only | legacy pricing stack |
| `laser_sizes` | `migrations/016_pricing_engine_schema.sql:95` | legacy-only | legacy pricing stack |
| `laser_prices` | `migrations/016_pricing_engine_schema.sql:112` | legacy-only | legacy pricing stack |
| `transfer_types` | `migrations/016_pricing_engine_schema.sql:125` | legacy-only | legacy pricing stack |
| `transfer_sizes` | `migrations/016_pricing_engine_schema.sql:163` | legacy-only | legacy pricing stack |
| `transfer_prices` | `migrations/016_pricing_engine_schema.sql:183` | legacy-only | legacy pricing stack |
| `setup_fees` | `migrations/016_pricing_engine_schema.sql:196` | legacy-only | legacy pricing stack |
| `service_addons` | `migrations/016_pricing_engine_schema.sql:218` | legacy-only | legacy pricing stack |
| `purchase_orders` | `migrations/001_feature_tables.sql:262` | legacy-only | legacy purchasing |
| `purchase_order_items` | `migrations/001_feature_tables.sql:291` | legacy-only | legacy purchasing |
| `expense_categories` | `migrations/001_feature_tables.sql:17` | legacy-only | legacy finance |
| `vendors` | `migrations/001_feature_tables.sql:46` | legacy-only | legacy finance |
| `order_status_history` | `migrations/007_printavo_sync_updates.sql:102` | legacy-only | legacy order lifecycle |
| `job_step_logs` | `migrations/010_job_step_tracking.sql:6` | legacy-only | legacy production lifecycle |
| `receiving_logs` | `migrations/010_job_step_tracking.sql:25` | legacy-only | legacy production lifecycle |
| `imprint_assignments` | `migrations/001_feature_tables.sql:169` | legacy-only | legacy production lifecycle |
| `step_history` | `migrations/001_feature_tables.sql:192` | legacy-only | legacy production lifecycle |
| `time_entry_breaks` | `migrations/006_timekeeping_system.sql:80`, `employee.cjs:903` | legacy-only | PIN timekeeping |
| `time_entry_corrections` | `migrations/006_timekeeping_system.sql:151` | legacy-only | PIN/admin timekeeping |
| `pay_periods` | `migrations/006_timekeeping_system.sql:111` | legacy-only | PIN/admin timekeeping |
| `employee_timekeeping_settings` | `migrations/006_timekeeping_system.sql:182`, `employee.cjs:1220` | legacy-only | PIN/admin timekeeping |
| `production_time_entries` | runtime DDL in `employee.cjs:267` | UNKNOWN | dynamically created by legacy route |
| `activity_log` | writes in `v2-jobs.cjs:4273`, `v2-jobs.cjs:4327` | UNKNOWN | table definition not found in migrations set |
| `ai_sessions`, `ai_messages`, `ai_knowledge` | `migrations/003_ai_tables.sql` | UNKNOWN | no replacement/usage proof in mint-modules |
| `shipments` | `migrations/001_create_shipments.sql:4` | UNKNOWN | replacement relation to `shipping_labels` not proven |
| `mockups` | `migrations/007_printavo_sync_updates.sql:72`, deprecated by comment in `v2-jobs.cjs:17` | deprecated | superseded by `line_item_mockups`/`imprint_mockups` |

### 2.2 Mint migration tables not represented in current ownership SSOT

| table | evidence | classification | note |
|---|---|---|---|
| `artwork_contacts` | `artwork/migrations/20260128_artwork_ticket_model.sql:16` | mint-owned | should be added to ownership SSOT |
| `artwork_seeds` | `artwork/migrations/20260128_artwork_ticket_model.sql:40` | mint-owned | should be added to ownership SSOT |
| `artwork_jobs` | `artwork/migrations/20260128_artwork_ticket_model.sql:63` | mint-owned | should be added to ownership SSOT |
| `artwork_job_gates` | `artwork/migrations/20260128_artwork_ticket_model.sql:86` | mint-owned | should be added to ownership SSOT |
| `artwork_job_seed_links` | `artwork/migrations/20260128_artwork_ticket_model.sql:106` | mint-owned | should be added to ownership SSOT |
| `artwork_assets` | `artwork/migrations/20260128_artwork_ticket_model.sql:117` | mint-owned | should be added to ownership SSOT |
| `artwork_asset_links` | `artwork/migrations/20260128_artwork_ticket_model.sql:135` | mint-owned | should be added to ownership SSOT |

## 3) Conflict Check (planned Rank 5+ module writes)

STOP condition reached: multiple planned modules require writes to the same legacy tables.

| table | module A write need | module B write need | evidence |
|---|---|---|---|
| `orders` | Payment updates status/amounts/session (`stripe-webhooks.cjs:174`, `order-payments.cjs:144`) | Order-lifecycle updates status/customer/totals (`v2-jobs.cjs:1105`, `v2-jobs.cjs:183`) | unresolved ownership conflict |
| `payments` | Payment module inserts records (`stripe-webhooks.cjs:188`) | Order-lifecycle also inserts manual payments (`v2-jobs.cjs:1562`) | unresolved ownership conflict |
| `customers` | Auth module customer signup/profile writes (`auth.cjs:170`, `auth.cjs:345`) | Order-lifecycle checkout creates/finds customers (`v2-checkout.cjs:120`, `v2-checkout.cjs:130`) | unresolved ownership conflict |
| `activity_log` | Notification dispatch history likely target | Order-lifecycle currently writes SMS/invoice events (`v2-jobs.cjs:4273`, `v2-jobs.cjs:4327`) | table definition unresolved |

Operator decision required before Gate 2 for Rank 5-8.

## 4) Migration Dependency Order (FK topological sequence)

### Legacy chain (from migration FK refs)

1. Foundation tables with no declared FK dependencies in this migration set:  
`suppliers`, `vendors`, `expense_categories`, `production_steps`, `stations`, `dashboard_admins`, `pay_periods`, `pricing_quantity_tiers`, `embroidery_stitch_tiers`, `laser_sizes`, `transfer_types`, `transfer_sizes`, `message_templates`, `shipments`, `price_matrices`.

2. First dependent wave:  
`supplier_products -> suppliers`, `purchase_orders -> suppliers,orders`, `payments -> orders`, `imprints -> orders`, `production_files -> orders`, `tasks -> orders`, `fees -> orders`, `expenses -> orders,vendors`, `time_entries -> employees`, `ai_sessions -> customers`.

3. Second dependent wave:  
`purchase_order_items -> purchase_orders,supplier_products`, `imprint_assignments -> imprints,orders,stations,production_steps`, `order_status_history -> orders`, `time_entry_breaks -> time_entries`, `time_entry_corrections -> time_entries`, `employee_timekeeping_settings -> employees`, `supplier_sync_runs -> suppliers`, `ai_messages -> ai_sessions`.

4. Third dependent wave:  
`step_history -> imprint_assignments,production_steps,employees`, `communication_log -> customers,orders,message_templates`.

### Mint-native chain

1. `artwork_contacts` (root)
2. `artwork_seeds` and `artwork_jobs` (depend on `artwork_contacts`)
3. `artwork_job_gates` (depends on `artwork_jobs`)
4. `artwork_job_seed_links` (depends on `artwork_jobs` + `artwork_seeds`)
5. `artwork_assets` (root)
6. `artwork_asset_links` (depends on `artwork_assets`)
7. `finance_event_map` (root)
8. `shipping_labels` (root, logical `order_id` only; no FK)

## Gate 1 Outcome

- Ownership map can proceed for review.
- Gate 2 for Rank 5+ is blocked on operator ownership decisions for `orders`, `payments`, `customers`, and `activity_log`.
