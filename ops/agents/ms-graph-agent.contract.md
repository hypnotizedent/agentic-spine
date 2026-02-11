# ms-graph-agent Contract

> **Status:** registered
> **Domain:** identity
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** ms-graph-agent
- **Domain:** identity (Microsoft Graph API — email, calendar, identity)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/microsoft-graph.json` (config-only)
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Email search/read | MS Graph API |
| Calendar queries | MS Graph API |
| Identity/profile lookups | MS Graph API |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Secrets (OAuth tokens) | Infisical `/spine/services/microsoft-graph/` |

## Governed Tools

No custom tools in MCPJungle (config-only MCP server). All MS Graph access is read-only via configured MCP package.

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Microsoft Graph API | graph.microsoft.com | Cloud service (no VM) |
