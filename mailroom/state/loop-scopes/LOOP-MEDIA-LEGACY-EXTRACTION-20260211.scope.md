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

## Extraction Matrix (P1)

| Legacy artifact | Proposed disposition | Target surface | Notes |
|---|---|---|---|
| `REF_CRITICAL_RULES.md` | extract | spine-native governance/runbook doc | High-signal safety rules; rewrite only |
| `REF_DOWNLOAD_ARCHITECTURE.md` | extract | spine-native architecture section | Shop/home download model needs canonical summary |
| `REF_MEDIA_PIPELINE.md` | extract | spine-native pipeline overview | Large doc; extract only operational core flows |
| `REF_HOME_DOWNLOADER.md` | defer | backup/home docs after validation | Depends on current home LXC reality |
| `REF_SECRETS.md` | extract (sanitized) | namespace/key-path reference only | No secret values; key-path mapping only |
| `REF_QUALITY_PROFILES.md` | defer | workbench media agent docs | Recyclarr already authoritative in config |
| `RUNBOOK_RECOVER.md` | extract | governed DR/media recovery runbook | Needs adaptation to VM 209/210 split |
| `RUNBOOK_TDARR.md` | defer | media troubleshooting docs | Only if Tdarr remains active in current stack |
| `RUNBOOK_JELLYFIN_BUFFERING.md` | defer | media troubleshooting docs | Only if recurring incident class is current |
| `RUNBOOK_INTRO_SKIPPER.md` | defer | media feature runbook | Optional capability, not control-plane critical |
| `scripts/trickplay-guard.sh` | defer (Move B candidate) | capability wrapper only | Promote only if still needed operationally |
| `config/kometa/*` | defer/reject pending service check | media config authority | Promote only if Kometa active now |
| `config/janitorr/application.yml` | defer/reject pending service check | media config authority | Promote only if Janitorr active now |
| `config/recyclarr/recyclarr.yml` | superseded | none | Already covered: `workbench/agents/media/config/recyclarr.yml` |

## Success Criteria

- A single spine-governed extraction matrix exists for all media legacy candidates with one disposition per item: `extract`, `defer`, `reject`, or `superseded`.
- Critical operational rules and recovery logic are rewritten into spine-native docs (not pasted).
- Any script/config promoted is wrapped behind governed capability or binding with receipts.
- Legacy source references are tracked as read-only provenance only.
- Loop closes with explicit list of promoted outputs + rejected outputs.

## Phases

- P0: COMPLETE -- Register loop + gap and verify source commit/path inventory.
- P1: IN PROGRESS -- Build extraction matrix and assign dispositions for each candidate item.
- P2: PENDING -- Promote high-priority docs (critical rules, download architecture, media pipeline, recovery) as rewritten spine-native docs.
- P3: PENDING -- Decide/implement script-level promotions (`trickplay-guard`, Kometa/Janitorr) only if services are active.
- P4: PENDING -- Validate (`spine.verify`) and close with receipt-linked summary.

## Notes

- `RUNBOOK_INTRO_SKIPPER.md`, `RUNBOOK_TDARR.md`, `RUNBOOK_JELLYFIN_BUFFERING.md`, Kometa, and Janitorr are conditional on active service ownership in current topology (VM 209/210).
- `REF_SECRETS.md` must not be promoted as values; only key-path governance can be promoted.
- This loop is the canonical anti-sprawl intake for media legacy content; no parallel ad-hoc migration outside this scope.
