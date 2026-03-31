# Media Radarr Bridge Phase 4 (Remove) — Decision

## Proposed Model
One canonical workbench tool + one governed destructive spine bridge with preview/apply pattern.

## Tool / Capability IDs
- Workbench: `remove_movie` (new canonical tool)
- Spine: `media.radarr.remove` → `remove_movie`

## Authority Boundaries
- Workbench: `agents/media/tools/src/index.ts` — new tool + governance gate update
- Spine: `ops/capabilities.yaml`, `routing.dispatch.yaml`, `media-radarr-remove` script

## Next Action
Election for operator-approved destructive bridge.
