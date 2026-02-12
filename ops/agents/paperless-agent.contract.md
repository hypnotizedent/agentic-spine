# paperless-agent Contract

> **Status:** superseded
> **Superseded-By:** finance-agent
> **Domain:** documents
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** paperless-agent
- **Domain:** documents (Paperless-ngx document management)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/paperless.json` (config-only)
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Document search/retrieval | Paperless-ngx API |
| Tag/correspondent management (future) | Paperless-ngx API |
| Receipt scanning workflow (future) | Paperless-ngx |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/services/paperless/` |

## Governed Tools

No custom tools in MCPJungle (config-only MCP server). All Paperless API access is read-only via configured MCP package.

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Paperless-ngx | docker-host (VM 200) | Finance stack |
