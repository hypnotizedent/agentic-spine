**NO MINT OS LEGACY DEPENDENCY, EVERYTHING SHOULD BE NEW/FRESH**
**AGENT FIRST**

# MINT Roadmap - 2026-02-22 (Control Writer)

Session objective: documentation + alignment only.
Mutation policy for this artifact: no production mutations.

Last Consolidated: `2026-02-22T06:20:00Z`
Latest Tick Run Key: `CAP-20260221-230254__spine.control.tick__Rxuy87260`
Latest Plan Run Key: `CAP-20260221-230254__spine.control.plan__Rjf9j7261`
Latest Route Cutover Run Key: `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987`
Latest Route Verify Run Key: `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987`
Latest Stability Run Key: `CAP-20260222-010907__stability.control.snapshot__Rlohn4003`
Latest Core Verify Run Key: `CAP-20260222-011540__verify.pack.run__Ro21l28962`
Latest Pack Verify Run Key: `CAP-20260222-011540__verify.pack.run__Ro21l28962`
Latest Communications Run Key: `CAP-20260222-011529__communications.provider.status__Rt1st26962`
Latest Send Proof Run Key: `CAP-20260222-011521__communications.send.execute__R9gbg26034`

## Current State (Fresh vs Legacy)

### Fresh runtime (active and healthy)

- Mint fresh-slate app/data runtime is live on VM 212 (`mint-data`) and VM 213 (`mint-apps`).
- App/data coverage now observed as `7/7` running app/data containers.
- Public routing coverage is now `2/14` to fresh-slate targets in the authoritative runtime audit.
- MCP surface is fresh-endpoint aligned, but governance parity is incomplete (health/verify blind spots remain).
- **Finance adapter** reconciliation path is unblocked: `FINANCE_ADAPTER_API_KEY` provisioned, auth path proven (GAP-OP-802 closed).
- **Notifications phase1** is live: Resend `live_ready=yes`, email send path proven (Resend message ID `45cad36b`), 3 email workflows activated.

| Surface | Runtime | State | Evidence |
| --- | --- | --- | --- |
| Data plane | `mint-data` VM 212 (`mint-data` stack, 3 containers) | Healthy | `CAP-20260221-225755__mint.deploy.status__R17dk18983` |
| App plane | `mint-apps` VM 213 (`mint-apps`, `pricing`, `suppliers`, `shipping`) | Healthy | `CAP-20260222-010043__mint.modules.health__Rptt831985` |
| Route inventory | Cloudflare ingress includes mint hostnames | `2/14` cut over; pricing/shipping done | `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987` |
| Finance adapter | VM 213 `:3600` | Healthy, auth path proven | `CAP-20260222-005914__gaps.close__R4kn928977` |
| Notifications (email) | Resend + n8n workflows | Phase1 live (Resend live, Twilio sim) | `CAP-20260222-011529__communications.provider.status__Rt1st26962` |

### Legacy runtime (still authoritative for critical paths)

- VM 200 (`docker-host`) remains active with `mint-os`, `mint-modules-prod`, and `dashy`.
- Several business-critical surfaces are still legacy-only: auth, order domain backbone, payments, admin/customer/production portals.
- Legacy and fresh runtime coexist for duplicate services (`files-api`, `quote-page`, `order-intake`, `minio`), pending route cutover and data validation.

| Legacy host | Legacy stacks | State | Evidence |
| --- | --- | --- | --- |
| VM 200 (`docker-host`) | `mint-os`, `mint-modules-prod`, `dashy` | Active (`13` containers running) | `CAP-20260221-225857__docker.compose.status__Rbelc23304`, `HO-20260222-040005` |

### Module Extraction & Cutover Summary (Canonical)

Verified: 2026-02-22

- **Pricing**: done (module + runtime + route cutover).
- **Shipping**: done for module/runtime; route is configured to fresh target, but do one final external API-path verify before calling it fully closed.
- **Suppliers**: done for module/runtime/extraction (61b186c), but public route cutover is still unverified (not present in active tunnel ingress snapshot).
- **Suppliers + Shipping + Pricing extraction**: DONE.
- **Full cutover/retirement program**: NOT DONE yet (suppliers public route verification + legacy duplicate retirement + payment lane).

### Wave 13 payment closeout (2026-02-22)

