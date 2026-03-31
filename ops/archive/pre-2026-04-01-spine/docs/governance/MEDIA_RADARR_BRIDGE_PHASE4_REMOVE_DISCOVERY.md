# Media Radarr Bridge Phase 4 (Remove) — Discovery

## Truthful Seam
- Phases 1-3 landed read-only, request, and research Radarr bridge surfaces
- Workbench has no canonical `remove_movie` tool yet
- `bulk_library_action` establishes canonical delete semantics: deleteFiles=false, addImportExclusion=true
- Workbench mutating tools remain governance-blocked for ad hoc callers

## Out of Scope
- List/profile operations
- Sonarr/Lidarr/Jellyfin bridge
- Weakening workbench governance gate

## Open Questions
None — delete semantics already established by `bulk_library_action`.
