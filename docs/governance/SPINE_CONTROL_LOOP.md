---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: spine-control-loop
---

# Spine Control Loop

## Purpose

`spine.control.*` provides a single control-plane loop over operational state:

1. `spine.control.tick` (read-only): aggregate current signals.
2. `spine.control.plan` (read-only): produce prioritized next actions and route targets.
3. `spine.control.execute` (mutating/manual): execute selected capability-backed actions with receipt linkage.

## Capability Contract

### `spine.control.tick`

- Aggregates loops, gaps, proposal health, calendar status, alerting status, handoff status, and timeline verify signals.
- Emits deterministic envelope:
  - `capability`
  - `schema_version`
  - `status`
  - `generated_at`
  - `data.summary`
  - `data.loops|gaps|proposals|calendar|alerts|handoffs|timeline`

### `spine.control.plan`

- Consumes tick signals and produces prioritized actions.
- Every action includes:
  - `action_id`
  - `priority`
  - `reason`
  - `route_target.type` (`capability|agent_tool`)
  - Capability targets include executable `capability` + `args`.

### `spine.control.execute`

- Runs selected `--action-id` items from latest plan.
- Executes only `route_target.type=capability` items.
- If target capability approval is manual, `--confirm` is required.
- Writes control-plane latest artifact:
  - `mailroom/outbox/operations/control-plane-latest.json`
  - `mailroom/outbox/operations/control-plane-latest.md`

## Runtime Path Contract

Artifact paths follow `ops/bindings/mailroom.runtime.contract.yaml`:

- If runtime externalization is active, outputs resolve under `$SPINE_OUTBOX/operations`.
- If inactive, outputs resolve under repo `mailroom/outbox/operations`.

## Usage

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run spine.control.tick
./bin/ops cap run spine.control.plan
echo "yes" | ./bin/ops cap run spine.control.execute --action-id A01-loop-gap-verify
```
