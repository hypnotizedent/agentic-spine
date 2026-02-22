# Calendar Surface Audit

- Generated: 2026-02-21T04:05:59Z
- Capability: calendar.surface.audit
- Status: PASS
- Checks Passed: 52
- Checks Failed: 0

## Scope
- Calendar SSOT contracts (global/sync/schema/backup)
- Calendar + Graph + Backup capability matrix
- AOF control-plane calendar integration surfaces
- Generated artifacts and planner/runtime checks

## Failures
- none

## Passed Checks
- capability contract ok: calendar.generate
- capability contract ok: calendar.status
- capability contract ok: calendar.sync.plan
- capability contract ok: calendar.sync.execute
- capability contract ok: graph.calendar.list
- capability contract ok: graph.calendar.get
- capability contract ok: graph.calendar.create
- capability contract ok: graph.calendar.update
- capability contract ok: graph.calendar.rsvp
- capability contract ok: backup.calendar.generate
- capability contract ok: spine.briefing
- capability contract ok: spine.control.tick
- capability contract ok: spine.control.plan
- capability contract ok: spine.control.execute
- capability contract ok: spine.control.cycle
- calendar.global binding present
- calendar.global schema present
- calendar sync contract present
- backup calendar binding present
- calendar.global layers.order canonical
- calendar sync provider is ms-graph
- calendar sync approval is manual
- calendar sync spine-authoritative writes enabled
- calendar sync identity writes disabled
- calendar sync personal writes disabled
- calendar generate capability executable
- calendar status capability executable
- calendar sync planner executable
- calendar sync executor executable
- backup calendar generator executable
- briefing calendar section executable
- AOF spine-control runtime executable
- calendar test present: ops/plugins/calendar/tests/test-calendar-generate.sh
- calendar test present: ops/plugins/calendar/tests/test-calendar-status.sh
- calendar test present: ops/plugins/calendar/tests/test-calendar-sync-plan.sh
- calendar test present: ops/plugins/calendar/tests/test-calendar-sync-execute.sh
- calendar.generate execution pass
- backup.calendar.generate execution pass
- calendar.status reports OK
- calendar.sync.plan execution pass
- spine.control.tick execution pass
- spine.control.plan execution pass
- calendar index has events (count=6)
- calendar index covers expected layer set
- artifact present: mailroom/outbox/calendar/calendar-global.ics
- artifact present: mailroom/outbox/calendar/calendar-infrastructure.ics
- artifact present: mailroom/outbox/calendar/calendar-automation.ics
- artifact present: mailroom/outbox/calendar/calendar-identity.ics
- artifact present: mailroom/outbox/calendar/calendar-personal.ics
- artifact present: mailroom/outbox/calendar/calendar-spine.ics
- artifact present: mailroom/outbox/calendar/calendar-life.ics
- artifact present: mailroom/outbox/backup-calendar/backup-calendar.ics
