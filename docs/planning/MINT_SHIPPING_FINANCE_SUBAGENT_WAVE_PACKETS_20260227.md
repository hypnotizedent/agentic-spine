---
status: draft
owner: "@ronny"
created: 2026-02-27
scope: mint-shipping-finance-subagent-wave-packets
authority: LOOP-MINT-SHIPPING-CARRIER-INTEGRATION-20260226
---

# Mint Shipping + Finance Subagent Wave Packets (Orchestration Only)

## Mode

- terminal role: orchestration-only
- implementation mode: subagent waves only
- atomicity rule: one wave = one commit
- direct code edits by orchestration terminal: prohibited

## Baseline (verified before dispatch)

- session start: `CAP-20260227-005410__session.start__Rnpt592251`
- shape lock baseline: 17 pass / 0 warn / 0 fail
- internal shape lock baseline: 17 pass / 0 warn / 0 fail
- content lock baseline: 17 pass / 0 warn / 0 fail
- module tests baseline:
  - shipping: 28 passed
  - finance-adapter: 71 passed

## Hard Boundaries

1. Do not modify `suppliers/` source.
2. Do not modify `pricing/` source.
3. Do not touch supplier COGS gap lane `GAP-OP-1037..1041` in execution waves.
4. Do not touch pricing normalization lane `GAP-OP-1009..1016`.
5. Allowed source modules for waves: `shipping/`, `finance-adapter/`.
6. Keep existing route/API compatibility (do not break `/buy` alias or existing finance events).

## Global Guard Commands (run after every wave)

```bash
cd ~/code/mint-modules
bash scripts/guard/module-shape-lock.sh --mode full --policy enforce
bash scripts/guard/module-internal-shape-lock.sh --mode full --policy enforce
bash scripts/guard/module-content-lock.sh --mode full --policy enforce

cd ~/code/mint-modules/shipping && npm test
cd ~/code/mint-modules/finance-adapter && npm test
```

## Wave S1 Packet

- wave id: `S1`
- target gaps: `GAP-OP-1023`, `GAP-OP-1032`
- objective: shipping emits granular finance events; finance-adapter accepts shipping-specific event and ref types.
- commit message: `WS1a: extend shipping-finance event contract and emission flow`

### Subagent File Targets

- finance-adapter:
  - `finance-adapter/src/routes/events.ts`
  - `finance-adapter/src/services/event-processor.ts`
  - `finance-adapter/src/__tests__/events-validation.test.ts`
  - `finance-adapter/src/__tests__/event-processor.test.ts`
- shipping:
  - `shipping/src/routes/shipping.ts`
  - `shipping/src/config.ts` (if finance endpoint env wiring is required)
  - `shipping/src/__tests__/shipping-routes.test.ts`
  - optional new helper: `shipping/src/services/finance-events.ts`

### Required Contract Changes

1. Add finance event types: `shipping_cost`, `shipping_delta`, `shipping_refund`.
2. Add finance ref type: `tracking_code`.
3. Extend shipping event metadata to include:
   - `carrier`, `service_level`, `billing_entity`, `package_count`, `weight_oz`, `zone`, `order_ref`.
4. In shipping `POST /labels` and `/buy` flow, emit finance event after successful label purchase.
5. In shipping `POST /:id/refund`, emit `shipping_refund` event.
6. Failure policy: finance emission failures are logged/reported but must not fail shipping label/refund API response.

### Done Check

- all guard commands pass
- shipping and finance tests pass
- existing accepted finance events (`order_confirmed`, `shipping_label`, `subcontract`) remain valid

## Wave S2 Packet

- wave id: `S2`
- target gaps: `GAP-OP-1026`, `GAP-OP-1031`
- objective: typed carrier registry/default routing contract in shipping.
- commit message: `WS2a: add typed carrier registry and default routing rules`

### Subagent File Targets

- `shipping/src/contracts/carrier-registry.ts` (new)
- `shipping/src/contracts/carrier-defaults.ts` (new)
- `shipping/src/routes/shipping.ts`
- `shipping/src/__tests__/shipping-routes.test.ts`
- optional new tests: `shipping/src/__tests__/carrier-defaults.test.ts`

### Required Contract Changes

1. Add carrier config with explicit states:
   - UPS enabled + default
   - USPS enabled
   - FedEx planned/disabled
2. Provide deterministic default selection API by context.
3. Ensure `/rates` route uses contract-driven defaults, not hardcoded branching.

### Done Check

- deterministic carrier selection covered by tests
- fallback behavior covered
- all guards/tests pass

## Wave S3 Packet

- wave id: `S3`
- target gap: `GAP-OP-1027`
- objective: first-class delta adjustment tracking and finance emission path.
- commit message: `WS3a: implement shipping delta adjustment tracking and eventing`

