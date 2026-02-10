---
status: draft
owner: "@ronny"
last_verified: 2026-02-10
scope: backup-calendar
---

# Backup Calendar (.ics)

Goal: make backup cadence visible and subscribable (iPhone) without SSH or digging
through cron/jobs on each host.

## Generate (Spine Capability)

```bash
./bin/ops cap run backup.calendar.generate
```

Output path (governed sink):

- `mailroom/outbox/backup-calendar/backup-calendar.ics`

Schedule source of truth:

- `ops/bindings/backup.calendar.yaml`

## Subscribe (Plan)

The `.ics` must be reachable over HTTPS from the iPhone. The spine does not yet
ship a calendar server.

Recommended plan:

1. **Tailnet-only**: serve the file over Tailscale on a trusted node (no public internet).
2. **Long-term**: expose the ICS from the Mailroom bridge as `GET /backup-calendar.ics`
   with explicit auth (tracked under `LOOP-MAILROOM-MCP-BRIDGE-20260210`).

## Safety Notes

- The calendar should contain schedules only (no secrets).
- Do not expose publicly without an auth boundary (Tailscale ACLs, token, or both).

