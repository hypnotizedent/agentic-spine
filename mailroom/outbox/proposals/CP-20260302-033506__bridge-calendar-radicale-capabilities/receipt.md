# Proposal Receipt: CP-20260302-033506__bridge-calendar-radicale-capabilities

## What was done
- Analyzed spine bridge architecture and calendar capabilities
- Confirmed calendar.home.event.* capabilities exist for Radicale operations
- Identified gap: bridge Cap-RPC allowlist lacks calendar capabilities
- Created loop scope for implementation work
- Drafted GAP-OP-1336 entry for operational.gaps.yaml
- Proposed changes to mailroom.bridge.consumers.yaml

## Why
- Operator (via bridge/mobile) attempted to add an event to the agentic spine calendar
- Bridge has /calendar/feed and /calendar/today (read-only) but no event manipulation
- Calendar capabilities exist but are not exposed via Cap-RPC allowlist
- Calendar management via bridge is a missing operator workflow

## Gap Analysis

### Current State
- **Bridge HTTP endpoints:** `/calendar/feed`, `/calendar/today` (read-only ICS/JSON)
- **Cap-RPC allowlist:** No calendar.* capabilities
- **Existing capabilities:**
  - `calendar.home.event.create` - Create Radicale events
  - `calendar.home.event.list` - List events with date range
  - `calendar.home.event.get` - Get event by UID
  - `calendar.home.event.update` - Update event (merge-patch)
  - `calendar.home.event.delete` - Delete event by UID

### Missing
- Calendar capabilities in bridge Cap-RPC allowlist
- Optional: `calendar.calendars.list` to list available calendar collections

### Proposed Changes
1. Add to `mailroom.bridge.consumers.yaml` allowlist:
   ```yaml
   - calendar.home.event.create
   - calendar.home.event.list
   - calendar.home.event.get
   - calendar.home.event.update
   - calendar.home.event.delete
   ```
2. Operator role already has `"allow": "*"` - no role changes needed
3. Monitor role could optionally get read-only calendar access

## Architecture Notes

### Calendar Infrastructure
- **Provider:** Radicale (CalDAV server)
- **Location:** comms VM (communications-stack, VM 214)
- **Co-located with:** Stalwart (mail server)
- **Access:** Internal network, auth via Radicale admin credentials (Infisical)

### Bridge Auth Pattern (Already Established)
- CF Access service-token at edge → JWT injection
- Bridge validates JWT `aud` claim
- CF-authenticated requests get operator-level RBAC

### Security Considerations
- All calendar mutations go through governed capabilities
- `calendar.home.event.create/update/delete` are `approval: manual` caps
- Bridge Cap-RPC enforces manual confirmation via `confirm: true`
- Auth chain: CF Access → bridge token → capability receipt

## Expected Outcomes
When applied:
- GAP-OP-1336 registered in operational.gaps.yaml
- Loop scope created for tracking implementation
- Bridge gains calendar event manipulation via Cap-RPC
- Operator can create/update/delete calendar events from mobile/remote

## Evidence
- ops/capabilities.yaml confirms calendar.home.event.* capabilities exist
- ops/bindings/mailroom.bridge.yaml shows current allowlist (no calendar)
- ops/bindings/calendar.home.contract.yaml defines Radicale connection
- mailroom.bridge.consumers.yaml is SSOT for Cap-RPC allowlist

## Files to Apply
1. `files/GAP-OP-1336.yaml` → append to `ops/bindings/operational.gaps.yaml`
2. `files/LOOP-BRIDGE-CALENDAR-RPC-20260302.scope.md` → `mailroom/state/loop-scopes/`
3. `files/mailroom.bridge.consumers.yaml` → `ops/bindings/`

## Next Steps
1. Apply proposal via `proposals.apply`
2. Run `mailroom-bridge-consumers-sync` to update bridge binding
3. Restart bridge: `mailroom.bridge.stop` → `mailroom.bridge.start`
4. Verify: `POST /cap/run` with calendar.home.event.list
5. Close gap with `gaps.close --id GAP-OP-1336`
