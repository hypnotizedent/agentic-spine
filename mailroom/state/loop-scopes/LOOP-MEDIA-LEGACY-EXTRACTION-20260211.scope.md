---
status: active
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-MEDIA-LEGACY-EXTRACTION-20260211
severity: high
---

# Loop Scope: LOOP-MEDIA-LEGACY-EXTRACTION-20260211

## Goal

Recover high-signal media-stack operational knowledge from legacy `ronny-ops` without importing stale runtime patterns, and promote only spine-compatible outputs.

## Problem / Current State (2026-02-11)

- Legacy local path `~/ronny-ops` was intentionally removed by `LOOP-HOME-DIR-CLEANUP-20260210` (D30 compliance).
- Source still exists remotely: `https://github.com/hypnotizedent/ronny-ops.git` at commit `1ea9dfa91f4cf5afbd56a1a946f0a733d3bd785c`.
- Media operational docs/scripts are missing from spine in a governed form, causing repeated ad-hoc resurfacing and confusion.

## Extraction Contract (No Garbage Import)

- Follow `docs/core/EXTRACTION_PROTOCOL.md`:
  - Move A first (doc-only snapshot and rewrite).
  - Move B only for small, clean, governed wrappers.
- No direct runtime dependency on `ronny-ops`.
- No blind copy/paste of legacy markdown or scripts.
- Every promoted artifact must include:
  - owner
  - authority/scope
  - verification method
  - receipts for validation (`spine.verify`, plus capability receipts where applicable)

## Candidate Inventory (Verified in remote source)

Source root: `ronny-ops/media-stack/`

- `docs/reference/REF_CRITICAL_RULES.md`
- `docs/reference/REF_DOWNLOAD_ARCHITECTURE.md`
- `docs/reference/REF_MEDIA_PIPELINE.md`
- `docs/reference/REF_HOME_DOWNLOADER.md`
- `docs/reference/REF_SECRETS.md`
- `docs/reference/REF_QUALITY_PROFILES.md`
- `docs/runbooks/RUNBOOK_RECOVER.md`
- `docs/runbooks/RUNBOOK_TDARR.md`
- `docs/runbooks/RUNBOOK_JELLYFIN_BUFFERING.md`
- `docs/runbooks/RUNBOOK_INTRO_SKIPPER.md`
- `scripts/trickplay-guard.sh`
- `config/kometa/config.yml`
- `config/kometa/collections/trending.yml`
- `config/janitorr/application.yml`
- `config/recyclarr/recyclarr.yml` (already covered in workbench)

## Extraction Matrix (Final)

| Legacy artifact | Disposition | Target surface | Notes |
|---|---|---|---|
| `REF_CRITICAL_RULES.md` | **extracted** | `docs/brain/lessons/MEDIA_CRITICAL_RULES.md` | P2: rewritten spine-native |
| `REF_DOWNLOAD_ARCHITECTURE.md` | **extracted** | `docs/brain/lessons/MEDIA_DOWNLOAD_ARCHITECTURE.md` | P2: rewritten spine-native |
| `REF_MEDIA_PIPELINE.md` | **extracted** | `docs/brain/lessons/MEDIA_PIPELINE_ARCHITECTURE.md` | P2: rewritten spine-native |
| `RUNBOOK_RECOVER.md` | **extracted** | `docs/brain/lessons/MEDIA_RECOVERY_RUNBOOK.md` | P2: adapted to VM 209/210 split |
| `REF_SECRETS.md` | **superseded** | `ops/bindings/secrets.namespace.policy.yaml` | Key-path mappings already governed (lines 35-48) |
| `REF_QUALITY_PROFILES.md` | **superseded** | `workbench/agents/media/config/recyclarr.yml` | Recyclarr config is authoritative |
| `config/recyclarr/recyclarr.yml` | **superseded** | `workbench/agents/media/config/recyclarr.yml` | Already covered |
| `config/kometa/*` | **reject/deprecated** | none | Kometa not present on any VM (2026-02-11 service check) |
| `config/janitorr/application.yml` | **reject/deprecated** | none | Janitorr not present on any VM (2026-02-11 service check) |
| `RUNBOOK_TDARR.md` | **reject** | none | Tdarr deliberately stopped (RCA quick-win); no restart planned |
| `scripts/trickplay-guard.sh` | **reject** | none | No trickplay activity on VM 210; NFS I/O root cause resolved by VM split |
| `RUNBOOK_JELLYFIN_BUFFERING.md` | **reject** | none | Root cause (SQLite on NFS) resolved; `MEDIA_STACK_LESSONS.md` covers fix |
| `REF_HOME_DOWNLOADER.md` | **defer** | future home media docs | Depends on home LXC reality; `download-home` is optional target |
| `RUNBOOK_INTRO_SKIPPER.md` | **defer** | future troubleshooting doc | Intro-skipper plugin active (DB exists) but runbook is low-priority |

## Success Criteria

- A single spine-governed extraction matrix exists for all media legacy candidates with one disposition per item: `extract`, `defer`, `reject`, or `superseded`.
- Critical operational rules and recovery logic are rewritten into spine-native docs (not pasted).
- Any script/config promoted is wrapped behind governed capability or binding with receipts.
- Legacy source references are tracked as read-only provenance only.
- Loop closes with explicit list of promoted outputs + rejected outputs.

## Phases

- P0: COMPLETE -- Register loop + gap and verify source commit/path inventory.
- P1: COMPLETE -- Build extraction matrix and assign dispositions for each candidate item.
- P2: COMPLETE -- Promote high-priority docs: 4 spine-native rewrites in `docs/brain/lessons/MEDIA_*.md` (commit 0774811; D60 wording fix in a6503cb).
- P3: COMPLETE -- Service checks resolved all pending dispositions: 5 rejected (Tdarr/Kometa/Janitorr/trickplay/buffering), 3 superseded, 2 remain deferred (home downloader, intro-skipper — non-blocking for close).
- P4: IN PROGRESS -- Validate (`spine.verify`) and close with receipt-linked summary.

## P3 Service Check Evidence (2026-02-11)

Receipt: `RCAP-20260211-100942__docker.compose.status__Roakh40137`

Live container inventory captured via `sudo docker ps` on VM 209/210:

**VM 209 (download-stack) — 19 running, 5 stopped:**
- Running: autopulse, crosswatch, crowdsec, decypharr, flaresolverr, lidarr, node-exporter, posterizarr, prowlarr, qbittorrent, radarr, recyclarr, sabnzbd, sonarr, soularr, swaparr-radarr, trailarr, unpackerr, watchtower
- Stopped: huntarr, slskd, swaparr-lidarr, swaparr-sonarr, **tdarr** (deliberately stopped per RCA quick-win)
- **Not present:** Kometa, Janitorr

**VM 210 (streaming-stack) — 10 running, 0 stopped:**
- Running: bazarr, homarr, jellyfin, jellyseerr, navidrome, node-exporter, spotisub, subgen, watchtower, wizarr
- Intro-skipper: Jellyfin plugin active (DB at `/opt/appdata/jellyfin/introskipper/introskipper.db`)
- Trickplay: no directories or config found
- **Not present:** Kometa, Janitorr

## Notes

- This loop is the canonical anti-sprawl intake for media legacy content; no parallel ad-hoc migration outside this scope.
- 2 items remain deferred: `REF_HOME_DOWNLOADER.md` (home LXC dependent) and `RUNBOOK_INTRO_SKIPPER.md` (active but low-priority). These can be picked up in future loops if needed.
