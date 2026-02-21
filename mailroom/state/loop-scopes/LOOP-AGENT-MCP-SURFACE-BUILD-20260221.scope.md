# LOOP-AGENT-MCP-SURFACE-BUILD-20260221

## Status: closed
## Created: 2026-02-21
## Owner: SPINE-CONTROL-01

## Objective

Build and activate MCP server implementations for immich-photos and communications-agent. Both agents are registered in spine (agents.registry.yaml) but lack working MCP server code.

## Scope

1. **immich-photos MCP server** — Direct API access pattern (like finance-agent). 10 tools from SPEC.md at `~/code/workbench/agents/immich/tools/mcp/`.
2. **communications-agent MCP server** — Gateway pattern wrapping spine capabilities via subprocess. 12 tools covering all `communications.*` caps.
3. **Config surfaces** — Claude Desktop config, mcp.runtime.contract.yaml, agents.registry.yaml updates.
4. **Contract updates** — Both agent contracts status: registered -> active.

## Gaps

- GAP-OP-754: immich-photos MCP server not implemented
- GAP-OP-755: communications-agent workbench scaffold missing

## Deliverables

- [x] immich-photos MCP server built and responding to tools/list
- [x] communications-agent MCP server built and responding to tools/list
- [x] Claude Desktop config updated with both servers
- [x] agents.registry.yaml updated (status + mcp_tools)
- [x] Agent contracts updated (status: active)
- [x] mcp.runtime.contract.yaml updated
- [x] Both gaps closed (GAP-OP-754 fixed, GAP-OP-755 fixed)
- [x] Verification suite passes (core 7/7, stability WARN only immich ingest pre-existing)
