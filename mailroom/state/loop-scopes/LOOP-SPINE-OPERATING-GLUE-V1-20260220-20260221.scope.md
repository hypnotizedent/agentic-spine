---
loop_id: LOOP-SPINE-OPERATING-GLUE-V1-20260220-20260221
created: 2026-02-21
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Build unified control loop surfaces (tick/plan/execute) with receipted runtime artifact output and deterministic routing targets.
---

# Loop Scope: LOOP-SPINE-OPERATING-GLUE-V1-20260220-20260221

## Objective

Build unified control loop surfaces (tick/plan/execute) with receipted runtime artifact output and deterministic routing targets.

## Context Artifact

- `docs/governance/SPINE_CONTROL_LOOP.md`

## Parent Gaps

- GAP-OP-674
- GAP-OP-675
- GAP-OP-676
- GAP-OP-677

## Locked Decisions

- `spine.control.tick` and `spine.control.plan` stay read-only.
- `spine.control.execute` is mutating/manual and only executes capability route targets.
- Manual target capabilities require explicit `--confirm`; otherwise return deterministic `manual_confirmation_required`.
- Control-plane artifacts are runtime-aware and written to `$SPINE_OUTBOX/operations/control-plane-latest.{json,md}`.

## Scope

- Add governed capability surfaces:
  - `spine.control.tick`
  - `spine.control.plan`
  - `spine.control.execute`
- Implement deterministic route-target plan envelope (`capability|agent_tool`).
- Implement action execution with run key + receipt extraction for executed items.
- Write canonical control-plane latest artifact contract.
- Extend runtime migration contract for `mailroom/outbox/operations`.
- Update governance docs to reflect shipped control loop.

## Out Of Scope

- Autonomous execution of `agent_tool` route targets.
- Direct mutation shortcuts outside `./bin/ops cap run`.
- Weekly cadence policy tuning implementation (follow-on loop).

## Verification Matrix

- `./bin/ops cap run spine.control.tick`
- `./bin/ops cap run spine.control.plan`
- `echo "yes" | ./bin/ops cap run spine.control.execute --action-id A01-loop-gap-verify`
- `bash surfaces/verify/d116-mailroom-bridge-consumers-registry-lock.sh`
- `./bin/ops cap run mcp.runtime.status`
- `./bin/ops cap run verify.core.run`
- `./bin/ops cap run verify.pack.run aof`
- `./bin/ops cap run verify.pack.run loop_gap`
- `./bin/ops cap run spine.verify`

## Acceptance

- One command provides current control-plane state (`spine.control.tick`).
- One command provides prioritized and routed next actions (`spine.control.plan`).
- One command executes selected approved actions with receipt linkage (`spine.control.execute`).
- Control-plane latest artifacts are emitted under runtime-aware outbox operations path.
