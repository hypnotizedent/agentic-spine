---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-order-lifecycle-contract-gate1
loop_id: LOOP-MINT-ORDER-LIFECYCLE-PHASE0-CONTRACT-20260222
---

# MINT Order Lifecycle Contract V1 (Gate 1)

Contract-only artifact. No runtime mutation.

Evidence:
- Legacy lifecycle surface: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/v2-jobs.cjs` (4347 lines)
- V1 scope lock: `/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/V1_SCOPE_AND_ROUTE_CANON.md:14-33`, DNB1 at `:67-78`
- Order-intake scope: `/Users/ronnyworks/code/mint-modules/order-intake/API.md:38-133`, `/Users/ronnyworks/code/mint-modules/order-intake/src/app.ts:61-63`

## 1) What order-intake already handles vs lifecycle gap

Order-intake today:
- Contract validation and intake envelope handling only (`/api/v1/intake`, `/api/v1/intake/validate`, `/api/v1/intake/schema`).
- No order CRUD, payment ledger, production tracking, or shipping lifecycle ownership.

Lifecycle gap today (legacy-owned in `v2-jobs`):
- Job/order CRUD, customer linking, line-item/imprint management.
- Payment posting + balance updates.
- Quote send/approve/reject flow.
- File/mockup/production asset linking.
- Notification and invoice dispatch side effects.

## 2) 4,347-line composition (active business logic vs dead code vs middleware)

Measured facts:
- Total lines: 4,347
- Blank lines: 503
- Comment-like lines: 445
- Endpoint markers in file comments: 42
- SQL query call sites: 143

Classification for this pass:
- Active business logic: **high** (majority of non-comment/non-blank lines; route handlers + SQL + state transitions).
- Middleware/helpers: **present** (`verifyToken`, `normalizeDecorationType`, response helpers, MinIO upload helpers).
- Dead code: **UNVERIFIED** (no reachability/runtime execution trace in this read-only pass).

## 3) State machine verification (Quote -> Order -> Production -> Shipped -> Closed)

Observed explicit transitions:
- Quote send: `QUOTE` + `Quote Out For Approval - Email` (`v2-jobs.cjs:2316-2323`)
- Quote approve: `PAYMENT NEEDED` + `Quote Approved` (`v2-jobs.cjs:2510-2517`)
- Payment completion: `PAID` (`stripe-webhooks.cjs:174-182`)
- General status mutation endpoint supports transitions to `in_production`, `ready`, `shipped`, `delivered`, `cancelled` map (`v2-jobs.cjs:1090-1101`)

State-machine verdict:
- `Quote -> Payment Needed -> Paid -> In Production -> Shipped` is evidenced.
- `Closed` is not explicitly represented as a dedicated terminal status in this file; terminal semantics are partially delegated to `printavo_statuses` via `statusHelper`.
- `Closed` therefore remains `UNVERIFIED` in current fresh-slate contract proof.

## 4) External calls from v2-jobs

Observed integration calls:
- Stripe checkout: `createCheckoutSession(...)` (`v2-jobs.cjs:2538-2547`)
- Event emission hook: `emitEvent('payment.received', ...)` (`v2-jobs.cjs:1593-1612`)
- n8n webhook: `fetch('https://n8n.ronny.works/webhook/mint/payment', ...)` (`v2-jobs.cjs:1614-1630`)
- Twilio SMS helpers: `sendOrderReadySMS`, `sendPaymentNeededSMS`, `sendShippedSMS`, `sendQuoteReadySMS` (`v2-jobs.cjs:4263-4266`)
- Resend invoice email send: `resend.emails.send(...)` (`v2-jobs.cjs:4313-4325`)
- MinIO object storage writes/listing via `minioClient.putObject` and `listObjectsV2` (`v2-jobs.cjs:2888`, `v2-jobs.cjs:3054`, `v2-jobs.cjs:3734`, `v2-jobs.cjs:3855`, `v2-jobs.cjs:3949`)
- Local filesystem temp-file reads/unlinks around upload flows (`v2-jobs.cjs:2887-2893`, `v2-jobs.cjs:3053-3059`)

## 5) Phasing plan

### Phase 1 (minimum lifecycle core)
- Order CRUD + customer linking + status transitions.
- Keep quote approval endpoints and deterministic status update contract.
- No new UI expansion.

### Phase 2 (financial and item depth)
- Line items, imprints, expenses, profit calculations.
- Payment mutation removed from lifecycle writer path once Rank 6 payment owner is established.

### Phase 3 (integrations and file surfaces)
- Stripe handoff via payment API boundary only.
- Notification/event bus integration (n8n + communications-agent).
- MinIO/mockup/production file reconciliation.

## Ownership conflict flags (from table audit)

Unresolved and operator-owned before Gate 2:
- `orders` write conflict (payment vs lifecycle)
- `payments` write conflict (payment vs lifecycle)
- `customers` write conflict (auth vs lifecycle)

## Gate 1 outcome

- Lifecycle boundary and phase plan are defined.
- Gate 2 blocked on table writer ownership lock and explicit terminal-state (`closed`) policy.
