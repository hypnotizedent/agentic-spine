---
status: draft
owner: "@ronny"
created: 2026-02-22
last_updated: 2026-02-22
scope: mint-prints-flow-replacement-roadmap
authority:
  - terminal evidence dump (2026-02-21)
  - user-provided SPINE-AUDIT-01 snapshot (2026-02-22)
  - CAP-20260221-222911__mint.deploy.status__Rm09d49504
  - CAP-20260221-222911__mint.modules.health__Ru4rn49506
  - CAP-20260221-222920__docker.compose.status__R9wxf49505
  - CAP-20260221-222920__docker.compose.status__Rfa3j50380
  - CAP-20260221-222920__docker.compose.status__Rpxv550381
  - CAP-20260221-222920__services.health.status__R6a9750396
  - CAP-20260221-223016__cloudflare.tunnel.ingress.status__Rjjf652069
  - CAP-20260221-223319__mint.deploy.status__Rtign68104
  - CAP-20260221-223321__mint.modules.health__R9ppz68421
  - CAP-20260221-223324__docker.compose.status__Rssel68704
  - CAP-20260221-223326__docker.compose.status__Rsn0169000
  - CAP-20260221-223328__docker.compose.status__R8md069298
  - CAP-20260221-223331__services.health.status__Rb1qd69657
  - CAP-20260221-223345__cloudflare.tunnel.ingress.status__Rr8dn70524
  - CAP-20260221-221353__verify.pack.run__Rbim82547
references:
  - /Users/ronnyworks/code/mint-modules/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md
  - /Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md
  - /Users/ronnyworks/code/agentic-spine/docs/governance/MINT_PRODUCT_GOVERNANCE.md
  - /Users/ronnyworks/code/agentic-spine/docs/planning/LEGACY_DELTA_AUDIT_20260222.md
---

# Mint Prints Flow Replacement Roadmap (Evening Baseline)

## NON-NEGOTIABLES

**NO MINT OS LEGACY DEPPENDACY, EVERYTHING SHOULD BE NEW/FRESH**

**AGNET FIRST**

## DECISION LOCK (Interview 2026-02-22)

| Topic | Locked Decision |
|---|---|
| Next 7-day focus | Inventory + documentation truth first (no broad build push this week) |
| Legacy hold start | Start now |
| Legacy hold duration | 90 days |
| API ingress now | Per-module hostnames now; gateway consolidation is a future project |
| Auth strategy | Port legacy JWT model into fresh-slate |
| Payments | Full Stripe/payment extraction into fresh-slate (not legacy bridge-only) |
| Portal/UI priority | No UI build now; API-first. When UI work starts, apply AOF UI normalization from day 1 |
| Agent autonomy | Fully autonomous where possible (agent-first operating model) |
| Cutover framing | Treat this as migration activation/normalization work, not “protect an already-working legacy product” |
| Terminal model | You + me: single writer roadmap mode, I act as technical translator |
| Proposal handling | Supersede pending module-loop proposals; use simpler roadmap-led execution |
| Deliverable shape | One doc containing VM truth table + decision log + prioritized queue |

## 1) Objective

Convert scattered Mint migration context into one execution roadmap focused on replacing manual/operator-heavy business flow with governed module + automation flow.

This document is planning-only. No runtime cutover is implied by this artifact.

## 2) Current Reality (as of 2026-02-22)

### Fresh-slate runtime that is live now

| Surface | Component | Host | Port | State |
|---|---|---|---|---|
| Data plane | PostgreSQL | mint-data (VM 212) | 5432 | healthy |
| Data plane | MinIO | mint-data (VM 212) | 9000/9001 | healthy |
| Data plane | Redis | mint-data (VM 212) | 6379 | healthy |
| App plane | files-api | mint-apps (VM 213) | 3500 | healthy |
| App plane | quote-page | mint-apps (VM 213) | 3341 | healthy |
| App plane | order-intake | mint-apps (VM 213) | 3400 | healthy |
| App plane | finance-adapter | mint-apps (VM 213) | 3600 | healthy |
| App plane | pricing | mint-apps (VM 213) | 3700 | healthy |
| App plane | suppliers | mint-apps (VM 213) | 3800 | healthy |
| App plane | shipping | mint-apps (VM 213) | 3900 | healthy |

