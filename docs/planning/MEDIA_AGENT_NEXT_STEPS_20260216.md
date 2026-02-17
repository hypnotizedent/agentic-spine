# Media Agent — Next Steps (2026-02-16)

> Focused analysis of the media-agent's current state and highest-leverage next moves.
> Proposal: CP-20260216-190040__media-agent-next-steps-20260216

---

## Where Things Stand

The media-agent has two homes with a clear boundary between them:

### Spine (control plane — `ops/agents/media-agent.contract.md`)

The spine owns infrastructure-layer media capabilities. These already exist and work:

| Capability | What it does |
|-----------|--------------|
| `media.status` | Unified dashboard: VM status, service counts, NFS, storage |
| `media.health.check` | Aggregate health across VM 209 + 210 |
| `media.service.status` | Container status mapped to service binding |
| `media.nfs.verify` | NFS mount health: RW/RO modes, free space |
| `media.metrics.today` | Radarr import count for the day |
| `media.stack.restart` | Docker compose restart (dry-run default) |
| `media.backup.create` | Config volume snapshots, 7-day retention |

Gate profile: D16, D17, D106, D107, D124, D126 + shared gates.

### Workbench (application layer — `agents/media/`)

This is the media-agent's real home. What shipped today:

**Already built (pre-today):**
- Full MCP server (`tools/src/index.ts`) — 30+ tools covering:
  - Radarr/Sonarr/Lidarr: search, request, profiles, custom formats, history
  - Jellyfin: libraries, recent activity, DB audit, bulk actions
  - SABnzbd: queue management (both stacks)
  - Jellyseerr: pending requests, approval
  - Bazarr: missing subtitles
  - Navidrome: stats
  - Prowlarr: indexer status
  - Huntarr: status/toggle
  - Recyclarr: sync status
  - Spine bridge: infra health, service status, NFS verify (delegates to spine caps)
- 3 playbooks: `wrong-language`, `missing-subtitles`, `library-hygiene`
- Config: `recyclarr.yml`
- Test: `api-connectivity.sh`

**Shipped today:**
- `docs/BOUNDARY.md` — media app-layer belongs in workbench, spine is control plane
- `docs/INDEX.md` — doc surface index
- `docs/RUNBOOK.md` — stub (empty)
- `docs/CAPABILITIES.md` — generated catalog of 8 spine-side media caps
- `docs/notes/` — impact note from today's session
- Brain-lessons absorbed: `MEDIA_CRITICAL_RULES.md`, `MEDIA_DOWNLOAD_ARCHITECTURE.md`, `MEDIA_PIPELINE_ARCHITECTURE.md`, `MEDIA_RECOVERY_RUNBOOK.md`, `MEDIA_STACK_LESSONS.md`

---

## The Gap: What's Missing

The media-agent MCP server has 30+ tools implemented but the surrounding structure has holes:

### 1. Runbook is empty

`agents/media/docs/RUNBOOK.md` is a stub. The playbooks exist (`wrong-language`, `missing-subtitles`, `library-hygiene`) but there's no operator runbook that ties them together — no "media-agent crashed, here's how to recover" or "new service added, here's the checklist."

### 2. Capability catalog mismatch

`docs/CAPABILITIES.md` only lists the 8 **spine-side** capabilities. The 30+ MCP tools in `tools/src/index.ts` are not cataloged anywhere. An operator looking at the catalog would think media-agent can only do infrastructure probes — they'd miss the Radarr search, Jellyfin audit, subtitle check, and everything else the agent actually does.

### 3. No MCP tool tests

`tests/api-connectivity.sh` checks if services are reachable. But there are no tests for the MCP tools themselves — no smoke test that verifies the tools register correctly, handle missing API keys gracefully, or return expected shapes.

### 4. Secrets not in Infisical

The MCP server reads from `.env` (10+ API keys). The spine pattern is Infisical-backed secrets. These media API keys aren't inventoried in `ops/bindings/secrets.inventory.yaml` or stored in Infisical — they're local `.env` only.

### 5. MCPJungle mirror not wired

The agent registry says `mcpjungle_mirror: "~/code/workbench/infra/compose/mcpjungle/servers/media-stack/"` but this needs to actually work for Claude Mobile / remote clients to use media tools.

---

## Prioritized Next Steps

### P0 — Catalog the real tools (1 hour)

Generate a workbench-side capability catalog that lists all 30+ MCP tools, not just the spine infra caps. This is the single highest-leverage move because it makes the agent discoverable.

**Deliverable:** Update `agents/media/docs/CAPABILITIES.md` to include both spine caps AND MCP tools in a unified catalog.

### P1 — Write the operator runbook (1 session)

Fill `agents/media/docs/RUNBOOK.md` with:
- How to start the MCP server locally
- How to run the connectivity test
- Common failure modes and recovery
- How to add a new media service to the agent
- How findings get routed back to spine mailroom

### P2 — Inventory secrets in Infisical (1 session)

Register all 10+ media API keys in `ops/bindings/secrets.inventory.yaml` and store them in Infisical under `infrastructure/prod/MEDIA_*`. Update the MCP server to optionally pull from Infisical via `infisical-agent.sh` instead of bare `.env`.

### P3 — MCP tool smoke tests (1 session)

Add a test that:
- Starts the MCP server
- Lists tools (verifies all 30+ register)
- Calls a read-only tool with missing API key (verifies graceful error)
- Calls `get_system_status` against live endpoints (integration)

### P4 — Wire MCPJungle (1 session)

Ensure the `mcpjungle` gateway config at `infra/compose/mcpjungle/servers/media-stack.json` actually routes to the media MCP server, so Claude Mobile and remote clients can use media tools.

---

## Decision Points

1. **P0 catalog format:** Should the MCP tool catalog be in the same `CAPABILITIES.md` file alongside spine caps, or a separate `MCP_TOOLS.md`?
2. **Secrets migration priority:** Is Infisical migration (P2) worth doing now, or is `.env` fine until the agent is used more?
3. **MCPJungle scope:** Should all 30+ tools be exposed remotely, or only the read-only subset?
