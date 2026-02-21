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
4. `spine.control.cycle` (mutating/manual): autonomous observe-plan-act pass that can execute capability actions and enqueue delegated agent-tool tasks.

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
- Executes `route_target.type=capability` items directly.
- Optionally supports `route_target.type=agent_tool` via governed delegation:
  - resolve agent using `agent.route --json`,
  - run `agent.health.check-all` preflight (strict by default),
  - enqueue task through `mailroom.task.enqueue`.
- If target capability approval is manual, `--confirm` is required.
- Writes control-plane latest artifact:
  - `mailroom/outbox/operations/control-plane-latest.json`
  - `mailroom/outbox/operations/control-plane-latest.md`

### `spine.control.cycle`

- Performs one autonomous pass:
  1. collect tick
  2. build plan
  3. select actions by priority (`P0..P2`) and max action count
  4. execute/delegate selected actions
- Manual capabilities are skipped unless `--confirm-manual` is provided.
- Delegated agent-tool tasks are health-gated unless `--allow-unhealthy-agents`.

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
echo "yes" | ./bin/ops cap run spine.control.cycle
```