### Legacy docker-host runtime still active

| Legacy stack on VM 200 | Running containers | State |
|---|---:|---|
| `mint-os` | 9/9 | active |
| `artwork-module` | 3/3 | active |
| `quote-page` | 3/3 | active |
| `dashy` | 1/1 | active |

### Public routing cutover status (Cloudflare ingress)

| Route | Current ingress target | Status |
|---|---|---|
| `pricing.mintprints.co` | `http://100.92.156.118:3001` | legacy target |
| `shipping.mintprints.co` | `http://mint-os-dashboard-api:3335` | legacy target |
| `api.mintprints.co` | `http://mint-os-dashboard-api:3335` | legacy target |
| `admin.mintprints.co` | `http://mint-os-admin:3333` | legacy target |
| `production.mintprints.co` | `http://mint-os-production:3336` | legacy target |
| `customer.mintprints.co` | `http://quote-page:3341` | mapped via tunnel service alias (must be explicitly verified against host source) |

Route summary (audit snapshot):
- Done: 6 routes (quote-page + minio/file hostnames).
- Not started: 12 routes, mostly legacy monolith portals/API endpoints.

### Monitoring/registry drift to fix immediately

- `mint.deploy.status` and `docker.compose.status mint-apps` currently report only 4 app containers because stack binding tracks `/opt/stacks/mint-apps/docker-compose.yml` only.
- Live mint-apps host has 7 active module containers (pricing/shipping/suppliers run as separate compose projects under `/opt/stacks/mint-apps/{pricing,shipping,suppliers}`).
- Roadmap implication: treat deployment as complete for module runtime, but incomplete for routing and governance inventory parity.
- On docker-host, compose stack accounting currently double-counts `mint-modules-prod` services under multiple stack aliases (needs binding cleanup).

### Still legacy-critical (docker-host / mint-os monolith path)

| Legacy capability | Current authority | Migration state |
|---|---|---|
| Orders, line items, imprints, customers, payments | `apps/api/dashboard-server.cjs` + `mint_os` DB | no replacement service yet |
| Auth (employee/PIN/JWT paths) | monolith | no fresh-slate auth service |
| Stripe payment lifecycle | monolith | not extracted |
| Customer/admin/production portals | `apps/web`, `apps/admin`, `apps/production` | not extracted |
| Notification completion (quote/payment/status) | mixed n8n + manual Outlook/Slack operations | partially automated, still human-dependent |

## 3) End-to-End Flow Coverage Matrix

Target business flow:
`Quote -> Seed -> Job -> Price -> Approve -> Pay -> Produce -> Ship -> Notify -> Reconcile`

| Flow segment | State now | Primary gap to close |
|---|---|---|
| Quote submit -> seed | live | none |
| Seed -> job bootstrap | live (A01 path) | harden idempotency + observability |
| Job -> pricing | partial | deploy pricing module + route traffic |
| Approval -> payment | legacy/manual-heavy | extract payment/order service boundary |
| Production status updates | mostly legacy/manual | event model + status API ownership |
| Shipping labels | legacy path | deploy shipping + replace employee-PIN auth path |
| Customer notifications | partial/manual | complete Resend/Twilio live cutover + template routing |
| Finance reconciliation | partial | close GAP-OP-802 (FINANCE_ADAPTER_API_KEY) |

## 4) Core Gaps That Block Full Employee-Independent Flow

