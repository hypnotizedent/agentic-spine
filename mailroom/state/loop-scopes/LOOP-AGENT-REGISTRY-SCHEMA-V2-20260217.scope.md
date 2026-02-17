---
loop_id: LOOP-AGENT-REGISTRY-SCHEMA-V2-20260217
status: active
owner: "@ronny"
priority: medium
created: 2026-02-17
parent_loop: LOOP-AOF-V1-1-SURFACE-ROLLDOWN-20260217
design_ref: docs/product/AOF_V1_1_SURFACE_UNIFICATION.md#move-2
---

# Move 2 — Queryable Agent Registry

## Objective

Extend `agents.registry.yaml` with machine-queryable fields (mcp_tools, capabilities,
write_scope, gates, endpoints) and add `agent.info` + `agent.tools` CLI capabilities.

## Deliverables

- [ ] Schema extension: add mcp_tools, capabilities, write_scope, gates, endpoints fields
- [ ] Populate fields for all 10 agents from existing .contract.md files
- [ ] `ops/plugins/agent/bin/agent-info` — query agent by ID
- [ ] `ops/plugins/agent/bin/agent-tools` — list tools for an agent
- [ ] `agent.info` capability registered
- [ ] `agent.tools` capability registered
- [ ] MCP gateway reads registry to expose per-agent tools (depends on Move 1)

## Target Files

| File | Action |
|------|--------|
| `ops/bindings/agents.registry.yaml` | modify (schema extension + data population) |
| `ops/plugins/agent/bin/agent-info` | create |
| `ops/plugins/agent/bin/agent-tools` | create |
| `ops/capabilities.yaml` | modify (register agent.info, agent.tools) |
| `ops/bindings/capability_map.yaml` | modify (add navigation entries) |

## Acceptance Criteria

1. `./bin/ops cap run agent.info finance-agent` returns structured data
2. `./bin/ops cap run agent.tools finance-agent` lists MCP tools
3. All 10 agent entries have populated mcp_tools/endpoints fields
4. Existing agent.route still works (backward compat)
5. All gates pass

## Constraints

- Additive fields only — no removal of existing schema fields
- .contract.md files become supplementary, not deleted
