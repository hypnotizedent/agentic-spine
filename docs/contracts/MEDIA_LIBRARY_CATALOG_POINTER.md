# Media Library Catalog — Thin Pointer

> **This is a pointer, not the authority.**
> The canonical media library catalog is owned by the workbench media-agent.

## Canonical Location

| Field | Value |
|-------|-------|
| **Owner** | `media-agent` |
| **Repo** | `~/code/workbench` |
| **Path** | `agents/media/data/MEDIA_LIBRARY_CATALOG.yaml` |
| **Lineage journal** | `agents/media/data/MEDIA_LIBRARY_LINEAGE.yaml` |
| **Schema** | `agents/media/data/catalog-schema.yaml` |
| **Lifecycle model** | `agents/media/data/lifecycle-model.yaml` |
| **Refresh tool** | `agents/media/tools/catalog-reconcile.py` |
| **Version** | 2.0 |
| **Created** | 2026-03-22 |

## What It Contains

- TV, movie, and music catalog entries sourced from Sonarr, Radarr, Lidarr
- Lifecycle states across request, ingest, import, library, client, archive, and retention
- A separate lineage journal preserving incidents, recoveries, rehomes, and gaps
- Known gaps with recovery prospects
- SABnzbd queue state at refresh time

## Refresh

```bash
cd ~/code/workbench
python3 agents/media/tools/catalog-reconcile.py --refresh
python3 agents/media/tools/catalog-reconcile.py --validate
```

## Boundary

- Spine does NOT own the catalog data model or content.
- Spine does NOT own the lineage journal or reconcile engine.
- Spine may reference the catalog location for governance checks.
- No duplicate catalog surface in spine.
