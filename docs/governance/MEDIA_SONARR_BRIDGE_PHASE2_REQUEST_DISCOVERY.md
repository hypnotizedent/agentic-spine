# Sonarr Bridge Phase 2 — Discovery

Loop: `LOOP-MEDIA-SONARR-CLI-BRIDGE-20260323`
Date: 2026-03-30

## Current State

- Phase 1 landed search/get/history read-only bridge surfaces
- Workbench already implements `request_show` (tvdbId, qualityProfileId, POST /series)
- Spine has no governed Sonarr add/request surface
- Workbench governance gate blocks ad hoc `request_show` (currently null pointer)

## Seam

Thin mutating bridge with preview/apply pattern, delegating to existing `request_show` tool.
Narrow governed bypass in workbench gate (same pattern as `request_movie`).

## Out of Scope

- remove/list/profile mutation
- Broad mutating bypass
