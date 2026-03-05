---
stub_id: STUB-ha-integration
loop_id: LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302
blocker_class: blocked_operator
status: parked
created: "2026-03-04"
updated_at: "2026-03-05"
owner: "@ronny"
depends_on:
  - STUB-vm-provision
  - STUB-camera-outage
---

# STUB: Home HA Frigate Integration

## Current State

Prerequisites cleared:
- Frigate 0.17.0 running on VM 215 with 8 cameras at 5 fps (CPU detector)
- MQTT enabled in Frigate config (pointing to home HA 10.0.0.100:1883)
- Mosquitto broker already installed in home HA (confirmed via API)
- Camera outage resolved (8/12 channels online)

## What Remains (operator UI actions only)

1. **Install Frigate integration via HACS** in home HA
   - HA UI: HACS > Integrations > search "Frigate" > Download
   - Restart HA after install
2. **Add Frigate integration** in HA
   - Settings > Devices & Services > Add Integration > Frigate
   - Frigate URL: `http://192.168.1.215:5000`
3. **Verify entities appear** in HA (camera.front_drive, etc.)
4. **Optional**: Create baseline automation (person detection after hours)
5. **Optional**: Add Frigate dashboard card

## Evidence

- Frigate API version: `0.17.0-f0d69f7` (confirmed via API)
- Frigate health: healthy (docker healthcheck passing)
- 8 cameras streaming at 5 fps each
- MQTT config: `host: 10.0.0.100, port: 1883, topic_prefix: frigate, client_id: frigate-shop`
- Mosquitto in HA: `update.mosquitto_broker_update` entity present
- HA API: reachable (HTTP 200)

## Next Action Owner

@ronny (requires HA web UI for HACS install)
