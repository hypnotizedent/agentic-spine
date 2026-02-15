# LOOP-HA-SSOT-BASELINE-20260215

## Objective
Establish a canonical, regression-proof, single source of truth (SSOT) for the entire Home Assistant installation — devices, entities, add-ons, HACS, integrations, automations, states, scenes, helpers, scripts, dashboards. One unified baseline binding that a home agent reads to understand the house.

## Gaps

| Gap ID | Type | Description |
|--------|------|-------------|
| GAP-OP-475 | missing-entry | New snapshot capabilities — scenes, scripts, HACS |
| GAP-OP-476 | missing-entry | Entity state baseline snapshot + expected-unavailable allowlist |
| GAP-OP-477 | missing-entry | Run all snapshots to establish on-disk bindings |
| GAP-OP-478 | missing-entry | Unified baseline binding + ha.ssot.baseline.build capability |
| GAP-OP-479 | missing-entry | Governance doc — HASS_SSOT_BASELINE.md |
| GAP-OP-480 | missing-entry | D115 — HA SSOT baseline freshness gate |
| GAP-OP-481 | runtime-bug | Fix D108 media health endpoint — Tailscale IP preference |

## Commit Plan
1. `feat(GAP-OP-475,476): HA snapshot capabilities — scenes, scripts, HACS, entity state baseline`
2. `feat(GAP-OP-477,478,479): HA SSOT baseline system — unified binding + governance doc`
3. `fix(GAP-OP-480,481): D115 baseline freshness gate + D108 tailscale IP fix`
4. `gov(LOOP-HA-SSOT-BASELINE-20260215): close loop — 7 gaps, HA baseline SSOT`

## Status
- [x] Loop registered
- [ ] Phase 1: Fill snapshot gaps (GAP-OP-475, 476)
- [ ] Phase 2: Generate bindings + unified baseline (GAP-OP-477, 478, 479)
- [ ] Phase 3: Gate + D108 fix (GAP-OP-480, 481)
- [ ] Loop closed
