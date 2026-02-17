---
loop_id: LOOP-SPINE-MCP-GATEWAY-V1-20260217
status: closed
owner: "@ronny"
priority: high
created: 2026-02-17
parent_loop: LOOP-AOF-V1-1-SURFACE-ROLLDOWN-20260217
design_ref: docs/product/AOF_V1_1_SURFACE_UNIFICATION.md#move-1
---

# Move 1 — Unified Spine-MCP Gateway

## Objective

Build a single MCP server that wraps the capability registry as MCP tools, replacing
per-surface MCP configurations with one `./bin/ops mcp serve` entry point.

## Deliverables

- [ ] `ops/plugins/mcp-gateway/bin/spine-mcp-serve` — Python3 MCP stdio server
- [ ] `bin/ops mcp serve` CLI subcommand routing
- [ ] `spine.mcp.serve` capability registered in capabilities.yaml + capability_map.yaml
- [ ] RAG MCP tools absorbed (rag_query, rag_retrieve, rag_health)
- [ ] Finance-agent MCP tools delegated via cap_run
- [ ] Single-line config validated in Claude Code
- [ ] Existing caps still callable via `./bin/ops cap run` (backward compat)

## Target Files

| File | Action |
|------|--------|
| `ops/plugins/mcp-gateway/bin/spine-mcp-serve` | create |
| `bin/ops` | modify (add mcp serve routing) |
| `ops/capabilities.yaml` | modify (register spine.mcp.serve) |
| `ops/bindings/capability_map.yaml` | modify (add navigation entry) |

## Acceptance Criteria

1. `./bin/ops mcp serve` starts and completes MCP handshake
2. `cap_list` tool returns capability inventory via MCP
3. `cap_run` tool executes read-only caps and returns output
4. All Core-8 + AOF domain gates pass after merge

## Constraints

- Python3 stdlib only (no pip dependencies)
- Same MCP stdio pattern as existing `rag-mcp-server`
- Safety model enforced: read-only=auto, mutating/destructive=same as CLI
