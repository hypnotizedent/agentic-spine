---
loop_id: LOOP-BRIDGE-CALENDAR-RPC-20260302
status: planned
created_at: "2026-03-02"
owner: "@ronny"
severity: medium
parent_loop: null
related_gaps:
  - GAP-OP-1336
---

# Loop Scope: Bridge Calendar RPC Enablement

## Objective

Enable bridge calendar capabilities for Radicale CalDAV operations so mobile/remote
operators can manage spine calendar events via the governed bridge API.

## Background

The spine has a comprehensive calendar system:
- **Provider:** Radicale (CalDAV) on communications-stack (VM 214)
- **Capabilities:** calendar.home.event.{create,list,get,update,delete}
- **Bridge:** Has /calendar/feed and /calendar/today (read-only HTTP)

**Gap:** No Cap-RPC access to calendar event operations. Remote operators cannot
create, update, or delete calendar events through the bridge.

## Scope

### In Scope
1. Add calendar.home.event.* capabilities to bridge Cap-RPC allowlist
2. Update mailroom.bridge.consumers.yaml
3. Run mailroom-bridge-consumers-sync
4. Restart bridge to pick up changes
5. Verify calendar operations work via POST /cap/run

### Out of Scope
- Creating new calendar capabilities (they already exist)
- Adding /calendar HTTP endpoint for event CRUD (use Cap-RPC instead)
- Adding calendar.calendars.list capability (future enhancement)
- Non-operator role calendar access (not needed for MVP)

## Implementation Plan

### Phase 1: Allowlist Update
- [ ] Update `ops/bindings/mailroom.bridge.consumers.yaml`
  - Add to `cap_rpc.allowlist`:
    - calendar.home.event.create
    - calendar.home.event.list
    - calendar.home.event.get
    - calendar.home.event.update
    - calendar.home.event.delete
- [ ] Run `bash ops/plugins/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
- [ ] Verify sync updated `ops/bindings/mailroom.bridge.yaml`

### Phase 2: Bridge Restart
- [ ] Run `./bin/ops cap run mailroom.bridge.stop`
- [ ] Run `./bin/ops cap run mailroom.bridge.start`
- [ ] Verify bridge health: `GET /health`

### Phase 3: Verification
- [ ] Test calendar.home.event.list via Cap-RPC:
  ```bash
  curl -X POST https://spine.ronny.works/cap/run \
    -H "CF-Access-Client-Id: $CF_ID" \
    -H "CF-Access-Client-Secret: $CF_SECRET" \
    -H "Content-Type: application/json" \
    -d '{"capability": "calendar.home.event.list", "args": []}'
  ```
- [ ] Test calendar.home.event.create via Cap-RPC (requires confirm):
  ```bash
  curl -X POST https://spine.ronny.works/cap/run \
    -H "CF-Access-Client-Id: $CF_ID" \
    -H "CF-Access-Client-Secret: $CF_SECRET" \
    -H "Content-Type: application/json" \
    -d '{
      "capability": "calendar.home.event.create",
      "args": ["--summary", "Test event", "--start", "2026-03-03T10:00:00", "--end", "2026-03-03T11:00:00"],
      "confirm": true
    }'
  ```

### Phase 4: Gap Closure
- [ ] Run `gaps.close --id GAP-OP-1336 --status fixed --fixed-in LOOP-BRIDGE-CALENDAR-RPC-20260302`

## Dependencies
- Bridge must be running (mailroom.bridge.status)
- CF Access service token configured
- Radicale accessible from comms VM

## Risks
- Calendar mutation caps require manual approval → bridge RPC must send `confirm: true`
- If Radicale is down, calendar ops will fail gracefully (capability handles error)

## Acceptance Criteria
- [ ] POST /cap/run with calendar.home.event.list returns events
- [ ] POST /cap/run with calendar.home.event.create creates event (with confirm)
- [ ] POST /cap/run with calendar.home.event.get retrieves event
- [ ] POST /cap/run with calendar.home.event.update modifies event (with confirm)
- [ ] POST /cap/run with calendar.home.event.delete removes event (with confirm)
- [ ] Receipt generated for each operation
- [ ] GAP-OP-1336 closed

## Files Changed
- ops/bindings/mailroom.bridge.consumers.yaml (allowlist additions)
- ops/bindings/mailroom.bridge.yaml (synced from consumers)
- ops/bindings/operational.gaps.yaml (gap registration/closure)

## Notes
- Consider adding monitor role read-only calendar access in future
- Consider calendar.calendars.list capability for multi-collection support