| Gap | Why it matters | Minimum closure target |
|---|---|---|
| Unified API ingress | no single API surface for clients/workflows | gateway for module routing + version policy |
| Auth model for service and operator actions | shipping/suppliers cannot be safely exposed without replacement auth | service API keys now, user auth contract next |
| Payment extraction strategy | order-to-cash remains legacy-coupled | explicit Stripe bridge plan tied to new order service |
| Scheduler/runtime jobs | supplier sync and recurring jobs still legacy-host bound | containerized scheduler with governed receipts |
| Notifications completion | customer comms still partially manual | quote/payment/status notifications fully automated |
| Data continuity policy | no agreed historical access pattern | pick read-through or snapshot projection model |
| Portal strategy | operators still depend on legacy UIs | API-first portal replacement sequence |
| MCP endpoint alignment | tools may still point to legacy APIs | all tools target module-native endpoints |

## 5) Decision Log to Lock Before Build-Focused Loops

| Decision | Candidate options | Recommended default for next loops |
|---|---|---|
| API gateway | per-module DNS vs ingress | Per-module hostnames now; gateway consolidation later |
| Auth strategy | API keys, JWT, OAuth | Port legacy JWT model into fresh-slate |
| Payment migration | keep legacy-only vs bridge extraction vs full extraction | Full Stripe/payment extraction into fresh-slate |
| Historical data | hold now vs hold after cutover | Start 90-day legacy hold now (2026-02-22 to 2026-05-23) |
| Portals | keep legacy indefinitely vs phased replacement | API-first now; defer UI build until normalized AOF UI baseline is ready |
| Scheduler | host cron vs container cron vs workflow engine | containerized cron first, then optional workflow engine if needed |

## 6) Roadmap Sequence (No Time Estimates)

### Phase A: Truth and inventory normalization (this week focus)

Scope:
- Normalize stack inventory so governed status surfaces match actual runtime (7 containers on mint-apps).
- Normalize route inventory against Cloudflare ingress and live container targets.
- Capture one canonical VM/service/route matrix and keep it current.

Exit criteria:
- Governed status surfaces accurately show all intended mint-apps services running.
- Route matrix explicitly marks done vs not-started hostnames.
- Observability drift items are resolved or explicitly parked with owner.

### Phase B: Fresh-slate activation path (API and comms)

Scope:
- Resend/Twilio live credential readiness.
- Quote-ready and status-change notifications from fresh-slate events.
- n8n workflows stop requiring legacy API for quote intake path.

Exit criteria:
- Quote submission produces seed/job + customer notification without manual email.
- Workflow receipts show no legacy endpoint dependency in active path.

### Phase C: Extract order/payment/auth boundaries

Scope:
- Define and implement fresh-slate order domain boundary (orders, line items, customer refs).
- Full Stripe/payment flow into new boundary.
- Port legacy JWT model into fresh-slate auth boundary for protected routes.

Exit criteria:
- New order domain API serves module dependencies.
- Payment lifecycle can run without monolith write dependency for new orders.

### Phase D: Replace operator portal dependencies

Scope:
- API-first only in this phase; no major UI build.
- Prepare UI replacement contract with AOF UI normalization baseline so UI build starts from normalized patterns later.

Exit criteria:
- Core operational workflows execute without legacy admin/customer/production apps.

### Phase E: Legacy decommission runway

Scope:
- Transition docker-host to a deliberate legacy hold role (data/rollback reserve) before final shutdown.
- Keep rollback window and evidence archive.

Exit criteria:
- Legacy mint-os runtime reduced to archival/read-only or retired state by approved runbook.

### Phase F: Legacy data hold (90-day policy)

Scope:
- Set docker-host role to `legacy-data-hold` now.
- Freeze feature changes on VM 200 (security + uptime only).
- Retain legacy DB/object data for 90 days from hold start date.

Hold controls:
- Keep minimum required services for data access and rollback proof.
- Block new business logic development on legacy runtime.
- Record hold start date and planned retirement date in runbook.
- Hold start date: 2026-02-22.
- Planned hold end date: 2026-05-23.

Exit criteria:
- 90-day hold window elapsed.
- Historical data export/backup validated.
- Legacy runtime retired per decommission checklist.

