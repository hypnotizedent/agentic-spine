---
loop_id: LOOP-SPINE-SELF-DRIVING-ORCHESTRATION-LAYER-V1-20260221-20260221
created: 2026-02-21
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Evolve spine control loop from operator-assisted to self-driving by adding autonomous cycle execution, delegated agent-tool task enqueue, and strict health/routing governance.
---

# Loop Scope: LOOP-SPINE-SELF-DRIVING-ORCHESTRATION-LAYER-V1-20260221-20260221

## Objective

Evolve spine control loop from operator-assisted to self-driving by adding autonomous cycle execution, delegated agent-tool task enqueue, and strict health/routing governance.

## Parent Gaps

- GAP-OP-678
- GAP-OP-679
- GAP-OP-680

## Locked Decisions

- Self-driving stays governed: no bypass of capability receipts.
- Delegated routes enqueue work through `mailroom.task.enqueue` only.
- Delegation is strict health-gated via `agent.health.check-all --strict` by default.
- `spine.control.cycle` selects bounded action count and priority window per pass.
- Manual capabilities in cycle are skipped unless explicit manual confirmation is enabled.

## Scope

- Add `spine.control.cycle` capability/surface.
- Extend `spine.control.execute` to support `agent_tool` route targets through governed task enqueue.
- Add strict health preflight evidence on delegated enqueue path.
- Include graph summary in `spine.control.tick` payload to strengthen control-loop context.
- Update governance/runtime docs for autonomous cycle contract.

## Verification Matrix

- `./bin/ops cap run spine.control.tick`
- `./bin/ops cap run spine.control.plan`
- `echo "yes" | ./bin/ops cap run spine.control.execute --action-id A90-route-discovery --allow-agent-tools --dry-run`
- `echo "yes" | ./bin/ops cap run spine.control.cycle --dry-run`
- `./bin/ops cap run verify.core.run`
- `./bin/ops cap run verify.pack.run aof`
- `./bin/ops cap run verify.pack.run loop_gap`
- `./bin/ops cap run spine.verify`

## Acceptance

- One cycle command can run a bounded autonomous observe-plan-act pass.
- Delegated `agent_tool` actions become governed queued tasks with route + health evidence.
- Control tick includes graph summary alongside timeline/loop/gap/proposal state.
