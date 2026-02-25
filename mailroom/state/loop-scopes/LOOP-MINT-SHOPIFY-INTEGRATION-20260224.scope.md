---
loop_id: LOOP-MINT-SHOPIFY-INTEGRATION-20260224
created: 2026-02-24
status: deferred
owner: "@ronny"
scope: mint
priority: medium
linked_gaps:
  - GAP-OP-874
objective: >
  Implement Shopify integration module in mint-modules: webhook receiver,
  order mapping, fulfillment callback, MCP tools. Deferred from W58 —
  not needed for current release.
---

# Loop Scope: LOOP-MINT-SHOPIFY-INTEGRATION-20260224

## Objective

Implement Shopify integration module in mint-modules. Shopify is an inbound
order channel (customers sell on Shopify, route production to Mint as partner).
Legacy OAuth routes exist in mint-os but no mint-modules code.

## Deferred Reason

Explicitly excluded from W58 gate baseline recovery. Not blocking any active
gates or release verification. Will be picked up when Mint module work resumes.

## Stage-0 Completion (2026-02-24)

Stage-0 contracts and stubs delivered. GAP-OP-874 remains open — stubs alone
do not satisfy the gap (execution phases P1-P5 remain).

P1 sandbox intentionally not started. Loop returned to deferred status.
No live Shopify API calls, no webhook registration, no OAuth flow.

### Artifacts Created (mint-modules repo, commit 948f3b3)

| Artifact | Location |
|----------|----------|
| Integration contract | `shopify-module/docs/INTEGRATION_CONTRACT.md` |
| Roadmap (P0-P5) | `shopify-module/docs/ROADMAP.md` |
| MCP tool spec | `shopify-module/docs/MCP_TOOL_SPEC.md` |
| Shopify webhook schema | `shopify-module/schema/shopify-order-webhook.schema.json` |
| Field mapping crosswalk | `shopify-module/schema/shopify-to-mint-mapping.json` |
| Normalized intake schema | `shopify-module/schema/mint-intake-normalized.schema.json` |
| Sample webhook fixture | `shopify-module/fixtures/sample-order-webhook.json` |
| Sample normalized output | `shopify-module/fixtures/sample-normalized-intake.json` |
| Module skeleton (Express) | `shopify-module/src/` (Shopify API routes return 501; /health returns 200) |
| Dockerfile + compose | `shopify-module/Dockerfile`, `docker-compose.yml` |

### Audit Summary

- **34 Shopify-related files** found across agentic-spine (integration registry, gap, loop, domain migration docs, soak checks, secrets namespace)
- **0 files** in mint-modules before this work
- **13 files** in workbench (legacy SSOT, token script, MCP inventory, authority doc, scripts registry, NAS inventory, archive refs)
- Legacy OAuth routes in mint-os: `routes/shopify.cjs` (working but not in mint-modules)
- Shopify credentials in Infisical at `/spine/integrations/commerce-mail` (6 keys)

### Key Design Decisions

1. **One Shopify order -> N Mint intake records** (one per line item)
2. **decoration_type inference**: from line item custom properties -> product mapping -> "other" fallback
3. **Port allocation**: 4100 (next available after payment:4000)
4. **MCP tools**: 4 planned (list_stores, order_status, webhook_health, fulfillment_push) — registered in P5
5. **No database in Stage-0**: connected store registry is contract-only

## Required Deliverables

1. Webhook receiver for Shopify order events
2. Order mapping (Shopify order → Mint job)
3. Fulfillment callback (Mint completion → Shopify fulfillment)
4. MCP tools for operator visibility
5. See `ops/bindings/platform.integration.registry.yaml` for full spec

## Linked Gaps

- GAP-OP-874 (high): Shopify integration module missing from mint-modules
