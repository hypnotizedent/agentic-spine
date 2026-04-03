# Sonarr Bridge Phase 1 — Decision

Loop: `LOOP-MEDIA-SONARR-CLI-BRIDGE-20260323`
Date: 2026-03-30

## Model

Three thin read-only bridge capabilities:
- `media.sonarr.search` → `search_content` (type=tv)
- `media.sonarr.get` → `get_show_details`
- `media.sonarr.history` → `get_episode_history`

All delegate through the existing `media-agent-bridge.sh` helper.

## Authority Boundaries

- Spine owns capability registration, routing, and CLI wrapper
- Workbench owns canonical tool implementation and API interaction
- Bridge helper owns MCP JSON-RPC transport and governance context
