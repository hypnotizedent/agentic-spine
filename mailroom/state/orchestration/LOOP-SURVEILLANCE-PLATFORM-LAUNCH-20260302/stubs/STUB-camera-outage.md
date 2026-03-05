---
stub_id: STUB-camera-outage
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: blocked_physical
status: parked
created: "2026-03-04"
owner: "@ronny"
depends_on: LOOP-CAMERA-OUTAGE-20260209
---

# STUB: Camera Outage Resolution

## What is blocked

All 12 NVR channels are dark since 2026-02-09. Frigate cannot ingest streams
until at least the 8 previously-online channels are restored.

## Evidence

- CAMERA_SSOT.md: 0/12 channels showing live video (2026-02-09)
- ISAPI query (2026-02-08): 8 channels online, 4 offline
- NVR web UI (2026-02-09): 0 feeds rendering after power cycle + DHCP fix
- GAP-OP-031: ch2-4 offline (notExist) — physical PoE switch issue

## Required Operator Action

1. Physical visit to shop upstairs 9U rack
2. Check Netgear PoE switch power and uplink to NVR
3. Verify camera power LEDs on PoE switch
4. Try NVR web UI from shop LAN workstation (browser plugin may be needed)
5. Re-run ISAPI channel detect query
6. Update CAMERA_SSOT.md with results

## Next Action Owner

@ronny (requires physical shop visit)

## ETA

Depends on physical visit scheduling — no remote resolution possible.