## 7) Working Mode (Single Writer + Translator)

| Role | Mode |
|---|---|
| You | Decision owner and operator |
| Me | Technical translator and single roadmap writer |
| Other terminals | Read-only evidence gathering unless explicitly requested |

Execution pattern:
1. Run one read-only audit terminal to gather VM/route/runtime truth.
2. Apply decisions in this roadmap document only.
3. Convert roadmap items into execution loops only when you explicitly call for build/deploy work.

Default track order when you start implementation:
`inventory truth -> route normalization -> auth/payment extraction -> portal replacement`.

## 8) Backlog Candidates (Execution-Ready, Ordered)

| Priority | Work item | Lane owner |
|---|---|---|
| P0 | Fix mint-apps stack registry parity (`docker.compose.targets.yaml`) so status surfaces include pricing/shipping/suppliers projects | `SPINE-CONTROL-01` |
| P0 | Fix docker-host stack alias/double-count drift for `mint-modules-prod` in compose target bindings | `SPINE-CONTROL-01` |
| P0 | Provision missing finance adapter key (`GAP-OP-802`) | `SPINE-CONTROL-01` |
| P0 | Resend live cutover + quote email automation completion | `SPINE-CONTROL-01` + `DEPLOY-MINT-01` |
| P1 | Cut over pricing route from legacy estimator to mint-apps pricing (`:3700`) | `MINT-CODE-01` + `DEPLOY-MINT-01` |
| P1 | Cut over shipping route from legacy dashboard API to mint-apps shipping (`:3900`) | `MINT-CODE-01` + `DEPLOY-MINT-01` |
| P1 | Publish/verify suppliers route on mint-apps suppliers (`:3800`) | `MINT-CODE-01` + `DEPLOY-MINT-01` |
| P1 | Migrate active n8n workflow dependencies off legacy endpoints | `MINT-CODE-01` + `DEPLOY-MINT-01` |
| P1 | Port JWT auth model from legacy into fresh-slate protected APIs | `MINT-CODE-01` + `SPINE-CONTROL-01` |
| P1 | Full Stripe/payment extraction plan and implementation sequencing | `SPINE-CONTROL-01` + `MINT-CODE-01` |
| P2 | Design order/payment extraction contract from monolith | `SPINE-CONTROL-01` + `MINT-CODE-01` |
| P2 | Portal replacement sequence definition (API-first) | `SPINE-CONTROL-01` |
| P2 | Write and approve 90-day legacy data hold + decommission runbook for VM 200 | `SPINE-CONTROL-01` + `SPINE-AUDIT-01` |

## 9) Baseline Verify Notes

- `verify.route.recommend` recommended `core-operator`.
- `verify.pack.run core-operator` passed (8/8).
- `verify.core.run` returned a transient D148 failure earlier in the session and should be monitored during next loop start.

## 10) Legacy Delta Intake (2026-02-22)

Source:
- `/Users/ronnyworks/code/agentic-spine/docs/planning/LEGACY_DELTA_AUDIT_20260222.md`

Intake summary:
- `25` roadmap additions identified (`LEG-001` through `LEG-025`).
- Estimated migration completion: `~15-25%`.
- Fully replaced area: artwork lane.
- Partially replaced areas: shipping backend, pricing backend, finance adapter.
- Still legacy-critical: auth, payments, order lifecycle, customer management, production portal, n8n workflow dependency, and large table ownership footprint.

### 10.1 Critical Intake Adds (Now tracked)

