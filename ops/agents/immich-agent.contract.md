# immich-agent Contract

> **Status:** active
> **Domain:** photos
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-AGENT-MCP-SURFACE-BUILD-20260221

---

## Identity

- **Agent ID:** immich-agent
- **Domain:** photos (Immich photo/video management)
- **MCP Server:** `~/code/workbench/agents/immich/tools/mcp/`
- **MCPJungle Mirror:** `~/code/workbench/infra/compose/mcpjungle/servers/immich-photos/`
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
| Backup/restore | `~/code/workbench/docs/brain-lessons/IMMICH_BACKUP_RESTORE.md` |
| Operational lessons | `~/code/workbench/docs/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` |

## Governed Tools

| Tool | Safety | Notes |
|------|--------|-------|
| `photo__search_by_location` | read-only | GPS coordinate search |
| `photo__search_by_date_range` | read-only | Date range + camera filter |
| `photo__find_wrong_dates` | read-only | Suspicious date detection |
| `photo__create_album` | mutating | Creates album, adds assets |
| `photo__create_trip_album` | mutating | Search + create album |
| `photo__get_duplicates` | read-only | Perceptual hash groups, THE RULE keeper |
| `photo__trash_assets` | mutating | Default: dry_run=true, never force=true |
| `photo__fix_date` | mutating | Corrects dateTimeOriginal |
| `photo__get_cleanup_report` | read-only | Library stats + issues |
| `photo__get_camera_summary` | read-only | Stats by camera model |

## Invocation

On-demand via Claude Desktop MCP. No watchers, no cron.

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Immich | immich (VM 203) | 100.114.101.50:2283, 229K assets |