- `WAVE-20260222-13` is closed (D3 audit acknowledged, collect/preflight/verify lanes green).
- Payment runtime on VM 213 is **not live**. `payment-v2` health probe returns `REFUSED`, `docker.compose.status mint-apps` reports `payment` as `down` with `reason=dir_missing`, and host precheck returned `ENV_MISSING` for `/opt/stacks/mint-apps/payment/.env`.
- Safe deploy policy enforced: no deployment performed without real host env/secrets; no synthetic secrets created.
- Pricing/suppliers/shipping status remains unchanged and healthy in this session.

Evidence:

- Tunnel ingress: `CAP-20260222-032121__cloudflare.tunnel.ingress.status__Rgt9u97088`
- Module health: `CAP-20260222-032127__services.health.status__Rop1j98580`
- Docker mint-apps: `CAP-20260222-032237__docker.compose.status__Rzcb44265`
- Docker docker-host: `CAP-20260222-032156__docker.compose.status__Rqezk99563`
- Suppliers extraction commit: `61b186c`
- Payment/visibility check: `CAP-20260222-033943__services.health.status__Rjg7c35707`
- Payment compose status: `CAP-20260222-033959__docker.compose.status__R96zl36866`
- Mint deploy status: `CAP-20260222-034009__mint.deploy.status__Rxyey37769`
- Mint modules health: `CAP-20260222-034010__mint.modules.health__Rk6vv38064`
- Core verify: `CAP-20260222-034012__verify.core.run__R5g5g38332`
- Pack verify: `CAP-20260222-034101__verify.pack.run__Rh48o35706`

## Gaps/Blockers

### System-level blockers (P0)

1. ~~Finance blocker: `GAP-OP-802` remains open and unlinked, blocking finance-adapter reconciliation path.~~ **CLOSED** (Wave3, `CAP-20260222-005914__gaps.close__R4kn928977`)
2. ~~Provider readiness gap: Resend and Twilio env not live-ready for customer notification paths.~~ **RESOLVED** (Wave4: Resend `live_ready=yes`, Twilio env provisioned but simulation-only per phase1 cutover)
3. ~~Notification workflow gap: email notification workflows inactive.~~ **RESOLVED** (Wave4: 3 workflows activated — Ready for Pickup, Payment Needed, Shipped)
4. **Auth gap**: fresh-slate replacement for legacy JWT/PIN/admin session paths is **UNVERIFIED** in current RAG evidence (`CAP-20260221-235253__rag.anythingllm.ask__R7uto40985`).
5. **Payment runtime blocker**: VM 213 payment stack is not live. Host precondition `/opt/stacks/mint-apps/payment/.env` is missing and compose status reports `payment` stack `down` (`reason=dir_missing`) (`CAP-20260222-033959__docker.compose.status__R96zl36866`).
6. ~~**Notification event emission gap**: event router pickup/shipped legs are confirmed as no-op (`P08`, `P10`) via workflow graph; v2 jobs webhook emission remains unproven.~~ **RESOLVED** (Wave6: P08/P10 no-op stubs replaced with live HTTP emission nodes, If node v2 caseSensitive fix applied to all 3 workflows, FROM domain corrected to verified `mintprints.co`, E2E test events routed without errors; `CAP-20260222-020121__n8n.workflows.list__Ryxpx6091`)
7. Governance parity gap: D148 is resolved (`PASS`) in core verify; remaining parity risk is false-positive vertical parity + health-cap blind spots (`CAP-20260222-011540__verify.pack.run__Ro21l28962`).

### Registered gap deltas from worker handoffs

- Notifications and communications delta: `LEG-001` through `LEG-015` (provider env now resolved; event emission wiring remains).
- Table ownership and extraction delta: auth/payment/order and migration strategy gaps (`LEG-001`, `LEG-002`, `LEG-003`, `LEG-004`, `LEG-016`).
- Agent/MCP parity delta: governance surfaces behind fresh runtime reality (AC-E series).
- Runtime placement/routing delta: fresh runtime healthy, `2/14` public routes now fresh-routed (pricing + shipping).

Evidence anchors:

- `CAP-20260221-233137__gaps.status__Rg0ae25574`
- `CAP-20260222-011540__verify.pack.run__Ro21l28962`
- `CAP-20260222-011529__communications.provider.status__Rt1st26962`
- `CAP-20260222-011521__communications.send.execute__R9gbg26034`
- `CAP-20260222-005914__gaps.close__R4kn928977`

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

- `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987`
- `HO-20260222-040005`

## 90-Day Legacy Hold Plan

Declared hold window: **2026-02-22 through 2026-05-23**.
Current interpretation: hold intent is declared, but enforcement gate is not yet met.

