# Media Radarr Bridge Phase 1 — Discovery

## Truthful Seam
- Spine has zero governed Radarr bridge capabilities
- Workbench media-agent already implements read-only movie tools: `search_content`, `get_movie_details`, `get_movie_history`
- Media-agent MCP server is declared in `agents.registry.yaml` and `mcp.runtime.contract.yaml`
- Current mailroom `agent_tool` path only supports `route_resolve`, not real tool execution

## Out of Scope
- Mutating operations (request/remove)
- Sonarr/Lidarr/Jellyfin bridge surfaces
- Generic MCP client framework redesign
- Mailroom agent_tool architecture changes

## Open Questions
None — workbench tool surface is confirmed and callable.
