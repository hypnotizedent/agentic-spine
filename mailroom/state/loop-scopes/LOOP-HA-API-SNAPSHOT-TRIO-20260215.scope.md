---
loop_id: LOOP-HA-API-SNAPSHOT-TRIO-20260215
status: open
owner: "@ronny"
opened: 2026-02-15
parent_loop: null
gaps:
  - GAP-OP-379
  - GAP-OP-380
  - GAP-OP-381
---

# LOOP-HA-API-SNAPSHOT-TRIO-20260215

> Three HA REST API snapshot capabilities for integration, automation, and helper inventories.

## Scope

The extraction matrix (`HASS_LEGACY_EXTRACTION_MATRIX.md`) shows three "Full gap" categories addressable via HA REST API snapshot capabilities:

1. **GAP-OP-379** — Integration inventory (60 integrations, no spine coverage)
2. **GAP-OP-380** — Automation inventory (14 automations, no spine coverage)
3. **GAP-OP-381** — Entity/helper inventory (input_booleans/selects/datetimes, no spine coverage)

## Pattern

Follows `ha-dashboard-snapshot` / `ha-device-map-build` (REST API via Infisical `HA_API_TOKEN`).

## Endpoints

- `GET /api/config/config_entries/entry` — integrations
- `GET /api/states` filter `automation.*` — automations
- `GET /api/states` filter `input_*` — helpers

## Deliverables

- 3 scripts: `ha-integrations-snapshot`, `ha-automations-snapshot`, `ha-helpers-snapshot`
- 3 bindings: `ha.integrations.yaml`, `ha.automations.yaml`, `ha.helpers.yaml`
- Wired in capabilities.yaml, capability_map.yaml, MANIFEST.yaml
- Extraction matrix coverage updated