| Prerequisite | Status | Blocking | Evidence |
| --- | --- | --- | --- |
| Legacy DB backup + restore test | Not verified | Yes | `HO-20260222-040005` |
| MinIO bucket parity/snapshot validation | Not verified | Yes | `HO-20260222-040005` |
| Feature freeze enforcement on VM 200 | Declared, no gate | Soft | `HO-20260222-040005` |
| 7-day health proof for fresh runtime | Partial | Partial | `CAP-20260222-010907__stability.control.snapshot__Rlohn4003` |
| 4 replaceable routes cut over | 2/4 done (pricing+shipping) | Partial | `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987` |
| Hold runbook artifact approved | Missing | Yes | `HO-20260222-040005` |
| `GAP-OP-802` closed | **Done** | No | `CAP-20260222-005914__gaps.close__R4kn928977` |

## Loop Backlog (P0/P1/P2)

### P0

- ~~Correct misrouted critical endpoints: repoint `pricing.mintprints.co` and `shipping.mintprints.co` to VM 213 targets.~~ **DONE** (2026-02-22, CF config v88)
- ~~Close `GAP-OP-802` and validate finance-adapter reconciliation path.~~ **DONE** (Wave3, key provisioned, auth path proven)
- ~~Provider/env readiness: Resend + Twilio + n8n env injection (notifications currently blocked).~~ **DONE** (Wave4, Resend live_ready=yes, Twilio env provisioned, 3 email workflows activated)
- ~~Notification trigger wiring blockers: replace event-router no-op stubs + add v2 status webhook emission.~~ **DONE** (Wave6, Event Router P08/P10 wired to live Resend-backed notification workflows)
- Auth/payment/order boundaries: start extraction loop for `LEG-001`/`LEG-002`/`LEG-003`/`LEG-004` (no partial cutover possible until auth + payments exist).
- Keep D148 passing while closing remaining parity blind spots (vertical false-pass + health-cap coverage), evidence: `CAP-20260222-011540__verify.pack.run__Ro21l28962`.

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
| `STATE-FRESH-BASELINE` | `SPINE-CONTROL-01` | `done` | `CAP-20260222-010907__stability.control.snapshot__Rlohn4003` | Keep daily health snapshots and compare to route state |
| `STATE-LEGACY-VM200` | `SPINE-AUDIT-01` | `open` | `CAP-20260221-225857__docker.compose.status__Rbelc23304` | Keep VM 200 active until replacement routes and boundaries are complete |
| `ROUTE-ZERO-CUTOVER` | `SPINE-CONTROL-01` | `done` | `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987` | First 2 routes (pricing/shipping) cut over 2026-02-22 |
| `ROUTE-CUTOVER-4` | `SPINE-CONTROL-01` | `open` | `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987` | 2/4 done (pricing+shipping verified); files/minio remain |
| `ROUTE-PRICING-MISROUTE` | `SPINE-CONTROL-01` | `done` | `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987` | Verified: `http://100.79.183.14:3700` — HTTP 200, service=pricing |
| `ROUTE-SHIPPING-MISROUTE` | `SPINE-CONTROL-01` | `done` | `CAP-20260222-011942__cloudflare.tunnel.ingress.status__Rngm790987` | Verified: `http://100.79.183.14:3900` — HTTP 200, service=shipping |
| `ROUTE-ALIAS-DISAMBIG` | `SPINE-CONTROL-01` | `open` | `HO-20260222-040005` | Replace alias routing for `quote-page` with explicit target host |
| `BLOCKER-GAP-802` | `SPINE-CONTROL-01` | **done** | `CAP-20260222-005914__gaps.close__R4kn928977` | Closed: FINANCE_ADAPTER_API_KEY provisioned, auth path verified |
| `DRIFT-MINT-DEPLOY-STATUS` | `TERMINAL-C` | `open` | `CAP-20260221-224435__mint.deploy.status__Rfmkx77795` | Update deploy status capability to include sub-project stacks |
| `BINDING-DOCKER-PARITY` | `TERMINAL-C` | `done` | `CAP-20260222-011540__verify.pack.run__Ro21l28962` | Keep docker target binding parity under verify pack guard |
| `NOTIF-PROVIDERS-READY` | `SPINE-AUDIT-01` | **done** | `CAP-20260222-011529__communications.provider.status__Rt1st26962` | Resend live_ready=yes, Twilio env provisioned (sim-only per phase1) |
| `NOTIF-WORKFLOW-ACTIVATION` | `SPINE-AUDIT-01` | **done** | `CAP-20260222-010954__n8n.workflows.activate__Rk9p333575` | 3 email workflows activated (Pickup, Payment, Shipped) |
| `NOTIF-SEND-PATH-PROVEN` | `SPINE-AUDIT-01` | **done** | `CAP-20260222-011521__communications.send.execute__R9gbg26034` | Live Resend email delivered (message ID 45cad36b) |
| `NOTIF-EVENT-ROUTER-WIRING` | `SPINE-AUDIT-01` | **done** | `CAP-20260222-020121__n8n.workflows.list__Ryxpx6091` | P08→Emit Ready for Pickup (httpRequest to /webhook/mint-ready-pickup), P10→Emit Shipped (httpRequest to /webhook/mint-shipped), If v2 caseSensitive fix applied, FROM domain corrected to mintprints.co |
| `NOTIF-V2-WEBHOOK-EMIT` | `SPINE-AUDIT-01` | **done** | `CAP-20260222-020125__communications.provider.status__Rqm746836` | Event Router E2E: webhook→route→emit→notification workflow→Resend, no error executions, HTTP 200 on all test events |
| `DOMAIN-AUTH-EXTRACTION` | `SPINE-AUDIT-01` | `blocked` | `CAP-20260221-235253__rag.anythingllm.ask__R7uto40985` | UNVERIFIED: no direct evidence of fresh-slate JWT/PIN/admin replacement found in current RAG result |
| `DOMAIN-PAYMENT-EXTRACTION` | `SPINE-AUDIT-01` | `blocked` | `CAP-20260222-033959__docker.compose.status__R96zl36866` | Provision real `/opt/stacks/mint-apps/payment/.env`, sync module dir, then `docker compose up -d --build` and verify `http://100.79.183.14:4000/health` |
| `DOMAIN-ORDER-BOUNDARY` | `SPINE-AUDIT-01` | `open` | `HO-20260222-035942` | Define order boundary and FK migration sequencing plan |
| `PARITY-D148` | `SPINE-CONTROL-01` | `done` | `CAP-20260222-011540__verify.pack.run__Ro21l28962` | D148 now passing (8/8 core gates green) |
| `PARITY-MODULE-HEALTH-COVERAGE` | `TERMINAL-E_AGENT_PARITY` | `open` | `CAP-20260221-225226__mint.modules.health__Rm4pp94982` | Expand health probes to all app-plane modules |
| `PARITY-VERTICAL-FALSE-PASS` | `TERMINAL-E_AGENT_PARITY` | `open` | `CAP-20260221-225241__verify.vertical_integration.parity_status__Rlumr4519` | Retarget parity admission contract to VM 213 services |
| `HOLD-RUNBOOK` | `SPINE-CONTROL-01` | `open` | `HO-20260222-040005` | Write hold runbook artifact and sign-off gates |
| `HOLD-DATA-PREREQS` | `SPINE-CONTROL-01` | `blocked` | `HO-20260222-040005` | Validate DB restore and MinIO bucket parity before enforceable hold |
| `CONTROL-CYCLE-LATEST` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-230254__spine.control.tick__Rxuy87260` | Follow recommended next actions from latest control plan |
| `CONTROL-PLAN-LATEST` | `SPINE-CONTROL-01` | `done` | `CAP-20260221-230254__spine.control.plan__Rjf9j7261` | Execute P0 queue in controlled documentation-first order |

## Next 72h Execution Order

| Priority | Item | Owner | Done Criteria |
| --- | --- | --- | --- |
| 1 | **Auth extraction scope**: audit legacy JWT/PIN/session tables, define fresh-slate auth boundary contract, file extraction loop (`LEG-001`) | `@ronny` | Scope doc written with table list + migration sequencing; extraction loop opened |
| 2 | ~~**Event router wiring**: replace P08/P10 no-op stubs with active webhook routes, prove v2 jobs status emission triggers notification workflows end-to-end~~ **DONE** (Wave6) | `@ronny` | E2E: 2 status-change events routed through Event Router → notification workflows without errors (`CAP-20260222-020121__n8n.workflows.list__Ryxpx6091`) |
| 3 | **Route cutover files/minio**: cut `files.mintprints.co` and `minio.mintprints.co` to VM 212 targets, validate bucket parity, move to `4/14` routes fresh | `@ronny` | Ingress audit shows `4/14` fresh, MinIO console + files-api accessible via new routes |
