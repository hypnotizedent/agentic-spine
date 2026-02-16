---
loop_id: LOOP-OFFICE-BUTTON-ONBOARDING-20260215
status: closed
created: 2026-02-15
closed: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-497  # ha.automation.create capability — CLOSED
  - GAP-OP-498  # Office button automation — CLOSED (pre-satisfied)
  - GAP-OP-499  # Office button device registry commit — CLOSED
  - GAP-OP-500  # ha.device.rename + BILRESA renamed via WS API — CLOSED
  - GAP-OP-501  # HA_API_TOKEN naming + namespace — CLOSED
---

# LOOP: Office Button Onboarding (CLOSED)

## Objective

Onboard the IKEA BILRESA dual button (Matter device) as `office-button` in the spine,
create the `ha.automation.create` capability, and wire button_1 to toggle `light.office_desk_bulb`.

## Results — 5/5 gaps closed

- GAP-OP-497: `ha.automation.create` capability — REST POST /api/config/automation/config/{id} (e442baa)
- GAP-OP-498: `automation.office_button_desk` pre-existed in HA
- GAP-OP-499: `office-button` registered in device registry with ha_entities + controls (d30e5da)
- GAP-OP-500: `ha.device.rename` capability — WebSocket config/device_registry/update (010d2fe)
  - BILRESA renamed to "Office Button" via CLI (no manual HA UI needed)
  - Key discovery: HA device/entity registry is WebSocket-only, not REST
- GAP-OP-501: TOKEN→HA_TOKEN consistency + HA_API_TOKEN in namespace policy (014685c)

## Bonus deliverables
- IoT naming convention in naming.policy.yaml + D117 gate (7689d17)
- HA API token rotated in Infisical (works via LAN, Tailscale on HA down)
- 32 HA capabilities total (18 read-only, 14 mutating), 276 total spine caps
