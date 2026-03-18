---
title: Home Media Residue Decision Table
status: generated
generated_from: ops/bindings/home.media.residue.inventory.yaml
generated_at: 2026-03-18
---

# Home Media Residue Decision Table

## Reset Baseline

- Capture date: `2026-03-18`
- Share: `proxmox-home:/mnt/media` -> `synology918:/volume1/media-staging`
- Media runtime state: `media-home` intentionally paused, `0` running containers
- Share usage: `9.50 TB used`, `11.59 TB free`, `46% used`

## What This Means

The service move succeeded, but the data lifecycle did not. The current problem is not active downloading. The problem is that transit lanes survived as retained storage.

Current split:

- Live movie library: `1` title
- Live TV library: `7` series
- Live music library: `34` artists
- Transit residue:
  - `downloads/incomplete`: `291`
  - `downloads/complete/tv`: `148`
  - `downloads/complete/movies`: `514`
  - `downloads/complete/music`: `445`

That is the opposite of boring. The library is small and the transit lanes are large.

## Lane Decisions

| Lane | Current State | Why It Is Not Boring | Default Decision | Allowed Exception |
|------|---------------|----------------------|------------------|-------------------|
| `downloads/incomplete` | `291` items; mostly `2026-01-02` residue plus `2026-03-17/18` active TV backlog | active and stale payload are mixed together | `purge` | explicitly wanted active-now titles may finish and import |
| `downloads/complete/tv` | `148` items; mostly fresh `2026-03-17` backlog | completed-download transit is acting like storage | `import or delete` | only shows in the explicitly kept TV library |
| `downloads/complete/movies` | `514` items; clustered on `2026-01-03` to `2026-01-08` | movie transit has become long-term storage residue | `delete` | explicit keeper titles may be imported into the library first |
| `downloads/complete/music` | `445` items; heavily clustered on `2026-01-03` with older residue | music transit is also acting like retained storage | `delete` | explicitly wanted artists or albums only, imported into library first |
| `movies` | `1` imported title | this is the actual home movie truth | `protect` | none |
| `tv` | `7` imported series | this is the actual home TV truth | `protect` | none |
| `music` | `34` imported artists | this is the actual home music truth | `protect` | none |

## Key Observations

- `downloads/complete/movies` is not "500 movies downloaded today." It is older residue, mostly from `2026-01-03` through `2026-01-08`.
- `downloads/complete/tv` is much fresher. Most of it landed on `2026-03-17`, with a few items still landing on `2026-03-18` before the stack was stopped.
- `downloads/incomplete` is the messiest lane. It contains recent TV backlog and much older mixed media residue together.
- The current live library is much smaller than the transit backlog. That is the core boringness failure.

## Why The Old 99% Problem Happened

The old shop-side `99%` pressure came from lifecycle failure, not just insufficient disks:

- auto-grab expanded faster than real watch intent
- completed downloads were not drained
- archive and runtime meanings overlapped
- cleanup decisions were deferred, so transit became storage

The current home residue is the same pattern in a new location.

## Boring Reset Sequence

1. Keep `media-home` paused.
2. Treat `downloads/complete/movies` as delete-by-default residue.
3. Reduce `downloads/complete/tv` to an explicit kept show set before Sonarr is allowed back on.
4. Decide whether music is active or historical; until then, keep the music helper lane off.
5. Use `media.data.readiness.verify` as the restart gate, and only restart the minimum services after the transit lanes are near-zero and the keep set is explicit.

## Immediate Guardrails

- Do not restart the full media stack yet.
- Do not let `downloads/complete/*` continue acting as storage.
- Do not re-enable Radarr monitoring.
- Do not cold-promote directly from inbox residue in the normal path.
- If Sonarr comes back later, it must come back against an explicit kept-TV scope, not the previous broad missing backlog.
