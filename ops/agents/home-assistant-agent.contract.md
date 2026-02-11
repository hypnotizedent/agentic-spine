# home-assistant-agent Contract

> **Status:** registered
> **Domain:** home-automation
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** home-assistant-agent
- **Domain:** home-automation (Home Assistant configuration, automations, device management)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/home-assistant/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Automation management | Home Assistant |
| Device/entity state queries | Home Assistant |
| Service calls (blocked — requires spine capability) | Home Assistant |
| Dashboard configuration | Home Assistant |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| SSOT auto-grade | `ha.ssot.propose` / `ha.ssot.apply` capabilities |
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/vm-home/home-assistant/` |
| Backups | `backup.*` capabilities |

## Governed Tools

| Tool | Status | Spine Capability |
|------|--------|-----------------|
| ha_call_service | BLOCKED (P2) | None — explicit deny pending spine architecture review |

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Home Assistant | proxmox-home VM 100 | Local only (no public tunnel) |
