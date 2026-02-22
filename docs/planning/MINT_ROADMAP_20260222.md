**NO MINT OS LEGACY DEPENDENCY, EVERYTHING SHOULD BE NEW/FRESH**  
**AGENT FIRST**

# MINT Roadmap - 2026-02-22 (Control Writer)

Session objective: documentation + alignment only.  
Mutation policy for this artifact: no production mutations.

Last Consolidated: `2026-02-22T05:57:00Z`
Latest Tick Run Key: `CAP-20260221-230254__spine.control.tick__Rxuy87260`
Latest Plan Run Key: `CAP-20260221-230254__spine.control.plan__Rjf9j7261`
Latest Route Cutover Run Key: `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082`
Latest Route Verify Run Key: `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082`
Latest Stability Run Key: `CAP-20260221-232156__stability.control.snapshot__R8sk420819`
Latest Core Verify Run Key: `CAP-20260221-232336__verify.core.run__Rkqa054468`
Latest Pack Verify Run Key: `CAP-20260221-232512__verify.pack.run__Ryc5d87703`

## Current State (Fresh vs Legacy)

### Fresh runtime (active and healthy)

- Mint fresh-slate app/data runtime is live on VM 212 (`mint-data`) and VM 213 (`mint-apps`).
- App/data coverage now observed as `7/7` running app/data containers.
- Public routing coverage is now `2/14` to fresh-slate targets in the authoritative runtime audit.
- MCP surface is fresh-endpoint aligned, but governance parity is incomplete (health/verify blind spots remain).

| Surface | Runtime | State | Evidence |
| --- | --- | --- | --- |
| Data plane | `mint-data` VM 212 (`mint-data` stack, 3 containers) | Healthy | `CAP-20260221-225755__mint.deploy.status__R17dk18983`, `CAP-20260221-225857__docker.compose.status__R1ti123307` |
| App plane | `mint-apps` VM 213 (`mint-apps`, `pricing`, `suppliers`, `shipping`) | Healthy | `CAP-20260221-225755__mint.deploy.status__R17dk18983`, `CAP-20260221-225857__docker.compose.status__Rv49p23305`, `CAP-20260221-225755__mint.modules.health__R7kx518984` |
| Route inventory | Cloudflare ingress includes mint hostnames | `2/14` cut over; pricing/shipping fixed | `CAP-20260221-231839__cloudflare.tunnel.ingress.status__R5fzy83317` |

### Legacy runtime (still authoritative for critical paths)

- VM 200 (`docker-host`) remains active with `mint-os`, `mint-modules-prod`, and `dashy`.
- Several business-critical surfaces are still legacy-only: auth, order domain backbone, payments, admin/customer/production portals.
- Legacy and fresh runtime coexist for duplicate services (`files-api`, `quote-page`, `order-intake`, `minio`), pending route cutover and data validation.

| Legacy host | Legacy stacks | State | Evidence |
| --- | --- | --- | --- |
| VM 200 (`docker-host`) | `mint-os`, `mint-modules-prod`, `dashy` | Active (`13` containers running) | `CAP-20260221-225857__docker.compose.status__Rbelc23304`, `HO-20260222-040005` |

## Gaps/Blockers

### System-level blockers (P0)

1. Provider readiness gap: Resend and Twilio env not live-ready for customer notification paths (`CAP-20260221-233033__communications.provider.status__Rjsxt24559`).
2. Notification routing gap: event router pickup/shipped legs are confirmed as no-op (`P08`, `P10`) via workflow graph; v2 jobs webhook emission remains unproven in this pass (`CAP-20260221-235253__n8n.workflows.get__Rz1vx40987`).
3. Auth gap: fresh-slate replacement for legacy JWT/PIN/admin session paths is **UNVERIFIED** in current RAG evidence (`CAP-20260221-235253__rag.anythingllm.ask__R7uto40985`).
4. Payment gap: fresh-slate Stripe checkout/webhook/payment-table replacement is **UNVERIFIED** in current RAG evidence (`CAP-20260221-235253__rag.anythingllm.ask__Ree5f40986`).
5. Finance blocker: `GAP-OP-802` remains open and unlinked, blocking finance-adapter reconciliation path.
6. Governance parity gap: D148 is resolved (`PASS`) in core verify; remaining parity risk is false-positive vertical parity + health-cap blind spots (`CAP-20260221-232336__verify.core.run__Rkqa054468`).

