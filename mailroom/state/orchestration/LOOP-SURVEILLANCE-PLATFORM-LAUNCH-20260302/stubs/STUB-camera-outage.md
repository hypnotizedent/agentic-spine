---
stub_id: STUB-camera-outage
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: resolved
status: cleared
created: "2026-03-04"
cleared_at: "2026-03-05"
cleared_by: "WAVE-SURVEILLANCE-VM-E2E-EXEC-20260305"
owner: "@ronny"
depends_on: LOOP-CAMERA-OUTAGE-20260209
---

# STUB: Camera Outage Resolution

## Resolution

The 2026-02-09 outage (0/12 channels showing video after NVR power cycle) has
self-resolved. As of 2026-03-05 ISAPI channel status query confirms **8/12
channels online** — matching the pre-outage baseline.

- ch1 (FRONT DRIVE): online
- ch2-5 (ALLY WAY, OFFICE, IPCamera 04/05): offline (pre-existing physical issue, GAP-OP-031)
- ch6-12: online

## Evidence

- ISAPI channel status query via PVE SSH (2026-03-05): 8/12 online
- NVR ping: 0% packet loss, 0.2ms avg RTT
- NVR HTTP: 200 OK
- NVR firmware: V4.30.216 (matches CAMERA_SSOT)
- CAMERA_SSOT.md updated with 2026-03-05 status

## Remaining

- Channels 2-5 remain offline (physical PoE/cabling — GAP-OP-031, separate loop)
- Physical location survey still pending for all channels
