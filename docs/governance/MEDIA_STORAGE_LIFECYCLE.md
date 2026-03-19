---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-18
scope: media-storage-lifecycle-contract
---

# MEDIA STORAGE LIFECYCLE

Purpose: remove ambiguity about where media belongs and stop `/downloads` from becoming a forever-home.

## Canonical Decision

- Home is the hot watch plane.
- Home may also hold the warm/current library.
- Shop / 730XD is cold archive capacity.
- 730XD is not the primary family playback surface.
- Downloads are staging only, never permanent residence.

## Tier Model

### Hot
- Purpose: current-watch UX, low-friction playback, family-facing library.
- Canonical authority: `synology918`
- Canonical roots:
  - `/volume1/media-holds/tv`
  - `/volume1/media-holds/movies`
  - `/volume1/media-holds/music`
- Runtime note: `media-home` VM 106 is the current home media/watch compute surface tied to this plane.

### Warm
- Purpose: import buffer, metadata cleanup, rehydration landing zone, current-but-not-yet-archived library.
- Canonical authority: `synology918`
- Canonical roots:
  - `/volume1/media-staging/tv`
  - `/volume1/media-staging/movies`
  - `/volume1/media-staging/music`

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
- Staging: `download-stack:/downloads/tv`
- Hot/current library: `synology918:/volume1/media-holds/tv`
- Warm/rehydration: `synology918:/volume1/media-staging/tv`
- Cold archive: `pve:/md1400/archive/media/tv`

### Movies
- Staging: `download-stack:/downloads/movies`
- Hot/current library: `synology918:/volume1/media-holds/movies`
- Warm/rehydration: `synology918:/volume1/media-staging/movies`
- Cold archive: `pve:/md1400/archive/media/movies`

### Music
- Staging: `download-stack:/downloads/music`
- Hot/current library: `synology918:/volume1/media-holds/music`
- Warm/rehydration: `synology918:/volume1/media-staging/music`
- Cold archive: `pve:/md1400/archive/media/music`

## Lifecycle Rules

### 1. Ingest
- New payload lands in a downloads staging path only.
- Download tooling may sort and enrich metadata, but it does not own long-term residence.
- If a file still lives under `/downloads` after import/archive review, that is drift.

### 2. Import
- Staging payload is normalized into the Synology warm lane.
- This is where renames, metadata cleanup, duplicate review, and "is this worth keeping?" decisions happen.

### 3. Home Library Placement
- Items meant to be readily watchable/playable move into the home hot library.
- Current-watch UX remains home-first even if the shop has more raw capacity.

### 4. Watched-State Archival
- Once a title becomes cold, duplicate, or low-likelihood for immediate replay, it may be copied to 730XD cold archive.
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

## Current Transitional Reality (2026-03-18)

- `media-home` VM 106 is live on `proxmox-home`, consumes Synology media-staging, and has daily Synology backup artifacts.
- `download-stack` and `streaming-stack` still mount shop `/media` from the 730XD side.
- `streaming-stack` is not currently a reliable playback authority because the VM is up but the declared Docker stack is empty.
- Cold archive path normalization on 730XD is not complete yet. The target contract is `/md1400/archive/media/*`, and current runtime/storage layout should be treated as transitional until migration closes.

## Operator Standard

When asked "where is it?", the answer should be one sentence:

- "It is in downloads staging."
- "It is in the home library."
- "It is in home staging."
- "It is in 730XD cold archive."

Anything fuzzier than that is contract drift.