### Registered gap deltas from worker handoffs

- Notifications and communications delta: `LEG-001` through `LEG-015` (plus provider-env unmapped blocker set).
- Table ownership and extraction delta: auth/payment/order and migration strategy gaps (`LEG-001`, `LEG-002`, `LEG-003`, `LEG-004`, `LEG-016`).
- Agent/MCP parity delta: governance surfaces behind fresh runtime reality (AC-E series).
- Runtime placement/routing delta: fresh runtime healthy, `2/14` public routes now fresh-routed (pricing + shipping).

Evidence anchors:

- `CAP-20260221-233137__gaps.status__Rg0ae25574`
- `CAP-20260221-233456__loops.progress__Rx70s31459` (run with `./bin/ops cap run loops.progress --loop <LOOP_ID>`)
- `CAP-20260221-232336__verify.core.run__Rkqa054468`
- `CAP-20260221-232512__verify.pack.run__Ryc5d87703`
- `CAP-20260221-225020__mcp.runtime.status__Re7px66523` (worker handoff evidence)
- `CAP-20260221-225022__verify.pack.run__Rlukn67107` (worker handoff evidence)
- `CAP-20260221-225241__verify.vertical_integration.parity_status__Rlumr4519` (worker handoff evidence)

## Route Cutovers

Current authoritative route state: **2/14 mint public routes are cut over to fresh-slate targets**.

Route Scope Definition: `14` is the total mint-public route denominator (customer/business mint hostnames only). Runtime state is currently `2/14` cut over. Any `0/14` mention refers to baseline scope framing, not current runtime state. This excludes non-mint `ronny.works` routes and external `mintprints-v3.ronny.works`.

### Cutover-ready now (fresh target exists, legacy route still active)

| Route | Current target | Target cutover | Status |
| --- | --- | --- | --- |
| `pricing.mintprints.co` | `http://100.79.183.14:3700` | `http://100.79.183.14:3700` | **Done** (cut over 2026-02-22) |
| `shipping.mintprints.co` | `http://100.79.183.14:3900` | `http://100.79.183.14:3900` | **Done** (cut over 2026-02-22) |
| `files.mintprints.co` | `http://mint-os-minio:9000` | `http://100.106.72.25:9000` | Not cut over |
| `minio.mintprints.co` | `http://mint-os-minio:9001` | `http://100.106.72.25:9001` | Not cut over |

### Ambiguous route bindings (must disambiguate before retirement)

| Route | Current target | Required action |
| --- | --- | --- |
| `customer.mintprints.co` | `http://quote-page:3341` | Resolve alias to explicit VM 213 target |
| `mintprints-app.ronny.works` | `http://quote-page:3341` | Resolve alias to explicit VM 213 target |

### Legacy-only routes (no replacement yet)

- `admin.mintprints.co`
- `api.mintprints.co`
- `estimator.mintprints.co`
- `kanban.mintprints.co`
- `kanban.ronny.works`
- `mintprints-api.ronny.works`
- `production.mintprints.co`
- `production.ronny.works`
- `stock-dst.mintprints.co`

### Retirement candidates after cutover + validation

- `files-api` (VM 200 -> VM 213 equivalent live)
- `quote-page` (VM 200 -> VM 213 equivalent live)
- `order-intake` (VM 200 -> VM 213 equivalent live)
- `minio` (VM 200 -> VM 212 equivalent live; requires bucket parity validation)

Evidence anchors:

- `CAP-20260221-225833__cloudflare.tunnel.ingress.status__R5ozz21558`
- `HO-20260222-040005`

## 90-Day Legacy Hold Plan

