---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ha-schema-environments-v1-exec-pack
parent_loop: LOOP-HA-SCHEMA-ENVIRONMENTS-V1-20260217
gap_id: GAP-OP-653
---

# HA Schema Environments V1 Executor Pack

## Objective

Provide deterministic executor handoff for `GAP-OP-653` so schema/environment implementation can proceed without runtime mutation ambiguity.

## Exact File Touch Map (Executor Lane)

- `ops/bindings/ha.naming.convention.yaml` (new, canonical naming contract)
- `ops/bindings/ha.environments.yaml` (new, canonical environment IDs and lifecycle state)
- `ops/bindings/ha.device.map.yaml` (only if reconciliation keys require schema alignment)
- `ops/bindings/ha.ssot.baseline.yaml` (only for schema-linked baseline parity)
- `docs/governance/_audits/HA_ORGANIZATION_V1_PLAN_20260217.md` (decision references only)
- `docs/governance/_audits/HA_SCHEMA_ENVIRONMENTS_V1_EXEC_PACK_20260217.md` (execution evidence updates)

## Acceptance Criteria

1. `ha.naming.convention.yaml` exists with snake_case `{area}_{function}_{qualifier}` contract.
2. `ha.environments.yaml` exists with `home` as active and `shop` as planned.
3. Schema definitions include reconciliation expectations for entity/device identity mapping.
4. `verify.core.run` and `verify.domain.run home --force` remain green after schema updates.
5. No forbidden runtime mutation path is used (UI/manual websocket/ad-hoc SSH mutation).

## Stop Conditions

1. Any attempt to mutate live HA runtime/devices in this prep lane.
2. Any proposed change outside WS3 schema boundary files listed above.
3. Any status mutation of protected non-WS3 gaps.
4. Any certification failure in `verify.core.run` or `verify.domain.run home --force`.

## Protected-Gap Unchanged List

- `GAP-OP-590`
- `GAP-OP-635`
- `GAP-OP-649`
- `GAP-OP-650`
- `GAP-OP-652`
- `GAP-OP-654`
- `GAP-OP-655`

## Execution Evidence (Implemented)

- Added `/Users/ronnyworks/code/agentic-spine/ops/bindings/ha.naming.convention.yaml` with canonical snake_case `{area}_{function}_{qualifier}` contract.
- Added `/Users/ronnyworks/code/agentic-spine/ops/bindings/ha.environments.yaml` with `home` (active) and `shop` (planned) environment IDs.
- Included reconciliation hooks to `ha.device.map.yaml`, `home.device.registry.yaml`, and `ha.ssot.baseline.yaml`.
- Included post-mutation refresh contract linkage: `ha.device.map.build -> ha.refresh -> ha.ssot.baseline.build`.
