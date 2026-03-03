---
loop_id: LOOP-TAXLEGAL-W1-DOMAIN-ROUTING-INTEGRATION-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: agentic-spine
objective: Define Wave 1 tax-legal domain governance integration across registry, terminal roles, taxonomy bridge, and domain docs routing.
---

# Loop Scope: TaxLegal W1 Domain Routing Integration

## Problem Statement

Even with contracts drafted, Tax-Legal cannot be discoverable or governable unless registry/routing surfaces are prepared. Current agent registry, terminal role contract, taxonomy bridge, and domain route bindings do not include tax-legal mappings.

## Deliverables

1. Planned delta spec for `ops/bindings/agents.registry.yaml` (agent + routing keywords).
2. Planned delta spec for `ops/bindings/terminal.role.contract.yaml` (`DOMAIN-TAXLEGAL-01`, planned).
3. Planned delta spec for `ops/bindings/domain.taxonomy.bridge.contract.yaml` tax-legal mapping.
4. Planned domain docs surfaces for `docs/governance/domains/tax-legal/` including runbook + capabilities stub.
5. Planned updates for `ops/bindings/domain.docs.routes.yaml` tax-legal routes.
6. Child gaps filed and linked for each missing routing/governance artifact.

## Acceptance Criteria

1. Tax-legal domain appears in proposed registry/routing plan with clear status = planned.
2. Terminal/runtime mapping path is explicit and role-safe.
3. Domain doc routing includes spine stub targets for tax-legal docs.
4. Child gaps exist for every required cross-file governance update.

## Constraints

1. No runtime enablement in this loop.
2. No capability registration execution in this loop.
3. Keep all changes design-only and governance-scoped.

## Gaps

1. `GAP-OP-1432` — missing domain capabilities stub.
2. `GAP-OP-1433` — missing tax-legal agent registry + routing keywords.
3. `GAP-OP-1434` — missing planned terminal role mapping.
4. `GAP-OP-1435` — missing taxonomy bridge mapping.
5. `GAP-OP-1436` — missing domain docs route bindings.