Declared hold window: **2026-02-22 through 2026-05-23**.  
Current interpretation: hold intent is declared, but enforcement gate is not yet met.

| Prerequisite | Status | Blocking | Evidence |
| --- | --- | --- | --- |
| Legacy DB backup + restore test | Not verified | Yes | `HO-20260222-040005` |
| MinIO bucket parity/snapshot validation | Not verified | Yes | `HO-20260222-040005` |
| Feature freeze enforcement on VM 200 | Declared, no gate | Soft | `HO-20260222-040005` |
| 7-day health proof for fresh runtime | Partial | Partial | `CAP-20260221-225755__mint.deploy.status__R17dk18983`, `HO-20260222-040005` |
| 4 replaceable routes cut over | 2/4 done (pricing+shipping) | Partial | `CAP-20260221-231839__cloudflare.tunnel.ingress.status__R5fzy83317` |
| Hold runbook artifact approved | Missing | Yes | `HO-20260222-040005` |
| `GAP-OP-802` closed | Open | Yes | `CAP-20260221-225755__gaps.status__R7rrh18982` |

## Loop Backlog (P0/P1/P2)

### P0

- ~~Correct misrouted critical endpoints: repoint `pricing.mintprints.co` and `shipping.mintprints.co` to VM 213 targets.~~ **DONE** (2026-02-22, CF config v88)
- Close `GAP-OP-802` and validate finance-adapter reconciliation path.
- Provider/env readiness: Resend + Twilio + n8n env injection (notifications currently blocked).
- Notification trigger wiring blockers: replace event-router no-op stubs + add v2 status webhook emission.
- Auth/payment/order boundaries: start extraction loop for `LEG-001`/`LEG-002`/`LEG-003`/`LEG-004` (no partial cutover possible until auth + payments exist).
- Keep D148 passing while closing remaining parity blind spots (vertical false-pass + health-cap coverage), evidence: `CAP-20260221-232336__verify.core.run__Rkqa054468`.

### P1

- Route cutover for remaining replaceable services (`files.mintprints.co`, `minio.mintprints.co`) and alias disambiguation (`customer.mintprints.co`, `mintprints-app.ronny.works`).
- Author and approve `docs/planning/LEGACY_HOLD_RUNBOOK_VM200.md`.
- Define and execute supplier/pricing/shipping ownership transfer contracts and acceptance checks (`AC-SUPP-001`, `AC-PRICE-001`, `AC-SHIP-001`).
- Converge send path contract (n8n vs spine communications vs legacy direct libs) and retire dead path.
- Retire duplicate VM 200 containers after route cutover and rollback window.

### P2

- Production/timekeeping/communications table extraction (`LEG-009`, `LEG-010`, `LEG-011`).
- AI/deprecated table decisions and cleanup plan.
- Non-mint degraded runtime follow-ups (download-stack exits, jellyfin timeout) tracked as non-blocking to mint cutover.

## Canonical Status Table

Source of truth: this table is canonical for item state, ownership, evidence, and next action.

