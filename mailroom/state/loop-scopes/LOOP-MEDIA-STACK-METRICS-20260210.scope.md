---
status: active
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

## Notes

- Metrics collection is independent of VM 201 decommission (Radarr is already on VM 209).
- Current blocker: `RADARR_API_KEY` is not present in Infisical injection (`/spine/vm-infra/media-stack/download`).

## Evidence (Receipts)
- Failed run (missing `RADARR_API_KEY`): `receipts/sessions/RCAP-20260210-090929__media.metrics.today__R4y5m31176/receipt.md`
