# Media Radarr Bridge Phase 3 (Research) — Decision

## Proposed Model
One thin mutating bridge capability with preview/apply pattern.

## Capability ID
- `media.radarr.research` → `search_movie_by_id`

## Authority Boundaries
- `ops/capabilities.yaml` — new mutating capability
- `ops/bindings/routing.dispatch.yaml` — regenerated
- `ops/plugins/domains/media/bin/media-radarr-research` — new bridge script

## Next Action
Election for operator-approved mutating bridge.