| Group | Item IDs | Priority | Why this is blocking |
|---|---|---|---|
| Auth and access boundary | `LEG-001` | P0 | No replacement for JWT/admin/PIN auth means no secure fresh-slate user/worker access model |
| Payment lifecycle | `LEG-002`, `LEG-003` | P0 | No Stripe webhook + payment lifecycle replacement means revenue and reconciliation remain legacy-bound |
| Order backbone | `LEG-004` | P0 | `order-intake` is pre-order only; full lifecycle still legacy |
| Notifications wiring | `LEG-006`, `LEG-012` | P0/P1 | Communications surfaces exist, but transactional event wiring/retry/orchestration is incomplete |
| Table ownership + migration | `LEG-016`, `LEG-024` | P1 | Module extraction stalls without canonical ownership and data migration strategy |
| Supplier runtime completion | `LEG-019` | P1 | Suppliers extraction not complete until sync runtime and scheduler are truly fresh-slate |
| Legacy infra/routing dependencies | `LEG-013`, `LEG-014`, `LEG-015` | P0/P1 | External routing, orchestration, and startup/secrets still depend on legacy patterns |

### 10.2 Added Loop Candidates (from audit, adopted)

1. `LOOP-LEG-AUTH-PAYMENT-EXTRACTION-CONTRACT` (P0)
Scope:
- Lock fresh-slate auth contract (JWT + admin + worker/PIN replacement policy).
- Lock full Stripe/payment contract (checkout, webhook, refunds, idempotency).
- Decide module boundaries and acceptance gates before implementation.

2. `LOOP-LEG-NOTIFICATION-WIRING` (P0/P1)
Scope:
- Map all transactional events to communication delivery paths.
- Close wiring gap between mint transactional events and communications execution.
- Define retry/idempotency and delivery evidence requirements.

3. `LOOP-LEG-LEGACY-TABLE-OWNERSHIP-AUDIT` (P1)
Scope:
- Produce canonical table ownership map across legacy and mint surfaces.
- Define write authority, transition strategy, and migration DAG.
- Unblock schema gates for module extraction loops.

### 10.3 Contradictions And Unknowns (Tracked From Audit)

Open contradictions to resolve:
- Pricing scope parity between legacy `job-estimator` and fresh-slate pricing service.
- Suppliers dual-runtime ambiguity (legacy Python sync vs module-native runtime).
- Notification capability gap (communications surfaces vs legacy transactional coordination).
- Shipping backend replacement vs missing shipping operator UI replacement.

Open unknowns flagged for verification:
- `U-1` through `U-10` from the legacy delta audit are accepted as active discovery tasks for Phase A truth normalization.

## 11) Multi-Terminal Alignment Wave (Read-Only)

Goal:
- Align documentation, VM/runtime truth, agent surfaces, and legacy deltas into one coherent operating picture.
- No build/deploy work in this wave.

Operating rules:
- Read-only only: no commits, no proposal submit/apply, no secrets mutation, no route cutover.
- Each terminal produces one artifact with evidence paths and run keys.
- Single writer (roadmap terminal) merges all findings into this roadmap.

### Lane assignments

| Lane | Focus | Primary output |
|---|---|---|
| Terminal A | VM/runtime/routing truth | VM + route matrix with drift list |
| Terminal B | Auth/payment legacy contract extraction | Auth/payment boundary inventory |
| Terminal C | Notifications + workflow wiring | Event-to-delivery map and gaps |
| Terminal D | Legacy table ownership and migration dependency | Ownership map + migration DAG draft |
| Terminal E | Agent/MCP/capability alignment | Agent-tool-to-runtime parity map |

### Required artifact paths

- `/Users/ronnyworks/code/agentic-spine/docs/planning/alignment/TERMINAL-A_VM_ROUTE_TRUTH_20260222.md`
- `/Users/ronnyworks/code/agentic-spine/docs/planning/alignment/TERMINAL-B_AUTH_PAYMENT_DELTA_20260222.md`
- `/Users/ronnyworks/code/agentic-spine/docs/planning/alignment/TERMINAL-C_NOTIFICATIONS_WIRING_20260222.md`
- `/Users/ronnyworks/code/agentic-spine/docs/planning/alignment/TERMINAL-D_TABLE_OWNERSHIP_20260222.md`
- `/Users/ronnyworks/code/agentic-spine/docs/planning/alignment/TERMINAL-E_AGENT_PARITY_20260222.md`
