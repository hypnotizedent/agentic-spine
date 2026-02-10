---
status: rolled-into-parent
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-MEDIA-STACK-METRICS-20260210
---

# Loop Scope: LOOP-MEDIA-STACK-METRICS-20260210

## Goal
Make the media stack measurable from the spine with receipts: daily counts for
"movies pulled today" (and optionally TV episodes) without ad-hoc SSH/log
digging.

## Success Criteria
- A read-only spine capability reports "movies pulled today" using Radarr history.
- Output includes: date window, count, and a short sample of titles (bounded).
- Uses governed secrets injection (no API key leaks).
- Receipted run can be triggered from terminal and later from n8n.

## Phases
- P0: Confirm Radarr/Sonarr endpoints + secret key names in Infisical
- P1: Implement `media.metrics.today` (radarr first) + docs
- P2: Optional: add `sonarr` episode metrics
- P3: Optional: n8n workflow to post daily summary to inbox/outbox

## Rolled Into: LOOP-MEDIA-STACK-SPLIT-20260208

Media stack metrics work becomes a post-decommission phase of the media stack split
loop (LOOP-MEDIA-STACK-SPLIT-20260208). Metrics collection depends on the split
being fully soaked and VM 201 decommissioned, so it naturally belongs as a follow-on
phase rather than a standalone loop.

---

## Evidence (Receipts)
- (link receipts here)