### Subagent File Targets

- `shipping/src/services/delta-tracker.ts` (new)
- `shipping/src/services/shipping-repository.ts`
- `shipping/src/routes/shipping.ts`
- `shipping/src/types.ts`
- `shipping/migrations/002_create_shipping_deltas.sql` (new)
- `shipping/migrations/002_create_shipping_deltas_down.sql` (new)
- tests:
  - `shipping/src/__tests__/shipping-routes.test.ts`
  - optional `shipping/src/__tests__/delta-tracker.test.ts`

### Required Contract Changes

1. Add `DeltaAdjustment` model with shipment linkage and reason.
2. Persist delta records in shipping DB.
3. Emit finance `shipping_delta` billable event on delta record.
4. Add endpoint `GET /api/v1/shipping/deltas/:shipmentId`.

### Done Check

- migration applies/rolls back cleanly in dry-run check
- delta endpoint and emission tested
- all guards/tests pass

## Wave S4 Packet

- wave id: `S4`
- target gaps: `GAP-OP-1028`, `GAP-OP-1030`
- objective: formal EasyPost billing boundary + metrics baseline contract.
- commit message: `WS4a: codify easypost billing boundary and metrics baseline`

### Subagent File Targets

- `shipping/src/contracts/easypost-boundary.ts` (new)
- `shipping/src/contracts/shipping-metrics.ts` (new)
- `shipping/src/types.ts`
- `shipping/src/services/shipping-repository.ts`
- `shipping/src/routes/shipping.ts`
- `shipping/migrations/003_add_shipping_label_billing_entity.sql` (new)
- `shipping/migrations/003_add_shipping_label_billing_entity_down.sql` (new)

### Required Contract Changes

1. Declare `billing_entity = easypost_wallet` as programmatic boundary constant.
2. Add `billing_entity` field to shipping label persistence model.
3. Define baseline metrics constants:
   - avg_postage_cents `1690`
   - range `[604, 3928]`
   - ancillary fee baselines `0`
   - recharge overhead `3.75`
4. Ensure finance emission includes `billing_entity`.

### Done Check

- boundary constants exported and consumed
- migration + tests pass
- all guards/tests pass

## Wave S5 Packet

- wave id: `S5`
- target gap: `GAP-OP-1022`
- objective: contractize shipping read-only address resolution from customers.
- commit message: `WS5a: add shipping address-resolution contract with fallback`

### Subagent File Targets

- `shipping/src/contracts/address-resolution.ts` (new)
- `shipping/src/routes/shipping.ts`
- `shipping/src/config.ts` (if customers endpoint config required)
- tests:
  - `shipping/src/__tests__/shipping-routes.test.ts`
  - optional `shipping/src/__tests__/address-resolution.test.ts`

### Required Contract Changes

1. `resolveShippingAddress(customerId)` read contract.
2. Hard boundary: shipping never writes customer data.
3. Fallback path to request payload address when customer service unavailable.

### Done Check

- success + fallback paths are tested
- all guards/tests pass

## Wave S6 Packet

- wave id: `S6`
- target gap: `GAP-OP-1044`
- objective: establish shipment lifecycle receipt-chain foundation.
- commit message: `WS6a: add shipment lifecycle receipt-chain state machine`

### Subagent File Targets

- `shipping/src/contracts/receipt-chain.ts` (new)
- `shipping/src/routes/shipping.ts`
- `shipping/src/services/shipping-repository.ts`
- `shipping/src/types.ts`
- `shipping/migrations/004_add_shipping_label_lifecycle_state.sql` (new)
- `shipping/migrations/004_add_shipping_label_lifecycle_state_down.sql` (new)
- tests:
  - `shipping/src/__tests__/shipping-routes.test.ts`
  - optional `shipping/src/__tests__/receipt-chain.test.ts`

### Required Contract Changes

1. Lifecycle states:
   - `label_created`
   - `tracking_active`
   - `in_transit`
   - `delivered`
   - `finance_reconciled`
2. Enforce transition validity.
3. Wire transition updates from tracking/refund/reconciliation touchpoints.

### Done Check

- invalid transition rejection covered by tests
- migration + tests pass
- all guards/tests pass

## Dispatch Sequence

1. Dispatch `S1` and require green verify before merge.
2. Dispatch `S2` only after `S1` commit lands.
3. Continue through `S6` sequentially.
4. If a wave fails any guard/test, stop sequence and open remediation micro-wave for that wave only.

## Conflict-Avoidance Clause

- If subagent detects edits in `suppliers/` or `pricing/` during any wave, abort wave and escalate.
- If subagent needs to touch `GAP-OP-1037..1041`, route as separate operator approval and do not proceed under this packet.
