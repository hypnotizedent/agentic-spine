# Sonarr Bridge Phase 2 — Decision

Loop: `LOOP-MEDIA-SONARR-CLI-BRIDGE-20260323`
Date: 2026-03-30

## Model

One thin mutating bridge capability:
- `media.sonarr.request` → `request_show`
- Default: preview (no mutation)
- `--apply` required for live mutation
- Governance gate: `request_show` pointer changed from null to `"media.sonarr.request"`

## Authority Boundaries

- Spine owns preview/apply semantics and CLI wrapper
- Workbench owns canonical `request_show` implementation
- Governed bypass reuses exact Radarr pattern (SPINE_GOVERNED_BRIDGE=1 + non-null cap pointer)