| item_id | owner | status | evidence_run_key | next_action |
| --- | --- | --- | --- | --- |
| `STATE-FRESH-BASELINE` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-232156__stability.control.snapshot__R8sk420819` | Keep daily health snapshots and compare to route state |
| `STATE-LEGACY-VM200` | `SPINE-AUDIT-01` | `open` | `CAP-20260221-225857__docker.compose.status__Rbelc23304` | Keep VM 200 active until replacement routes and boundaries are complete |
| `ROUTE-ZERO-CUTOVER` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082` | First 2 routes (pricing/shipping) cut over 2026-02-22 |
| `ROUTE-CUTOVER-4` | `SPINE-CONTROL-01` | `open` | `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082` | 2/4 done (pricing+shipping verified); files/minio remain |
| `ROUTE-PRICING-MISROUTE` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082` | Verified: `http://100.79.183.14:3700` — HTTP 200, service=pricing |
| `ROUTE-SHIPPING-MISROUTE` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-233000__cloudflare.tunnel.ingress.status__Rlx4x23082` | Verified: `http://100.79.183.14:3900` — HTTP 200, service=shipping |
| `ROUTE-ALIAS-DISAMBIG` | `SPINE-CONTROL-01` | `open` | `HO-20260222-040005` | Replace alias routing for `quote-page` with explicit target host |
| `BLOCKER-GAP-802` | `SPINE-CONTROL-01` | `blocked` | `CAP-20260221-233137__gaps.status__Rg0ae25574` | Provision finance adapter key and close gap with receipt |
| `DRIFT-MINT-DEPLOY-STATUS` | `TERMINAL-C` | `open` | `CAP-20260221-224435__mint.deploy.status__Rfmkx77795` | Update deploy status capability to include sub-project stacks |
| `BINDING-DOCKER-PARITY` | `TERMINAL-C` | `done` | `CAP-20260221-232512__verify.pack.run__Ryc5d87703` | Keep docker target binding parity under verify pack guard |
| `NOTIF-PROVIDERS-READY` | `SPINE-AUDIT-01` | `blocked` | `CAP-20260221-225007__communications.provider.status__R8p9464929` | Inject Resend/Twilio vars into runtime and validate `live_ready: yes` |
| `NOTIF-WORKFLOW-ACTIVATION` | `SPINE-AUDIT-01` | `open` | `CAP-20260221-225010__n8n.workflows.list__Rc5zz65490` | Activate payment-needed/ready-for-pickup/shipped email workflows |
| `NOTIF-EVENT-ROUTER-WIRING` | `SPINE-AUDIT-01` | `open` | `CAP-20260221-235253__n8n.workflows.get__Rz1vx40987` | P08/P10 are no-op nodes; replace with active webhook routes |
| `NOTIF-V2-WEBHOOK-EMIT` | `SPINE-AUDIT-01` | `open` | `CAP-20260221-235253__n8n.workflows.get__Rz1vx40987` | Event router verified; emission source from `/api/v2/jobs/:id/status` remains UNVERIFIED |
| `DOMAIN-AUTH-EXTRACTION` | `SPINE-AUDIT-01` | `blocked` | `CAP-20260221-235253__rag.anythingllm.ask__R7uto40985` | UNVERIFIED: no direct evidence of fresh-slate JWT/PIN/admin replacement found in current RAG result |
| `DOMAIN-PAYMENT-EXTRACTION` | `SPINE-AUDIT-01` | `blocked` | `CAP-20260221-235253__rag.anythingllm.ask__Ree5f40986` | UNVERIFIED: no direct evidence of fresh-slate Stripe checkout/webhook/payment-table replacement found in current RAG result |
| `DOMAIN-ORDER-BOUNDARY` | `SPINE-AUDIT-01` | `open` | `HO-20260222-035942` | Define order boundary and FK migration sequencing plan |
| `PARITY-D148` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-232336__verify.core.run__Rkqa054468` | D148 now passing (8/8 core gates green) |
| `PARITY-MODULE-HEALTH-COVERAGE` | `TERMINAL-E_AGENT_PARITY` | `open` | `CAP-20260221-225226__mint.modules.health__Rm4pp94982` | Expand health probes to all app-plane modules |
| `PARITY-VERTICAL-FALSE-PASS` | `TERMINAL-E_AGENT_PARITY` | `open` | `CAP-20260221-225241__verify.vertical_integration.parity_status__Rlumr4519` | Retarget parity admission contract to VM 213 services |
| `HOLD-RUNBOOK` | `SPINE-CONTROL-01` | `open` | `HO-20260222-040005` | Write hold runbook artifact and sign-off gates |
| `HOLD-DATA-PREREQS` | `SPINE-CONTROL-01` | `blocked` | `HO-20260222-040005` | Validate DB restore and MinIO bucket parity before enforceable hold |
| `CONTROL-CYCLE-LATEST` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-230254__spine.control.tick__Rxuy87260` | Follow recommended next actions from latest control plan |
| `CONTROL-PLAN-LATEST` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-230254__spine.control.plan__Rjf9j7261` | Execute P0 queue in controlled documentation-first order |
