---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: spine-glue-v3-execution-spec
---

# SPINE Glue V3 Execution Spec

## Canonical Runtime

- Product intent: `/Users/ronnyworks/code/README.md`
- Runtime authority: `/Users/ronnyworks/code/agentic-spine`

## Loop Sequencing (Current)

1. `LOOP-SPINE-ROUTING-AND-DELEGATION-GLUE-V1-20260218` — closed
   - GAP-OP-669..673 fixed.
2. `LOOP-SPINE-OPERATING-GLUE-V1-20260220-20260221` — active
   - GAP-OP-674..677 registered for `spine.control.*` completion.

## Control-Loop Scope (Operating Glue)

- `spine.control.tick` (read-only)
- `spine.control.plan` (read-only)
- `spine.control.execute` (mutating/manual)
- Runtime-aware artifact:
  - `mailroom/outbox/operations/control-plane-latest.json`
  - `mailroom/outbox/operations/control-plane-latest.md`

## Routing/Delegation Dependency (Already Landed)

- Unified MCP gateway exposes:
  - `agent_list`, `agent_info`, `agent_tools`, `route_resolve`
- Deterministic route contract:
  - `./bin/ops cap run agent.route --json <input>`
- Gateway-first runtime contract parity:
  - `ops/bindings/mcp.runtime.contract.yaml`

## Verify Matrix

```bash
bash surfaces/verify/d116-mailroom-bridge-consumers-registry-lock.sh
./bin/ops cap run mcp.runtime.status
./bin/ops cap run verify.core.run
./bin/ops cap run verify.pack.run aof
./bin/ops cap run verify.pack.run loop_gap
./bin/ops cap run spine.verify
```
