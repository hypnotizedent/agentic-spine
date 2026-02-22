---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-secrets-bootstrap-gate1
loop_id: LOOP-MINT-SECRETS-BOOTSTRAP-CONTRACT-20260222
---

# MINT Secrets Bootstrap Plan (Gate 1)

Contract-only artifact. Names/paths only, no secret values.

Evidence:
- Live project parity: `CAP-20260222-001207__secrets.projects.status__Rjcbo11608`
- Namespace policy: `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.namespace.policy.yaml:65-79`
- Inventory catalog: `/Users/ronnyworks/code/agentic-spine/ops/bindings/secrets.inventory.yaml:22-71`
- ADR-003 (one project per module + shared): `/Users/ronnyworks/code/mint-modules/docs/DECISIONS/ADR-003-SECRETS-PROJECT-MODEL.md:10-30`
- Env matrix baseline: `/Users/ronnyworks/code/mint-modules/docs/DEPLOYMENT/MINT_MODULES_ENV_MATRIX.md:14-95`
- Legacy scripts: `/Users/ronnyworks/ronny-ops/scripts/load-secrets.sh:41-78`, `/Users/ronnyworks/ronny-ops/scripts/sync-secrets-to-env.sh:37-53`
- Legacy env files index: `/Users/ronnyworks/ronny-ops/**/.env*` (examples listed by audit command)
- Communications readiness signal: `CAP-20260222-001200__communications.provider.status__Rq8lc11610`

## 1) Current state: existing projects vs Rank 5+ need

### Existing live projects (9 found / 9 expected)
- `infrastructure`
- `mint-os-api`
- `mint-os-vault` (deprecated/overlap)
- `n8n`
- `finance-stack` (deprecated)
- `media-stack`
- `immich`
- `home-assistant`
- `ai-services`

### Existing mint module namespaces in policy
- `artwork`, `quote-page`, `order-intake`, `pricing`, `suppliers`, `shipping`, `mint-shared-infra`

### Rank 5+ required domains not present
- `auth`
- `payment`
- `order-lifecycle`
- `notification` (or `communications-mint` explicit module namespace)

Gap verdict:
- Project inventory is healthy, but rank 5+ module namespace coverage is incomplete.

## 2) Required namespace/project additions for Rank 5+

Target model (ADR-003 aligned): one project per module + shared infra.

Required additions:
1. `mint-auth` project (or `/spine/services/auth` namespace if single-project operation remains)
2. `mint-payment` project (or `/spine/services/payment` namespace)
3. `mint-order-lifecycle` project (or `/spine/services/order-lifecycle` namespace)
4. `mint-notification` project (or `/spine/services/notification` namespace)

Required policy map updates:
- Add entries under `module_namespaces` for the four domains above.
- Add key-path overrides for new domain-prefixed keys where runtime loaders depend on canonical routing.

## 3) Name-only key bootstrap matrix (Rank 5+)

### Auth
- `JWT_SECRET`
- `ADMIN_JWT_SECRET`
- `AUTH_ACCESS_TOKEN_TTL`
- `AUTH_REFRESH_TOKEN_TTL` (if used)
- `PIN_TOKEN_TTL` (workforce token policy)

### Payment
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `CUSTOMER_APP_URL`
- `PAYMENT_DEPOSIT_DEFAULT_PERCENT`

### Order lifecycle
- `ORDER_LIFECYCLE_API_KEY`
- `ORDER_LIFECYCLE_DATABASE_URL`
- `MINIO_*` keys if lifecycle owns file side-effects
- `N8N_EVENT_WEBHOOK_URL` (if lifecycle emits directly)

### Notification
- `RESEND_API_KEY`
- `FROM_EMAIL`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER`
- `NOTIFICATION_DEFAULT_CHANNEL_POLICY`

## 4) Legacy bootstrap drift to resolve

Observed legacy-first behavior:
- `load-secrets.sh` fetches operational keys mainly from `infrastructure` and `mint-os-api` projects.
- `sync-secrets-to-env.sh` maps only legacy project IDs and legacy docker-host `.env` paths.

Impact:
- Rank 5+ modules cannot rely on legacy `mint-os-api` secret sprawl without violating ADR-003/module boundary intent.

Required bootstrap contract change:
- Add rank 5+ module projects/namespaces to governed secret routing surfaces before Gate 2.
- Keep legacy project reads for hold-window compatibility only.

## 5) Execution constraints

- No secret values in docs, receipts, or proposal payloads.
- No direct edits to legacy repo paths.
- No changes to rank 1-4 namespaces in this contract.

## Gate 1 outcome

- Namespace/project gap is explicit for Rank 5+.
- Gate 2 for Auth/Payment/Order Lifecycle/Notification is blocked until namespace policy and key-route bootstrap are extended.
