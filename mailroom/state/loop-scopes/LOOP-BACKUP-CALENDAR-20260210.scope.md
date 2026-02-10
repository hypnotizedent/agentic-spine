---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-BACKUP-CALENDAR-20260210
---

# Loop Scope: LOOP-BACKUP-CALENDAR-20260210

## Goal
Generate a canonical calendar view of backup cadence across machines (shop/home)
so the schedule is visible from iPhone and auditable from the spine.

## Success Criteria
- A spine capability generates an `.ics` calendar from SSOT/bindings.
- Calendar includes: vzdump schedule, NAS backups, key maintenance windows (if declared).
- Output is deterministic and stored in a governed sink (mailroom/outbox).
- Hosting/subscription plan is documented (Tailscale, reverse proxy, or file share).

## Phases
- P0: Extract backup schedules from SSOT/bindings into a single structured source
- P1: Generate ICS (backup events + reminders)
- P2: Publish/subscription path for iPhone (documented)
- P3: Closeout with receipts + SSOT updates

## Evidence (Receipts)
- (link receipts here)

