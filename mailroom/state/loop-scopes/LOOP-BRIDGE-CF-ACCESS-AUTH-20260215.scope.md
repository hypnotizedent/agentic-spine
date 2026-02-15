---
id: LOOP-BRIDGE-CF-ACCESS-AUTH-20260215
status: closed
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-471
  - GAP-OP-472
  - GAP-OP-473
  - GAP-OP-474
---

# LOOP: Cloudflare Access Service-Token Auth For Mailroom Bridge

## Objective

Enable non-interactive auth for hosted Claude runtimes so iPhone sessions can call the public spine bridge (`https://spine.ronny.works`) without prompting the operator to paste `MAILROOM_BRIDGE_TOKEN` each chat.

## Problem Statement

- Hosted Claude runtimes cannot read local token files on the Mac.
- Current bridge requires `MAILROOM_BRIDGE_TOKEN` for all non-health endpoints.
- Result: Claude iOS asks for a token every session, defeating “seamless mobile”.

## Approach

Use Cloudflare Access **service tokens** (client-id + client-secret headers) as an alternate authentication path for the bridge.

- Cloudflare Access enforces at the edge.
- Bridge accepts Access service-token headers as equivalent auth (no bridge token paste needed).
- No secrets are committed to git; service-token secret is stored in Vaultwarden and/or local ignored state.

## Deliverables

1. Cloudflare Access app + allow policy for `spine.ronny.works` (service-token gated, CLI/API only).
2. Bridge runtime supports Access service-token auth (configurable via binding; secrets loaded from ignored state/env).
3. Governance docs + skill updated to describe Access headers + egress allowlist gotcha.
4. Verification: unauthenticated request blocked; Access-auth request succeeds for `/loops/open`.

## Acceptance Criteria

1. From hosted runtime, `GET https://spine.ronny.works/health` works when Access headers are present.
2. From hosted runtime, `GET https://spine.ronny.works/loops/open` works without providing `MAILROOM_BRIDGE_TOKEN` (Access headers only).
3. Tailnet/local behavior remains unchanged for existing clients.

## Notes

- Cloudflare tunnel ingress already routes `spine.ronny.works` to tailnet-exposed bridge.
- The Cloudflare Access app was created via API during exploratory work; this loop brings the configuration under SSOT and completes enforcement.
