---
loop_id: LOOP-SPINE-ROUTING-AND-DELEGATION-GLUE-V1-20260218
created: 2026-02-18
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Close routing and delegation glue gaps via gateway-first parity, governed Cap-RPC task lifecycle, deterministic route JSON contract, orchestration dependency and health enforcement, and runtime/doc parity.
---

# Loop Scope: LOOP-SPINE-ROUTING-AND-DELEGATION-GLUE-V1-20260218

## Objective

Close routing and delegation glue gaps via gateway-first parity, governed Cap-RPC task lifecycle, deterministic route JSON contract, orchestration dependency and health enforcement, and runtime/doc parity.

## Context Artifact

- `docs/governance/_audits/SPINE_AUTONOMOUS_ORCHESTRATION_GAP_AUDIT_20260218.md`

## Parent Gaps

- GAP-OP-669
- GAP-OP-670
- GAP-OP-671
- GAP-OP-672
- GAP-OP-673

## Locked Decisions

- `/cap/run` accepts `confirm=true`; manual capabilities require explicit confirm and forward `yes\n`.
- `mailroom.task.*` capabilities are `approval: auto` and gated by strict Cap-RPC RBAC.
- Cap-RPC SSOT edit order is `mailroom.bridge.consumers.yaml` then consumers sync.
- Gateway-first cutover is two checkpoints: enable first, then flip required contract.
- `agent.route --json` contract ships before MCP `route_resolve`.
- Orchestration dependency logic is centralized in `_orchestration-common`.
- Task runtime state is externalized under `$SPINE_STATE/agent-tasks/...`.

## Scope

- Implement Cap-RPC confirm behavior for manual capability invocation and deterministic error path when missing confirm.
- Add governed task lifecycle capabilities:
  - `mailroom.task.enqueue`
  - `mailroom.task.claim`
  - `mailroom.task.heartbeat`
  - `mailroom.task.complete`
  - `mailroom.task.fail`
- Extend consumers SSOT allowlist and role scoping for task execution actors.
- Add `agent.route --json` stable envelope and wire MCP tools:
  - `agent_list`
  - `agent_info`
  - `agent_tools`
  - `route_resolve`
- Complete gateway-first parity across Codex, Claude Desktop, and OpenCode in two checkpoints.
- Extend orchestration manifest schema with dependency and routing metadata.
- Enforce dependency satisfaction through shared orchestration helpers.
- Add `agent.health.check-all` and use it in task claim preflight.
- Update runtime migration contract for `mailroom/state/agent-tasks`.
- Reconcile governance docs with shipped MCP gateway and agent registry reality.

## Out Of Scope

- Direct `/tasks/*` mutation endpoints.
- Parallel standalone DAG storage outside orchestration manifest SSOT.
- Incident work from unrelated loops.

## Execution Pack

1. Baseline
   - `./bin/ops status`
   - `./bin/ops cap run stability.control.snapshot`
   - `./bin/ops cap run verify.route.recommend`
2. Cap-RPC governance path
   - Update `ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve`
   - Update `ops/capabilities.yaml` for `mailroom.task.*`
   - Update `ops/bindings/mailroom.bridge.consumers.yaml`
   - Run `bash ops/plugins/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
3. Routing contract then MCP tooling
   - Extend `ops/plugins/agent/bin/agent-route` with `--json`
   - Extend `ops/plugins/mcp-gateway/bin/spine-mcp-serve` tools
4. Gateway-first parity checkpoint A then B
   - Checkpoint A: enable `spine` in `.claude.json` and `opencode.json`, keep contract required unchanged
   - Checkpoint B: update `ops/bindings/mcp.runtime.contract.yaml` required servers to `spine` for `claude_desktop` and `opencode`
5. Orchestration dependency extension
   - Update `ops/plugins/orchestration/manifest.schema.yaml`
   - Extend `ops/plugins/orchestration/bin/_orchestration-common`
   - Update `ops/plugins/orchestration/bin/orchestration-handoff-validate`
   - Update `ops/plugins/orchestration/bin/orchestration-integrate`
   - Add `agent.health.check-all` and claim preflight usage
6. Runtime path and docs parity
   - Update `ops/bindings/mailroom.runtime.contract.yaml`
   - Update `docs/governance/AGENTS_GOVERNANCE.md`
   - Update `docs/governance/MAILROOM_BRIDGE.md`

## Verification Matrix

- `./bin/ops cap run mcp.runtime.status`
- `bash surfaces/verify/d116-mailroom-bridge-consumers-registry-lock.sh`
- `./bin/ops cap run verify.core.run`
- `./bin/ops cap run verify.pack.run aof`
- `./bin/ops cap run verify.pack.run loop_gap`
- `./bin/ops cap run spine.verify`

## Acceptance

- Cap-RPC manual approval path works only with explicit `confirm=true`.
- Task lifecycle works through governed capabilities without interactive deadlock.
- Consumers SSOT remains authoritative and synced with no auto-block drift.
- Route JSON envelope is stable and consumed by MCP `route_resolve`.
- Dependency enforcement is shared-helper driven.
- Task state is externalized under `$SPINE_STATE`.
- Governance docs no longer claim MCP bridge is planned-only.
