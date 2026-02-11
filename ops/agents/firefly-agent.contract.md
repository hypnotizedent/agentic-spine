# firefly-agent Contract

> **Status:** registered
> **Domain:** finance
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** firefly-agent
- **Domain:** finance (Firefly III personal finance management)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/firefly.json` (config-only)
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Transaction queries | Firefly III API |
| Account/budget views | Firefly III API |
| Import rule management (future) | Firefly III API |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/services/finance/` |
| Operational runbooks | `docs/pillars/finance/` |

## Governed Tools

No custom tools in MCPJungle (config-only MCP server). All Firefly III API access is read-only via configured MCP package.

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Firefly III | docker-host (VM 200) | Finance stack |
