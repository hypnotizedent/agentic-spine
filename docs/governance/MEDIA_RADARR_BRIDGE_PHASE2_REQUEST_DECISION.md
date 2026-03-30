# Media Radarr Bridge Phase 2 (Request) — Decision

## Proposed Model
One thin mutating bridge capability with preview/apply pattern.

## Capability ID
- `media.radarr.request` → `request_movie`

## Authority Boundaries
- `ops/capabilities.yaml` — new mutating capability
- `ops/bindings/routing.dispatch.yaml` — regenerated
- `ops/plugins/domains/media/bin/media-radarr-request` — new bridge script

## Next Action
Election for operator-approved mutating bridge.
