---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-27
scope: w45a-secrets-inventory-alias-drift
---

# W45A Secrets Inventory + Alias Drift Map (Shipping, Payment, Notifications)

## Evidence Run Keys
- `session.start`: `CAP-20260227-040647__session.start__Ry60323009`
- `loops.status`: `CAP-20260227-040647__loops.status__Rbqbw23022`
- `gaps.status`: `CAP-20260227-040647__gaps.status__Rbiig23026`
- `secrets.inventory.status`: `CAP-20260227-040647__secrets.inventory.status__Rmpis23054`
- `secrets.namespace.status`: `CAP-20260227-040647__secrets.namespace.status__Rpl7023055`
- `secrets.runway.status` (in-flight evidence stream): `CAP-20260227-040746__secrets.runway.status__Ruge837735`

## Scope and Inputs
- Spine contracts:
  - `ops/bindings/secrets.namespace.policy.yaml`
  - `ops/bindings/secrets.runway.contract.yaml`
  - `ops/bindings/secrets.bundle.contract.yaml`
  - `ops/bindings/secrets.enforcement.contract.yaml`
- Mint runtime env consumers:
  - `mint-modules/shipping/src/config.ts`
  - `mint-modules/payment/src/config.ts`
  - `mint-modules/notifications/src/config.ts`

## Canonical Inventory (Current)

| Module | Runtime env keys consumed | Canonical keys currently routed in spine | Canonical path |
|---|---|---|---|
| shipping | `API_KEY`, `JWT_SECRET`, `DATABASE_URL`, `EASYPOST_API_KEY`, `EASYPOST_WEBHOOK_SECRET` | `SHIPPING_API_KEY`, `SHIPPING_DATABASE_URL`, `SHIPPING_EASYPOST_API_KEY`, `SHIPPING_EASYPOST_WEBHOOK_SECRET` | `/spine/services/shipping` |
| payment | `API_KEY`, `JWT_SECRET`, `DATABASE_URL`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | `PAYMENT_API_KEY`, `PAYMENT_DATABASE_URL` | `/spine/services/payment` |
| notifications | `API_KEY`, `JWT_SECRET` | *(none module-specific yet)*; shared comms keys (`RESEND_*`, `TWILIO_*`) routed to communications | `/spine/services/communications` (shared), no `/spine/services/notifications` contract entry yet |

## Alias Drift Findings
1. Generic runtime names (`API_KEY`, `DATABASE_URL`, `JWT_SECRET`) are still module-entry env names, but not fully mapped to module-specific canonical keys for all three modules.
2. Shipping is partially normalized: API/DB/EasyPost canonical keys exist, but `JWT_SECRET` is not module-scoped in current key routing contracts.
3. Payment is partially normalized: `PAYMENT_API_KEY`/`PAYMENT_DATABASE_URL` exist, but Stripe and JWT keys are not module-scoped in current routing contracts.
4. Notifications is unnormalized at module scope: no `NOTIFICATIONS_*` key family is declared in secrets route contracts.
5. `secrets.runway.status` still reports inferred-route drift for generic keys in legacy stack contexts (e.g., `JWT_SECRET`, `STRIPE_WEBHOOK_SECRET`), confirming alias drift remains active.

## W45A Proposed Canonical Alias Map (Target)

| Runtime key | Shipping canonical | Payment canonical | Notifications canonical |
|---|---|---|---|
| `API_KEY` | `SHIPPING_API_KEY` | `PAYMENT_API_KEY` | `NOTIFICATIONS_API_KEY` |
| `DATABASE_URL` | `SHIPPING_DATABASE_URL` | `PAYMENT_DATABASE_URL` | `NOTIFICATIONS_DATABASE_URL` *(optional; only if module storage is added)* |
| `JWT_SECRET` | `SHIPPING_JWT_SECRET` | `PAYMENT_JWT_SECRET` | `NOTIFICATIONS_JWT_SECRET` |
| `EASYPOST_API_KEY` | `SHIPPING_EASYPOST_API_KEY` | n/a | n/a |
| `EASYPOST_WEBHOOK_SECRET` | `SHIPPING_EASYPOST_WEBHOOK_SECRET` | n/a | n/a |
| `STRIPE_SECRET_KEY` | n/a | `PAYMENT_STRIPE_SECRET_KEY` | n/a |
| `STRIPE_WEBHOOK_SECRET` | n/a | `PAYMENT_STRIPE_WEBHOOK_SECRET` | n/a |

## W45A Output
- Planning map: `docs/planning/W45A_SECRETS_ALIAS_DRIFT_MAP_20260227.yaml`
- Next step lock:
  - `W45B`: add contract + gates `D245-D250` (report mode)
  - `W45E`: promote to enforce only after 3 clean runs
