---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-20
scope: media-storage-lifecycle-contract
---

# MEDIA STORAGE LIFECYCLE

Purpose: remove ambiguity about where media belongs and stop `/downloads` from becoming a forever-home.

## Canonical Decision

- Home is the active watch plane.
- Home is also the active current library and intake plane.
- Shop / 730XD is cold archive capacity.
- 730XD is not the primary family playback surface.
- Downloads are staging only, never permanent residence.
- Current live Synology share truth is smaller than the old naming sprawl: `/volume1/media-staging` is the only populated/exported media share currently consumed by `media-home` VM 106, `/volume1/media-holds` is the explicit hold/review lane, and no separate `/volume1/media-home` share exists today.
- Shop `/media/*` may still exist as transitional writer or transfer residue, but it is not canonical active placement truth.

## Tier Model

### Hot
- Purpose: current-watch UX, low-friction playback, family-facing library.
- Canonical authority: `synology918`
- Current live share state: the hot plane currently rides the active `/volume1/media-staging/*` tree.
- Runtime note: `media-home` VM 106 is live and serves the current home plane from `/volume1/media-staging/*`.

### Warm
- Purpose: import buffer, metadata cleanup, rehydration landing zone, and the active library path used by home today.
- Canonical authority: `synology918`
- Canonical roots:
  - `/volume1/media-staging/tv`
  - `/volume1/media-staging/movies`
  - `/volume1/media-staging/music`
  - `/volume1/media-staging/downloads`

### Hold / Review
- Purpose: explicit hold lane for manual-import review, duplicate review, forensic holds, and overflow that should not look like the primary library.
- Canonical authority: `synology918`
- Canonical roots:
  - `/volume1/media-holds/manual-import-review`
  - `/volume1/media-holds/duplicate-review`
  - `/volume1/media-holds/forensic-holds`

### Cold
- Purpose: long-retention archive and capacity relief.
- Canonical authority: `pve` / `md1400`
- Target roots:
  - `/md1400/archive/media/tv`
  - `/md1400/archive/media/movies`
  - `/md1400/archive/media/music`
- Rule: cold archive is retrievable but not the default watch surface.

## Canonical Placement by Media Type

### TV
- Staging: `synology918:/volume1/media-staging/downloads`
- Current live home-watch lane: `synology918:/volume1/media-staging/tv`
- Warm/rehydration: `synology918:/volume1/media-staging/tv`
- Cold archive: `pve:/md1400/archive/media/tv`

### Movies
- Staging: `synology918:/volume1/media-staging/downloads`
- Current live home-watch lane: `synology918:/volume1/media-staging/movies`
- Warm/rehydration: `synology918:/volume1/media-staging/movies`
- Cold archive: `pve:/md1400/archive/media/movies`

### Music
- Staging: `synology918:/volume1/media-staging/downloads`
- Current live home-watch lane: `synology918:/volume1/media-staging/music`
- Warm/rehydration: `synology918:/volume1/media-staging/music`
- Cold archive: `pve:/md1400/archive/media/music`

## Lifecycle Rules

### 1. Ingest
- New payload lands in a downloads staging path only.
- Download tooling may sort and enrich metadata, but it does not own long-term residence.
- If a file still lives under `/downloads` after import/archive review, that is drift.
- Canonical intake is the home plane. Shop-side download paths are transitional residue until home writer cutover finishes.

### 2. Import
- Staging payload is normalized into the Synology warm lane.
- This is where renames, metadata cleanup, duplicate review, and "is this worth keeping?" decisions happen.

### 3. Home Library Placement
- Items meant to be readily watchable/playable stay on the home Synology plane.
- There is no dedicated `/volume1/media-home` share today. The current live share path is `/volume1/media-staging/*`.
- Current-watch UX remains home-first even if the shop has more raw capacity.

### 4. Watched-State Archival
- Once a title becomes cold, duplicate, or low-likelihood for immediate replay, it may be copied from home to 730XD cold archive.
- Archive status must be explicit; the home copy may be pruned later for capacity relief.

### 5. Retrieval / Rehydration
- Retrieval runs cold -> warm -> hot, never cold -> "serve directly as the new normal".
- Rehydrated titles land on Synology warm first, then graduate back into the hot library if needed.

## Anti-Patterns

- `/downloads` as permanent residence
- Shop-first playback for normal family watch flow
- Mixed library/archive folders with no tier meaning
- Config and payload sharing the same ambiguous root
- "I think it lives on the 730XD somewhere" as an operating model

## Current Transitional Reality (2026-03-20)

- `media-home` VM 106 is live on `proxmox-home`, consumes Synology media-staging, and has daily Synology backup artifacts.
- `/volume1/media-home`, `/volume1/media`, `/volume1/hot-media`, `/volume1/live-library`, and `/volume1/library-home` are empty ghost placeholder directories, not active media shares.
- `media-holds` is an explicit hold/review share, not a populated home library.
- Shop split runtime still exists as transitional residue:
  - `download-stack` remains a residual writer/import surface.
  - `streaming-stack` is no longer the declared playback authority.
- Cold archive path normalization on 730XD is not fully closed yet. The target contract remains `/md1400/archive/media/*`.
- **Registry alignment (2026-03-19)**: `service.data.lifecycle.registry.yaml` previously listed `nas:/volume1/media-staging` under `drift_rules.retired_roots`. This was the only governance document treating the path as retired; all other contracts (this file, `MEDIA_STORAGE_CONTRACT.md`, tier model, canonical placements) already describe it as the active warm/home share. The registry has been corrected to classify this path as an `allowed_secondary_root`.

## Operator Standard

When asked "where is it?", the answer should be one sentence:

- "It is in downloads staging."
- "It is in the home library."
- "It is in home staging."
- "It is in 730XD cold archive."

Anything fuzzier than that is contract drift.
