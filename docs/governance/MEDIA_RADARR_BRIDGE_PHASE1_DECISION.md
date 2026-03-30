# Media Radarr Bridge Phase 1 — Decision

## Proposed Model
Thin spine bridge capabilities delegating to existing workbench media-agent MCP tools via stdio JSON-RPC.

## Capability IDs
- `media.radarr.search` → `search_content` (type=movie)
- `media.radarr.get` → `get_movie_details`
- `media.radarr.history` → `get_movie_history`

## Authority Boundaries
- `ops/capabilities.yaml` — new capability entries
- `ops/bindings/routing.dispatch.yaml` — regenerated
- `ops/plugins/domains/media/bin/` — new bridge scripts
- `ops/plugins/domains/media/lib/` — new bridge helper

## Next Action
Election for operator-approved implementation.
