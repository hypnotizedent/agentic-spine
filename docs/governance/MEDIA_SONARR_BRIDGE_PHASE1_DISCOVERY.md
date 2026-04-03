# Sonarr Bridge Phase 1 — Discovery

Loop: `LOOP-MEDIA-SONARR-CLI-BRIDGE-20260323`
Date: 2026-03-30

## Current State

- Spine has `media.sonarr.metrics.today` and `media.sonarr.policy.parity` only
- No governed Sonarr operational bridge capabilities exist for search/get/history
- Workbench already implements `search_content` (type=tv), `get_show_details`, `get_episode_history`
- The media-agent bridge helper from Radarr phase 1 is reusable (already exports SONARR_URL)

## Seam

Thin read-only bridge scripts delegating to existing workbench tools via the landed bridge helper.

## Out of Scope

- request/remove/list
- Raw Sonarr API logic in spine
- Profile mutation
