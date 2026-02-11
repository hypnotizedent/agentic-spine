# immich-agent Contract

> **Status:** registered
> **Domain:** photos
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211

---

## Identity

- **Agent ID:** immich-agent
- **Domain:** photos (Immich photo/video management)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/immich-photos/`
- **Registry:** `ops/bindings/agents.registry.yaml`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Photo/video search | Immich API |
| Album management | Immich API |
| Asset metadata queries | Immich API |
| Deduplication governance (THE RULE) | Immich |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `/spine/services/immich/` |
| Backup/restore | `docs/brain/lessons/IMMICH_BACKUP_RESTORE.md` |
| Operational lessons | `docs/brain/lessons/IMMICH_OPERATIONS_LESSONS.md` |

## Governed Tools

No mutating tools blocked (MCP server is read-only). All Immich API access through configured MCP package.

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Immich | immich (VM 203) | 192.168.1.203, 135K assets/3TB |
