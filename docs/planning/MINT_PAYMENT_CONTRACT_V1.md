---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-payment-contract-gate1
loop_id: LOOP-MINT-PAYMENT-PHASE0-CONTRACT-20260222
---

# MINT Payment Contract V1 (Gate 1)

Contract-only artifact. No runtime mutation.

Evidence:
- Stripe client and webhook verification: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/lib/stripe.cjs:4-135`
- Stripe webhook route: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/stripe-webhooks.cjs:56-221`
- Public order pay route: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/order-payments.cjs:37-170`
- Checkout creation route (50% deposit): `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/v2-checkout.cjs:87-308`
- Payment writes inside lifecycle route: `/Users/ronnyworks/ronny-ops/mint-os/apps/api/routes/v2-jobs.cjs:1510-1660`
- RAG check (replacement evidence): `CAP-20260222-001530__rag.anythingllm.ask__Rn90n87541` (retrieval-only, no direct replacement proof)

## 1) Webhook receiver: events and idempotency model

### Events currently handled
- `checkout.session.completed` (`stripe-webhooks.cjs:83-85`)
- `checkout.session.expired` (`stripe-webhooks.cjs:87-90`)
- Other event types are logged as unhandled (`stripe-webhooks.cjs:92-94`)

### Current idempotency model
- Idempotency is order-state based, not webhook-event ledger based:
  - Finds order by `id` or `stripe_session_id` (`stripe-webhooks.cjs:148-152`)
  - Skips if `deposit_paid` already true (`stripe-webhooks.cjs:163-168`)
- No dedicated webhook event table keyed by Stripe `event.id` exists in current legacy implementation.

Contract decision for replacement:
- Fresh-slate payment module must add explicit event-id idempotency (event ledger table) while preserving order-state guard.

## 2) Checkout model (deposit behavior)

Observed:
- `v2-checkout` always computes 50% deposit (`v2-checkout.cjs:246-248`) and stores `deposit_amount` (`v2-checkout.cjs:250-254`).
- `order-payments` supports flexible amount + payment type (`order-payments.cjs:89-113`).

Contract decision:
- Keep 50% as default for parity.
- Make deposit policy configurable at module level (`deposit_default_percent`, min/max bounds).
- Support `deposit`, `balance`, `partial`, `full` payment intents (already represented in `stripe.cjs:44-64`).

## 3) Payment-related tables and ownership

| table | current behavior | proposed owner |
|---|---|---|
| `payments` | inserted by webhook and `v2-jobs` (`stripe-webhooks.cjs:188`, `v2-jobs.cjs:1562`) | Payment module (Rank 6) |
| `orders` payment columns (`deposit_paid`, `deposit_amount`, `amount_paid`, `amount_outstanding`, `stripe_session_id`) | updated by checkout/webhook/lifecycle routes (`v2-checkout.cjs:251`, `stripe-webhooks.cjs:174`, `v2-jobs.cjs:1585`) | Order-lifecycle module (Rank 7), with payment module updates via API/event contract |
| `customers` (email/name for checkout context) | read and created in checkout (`v2-checkout.cjs:120-141`) | Order-lifecycle module (Rank 7) |

Conflict flag:
- Current legacy behavior has both payment and lifecycle paths writing `orders` and `payments`.
- Ownership split must be operator-locked before Gate 2.

## 4) Dependency on auth

Observed auth dependencies:
- `POST /api/orders/:id/pay` is public (`order-payments.cjs:39-42`).
- `POST /api/v2/checkout` is public guest checkout (`v2-checkout.cjs:89-92`).
- Admin/manual payment entry in `v2-jobs` requires JWT (`v2-jobs.cjs:1513-1517`).

Contract decision:
- Customer checkout/payment-link flow can run without login (signed order/payment token model).
- Admin/manual payment operations require Rank 5 admin auth.
- Stripe webhook depends on webhook secret, not user auth.

## 5) Dependency on order-lifecycle

Can payments exist without order-lifecycle?
- Full replacement: **No**. Payment workflow requires authoritative order identity/totals/state.
- Transitional bridge: **Yes (limited)** by reading legacy orders during migration.

Contract decision:
- Rank 6 may start with compatibility mode (legacy order read).
- Rank 6 cutover is blocked until Rank 7 defines canonical order write authority.

## Fresh-slate replacement status

- Fresh-slate Stripe checkout/webhook/payment-table replacement: `UNVERIFIED`.
- Evidence run key: `CAP-20260222-001530__rag.anythingllm.ask__Rn90n87541`.

## Gate 1 outcome

- API/table boundary defined.
- Gate 2 blocked on ownership lock for `payments` vs `orders` write authority and event-ledger idempotency schema approval.
