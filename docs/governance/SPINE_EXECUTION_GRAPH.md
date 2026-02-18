---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: spine-execution-graph
---

# Spine Execution Graph

## Purpose

Defines the canonical execution graph for spine control-plane state transitions and exposes
read-only graph visualization through `spine.graph.show`.

Authoritative bindings:
- `ops/bindings/spine.execution.graph.yaml`
- `ops/bindings/spine.execution.graph.schema.yaml`

## State Authority Split

Repo-authoritative surfaces:
- `receipts/sessions`
- `mailroom/state/loop-scopes`
- `ops/bindings/operational.gaps.yaml`

Runtime-authoritative surfaces:
- `${SPINE_STATE}/ledger.csv`
- `${SPINE_STATE}/handoffs`
- `${SPINE_STATE}/orchestration`
- `${SPINE_OUTBOX}/proposals`
- `${SPINE_OUTBOX}/audits`

## Graph Contract

Node and edge IDs use lowercase snake-case IDs.

Required node fields:
- `id`
- `type`
- `description`

Required edge fields:
- `id`
- `from`
- `to`
- `event_type`
- `description`

Validation rules:
- Edge `from`/`to` references must resolve to existing node IDs.
- View include lists must resolve to existing node/edge IDs.
- Event types use `<noun>.<verb>` canonical format.

## Capability

Use:
```bash
./bin/ops cap run spine.graph.show --view core --format mermaid
```

`spine.graph.show` is read-only and emits graph output to stdout (`mermaid|json|yaml`).
