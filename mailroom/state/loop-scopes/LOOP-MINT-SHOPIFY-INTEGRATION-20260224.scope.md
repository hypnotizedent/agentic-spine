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

## Required Deliverables

1. Webhook receiver for Shopify order events
2. Order mapping (Shopify order → Mint job)
3. Fulfillment callback (Mint completion → Shopify fulfillment)
4. MCP tools for operator visibility
5. See `ops/bindings/platform.integration.registry.yaml` for full spec

## Linked Gaps

- GAP-OP-874 (high): Shopify integration module missing from mint-modules
