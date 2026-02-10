---
status: closed
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
- P0: Extract backup schedules from SSOT/bindings into a single structured source — DONE
  (`ops/bindings/backup.calendar.yaml` — 5 events: vzdump daily, vaultwarden, infisical,
  gitea, offsite sync)
- P1: Generate ICS (backup events + reminders) — DONE
  (`ops/plugins/backup/bin/backup-calendar-generate`, capability `backup.calendar.generate`)
- P2: Publish/subscription path for iPhone — DEFERRED
  (ICS file at `mailroom/outbox/backup-calendar/backup-calendar.ics`; manual AirDrop/share for now.
  Plan documented in `docs/governance/BACKUP_CALENDAR.md`. Future: serve via Caddy or Mailroom bridge for webcal:// subscription.)
- P3: Closeout with receipts + SSOT updates — DONE

## Evidence (Receipts)
- `RCAP-20260210-093643__backup.calendar.generate__Rpwtp71956` — first ICS generation
- `RCAP-20260210-094136__backup.calendar.generate__Rul6f83550` — generates `mailroom/outbox/backup-calendar/backup-calendar.ics`

## Closure Note (2026-02-10)

P0-P1 complete: binding defines 5 daily backup events, capability generates valid
ICS with VTIMEZONE, RRULE DAILY, and VALARM 15-min reminders. Output is deterministic
(same binding = same ICS). P2 deferred — file can be manually shared now; webcal://
subscription via Caddy or the Mailroom bridge is a future enhancement.

## Deferred / Follow-ups
- Publish ICS via Caddy on infra-core for iPhone webcal:// subscription
- Add home-location backup events when home infra is in scope
