---
stub_id: STUB-ha-integration
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: blocked_runtime_access
status: parked
created: "2026-03-04"
owner: "@ronny"
depends_on:
  - STUB-vm-provision
  - STUB-camera-outage
---

# STUB: Home HA Frigate Integration

## What is blocked

Cannot integrate Frigate with home HA until:
1. Surveillance VM is provisioned and Frigate is running
2. Camera feeds are live (camera outage resolved)
3. MQTT broker (Mosquitto) is configured in home HA

## Required Operator Action

1. Install Mosquitto add-on in home HA (if not already present)
2. Install Frigate integration via HACS in home HA
3. Configure Frigate MQTT connection to home HA broker
4. Verify events flow from Frigate to HA
5. Create baseline automations (person detection after hours)
6. Add Frigate card to HA dashboard

## Evidence

- ha.surveillance.status capability created and registered
- go2rtc integration already loaded in home HA (entry 01JGW6HWCQJNEQBV0F7AQJH3HE)
- Capability will report PENDING_SETUP until integration is configured

## Next Action Owner

@ronny (after STUB-vm-provision and STUB-camera-outage clear)

## ETA

After VM provisioning and camera outage resolution.
