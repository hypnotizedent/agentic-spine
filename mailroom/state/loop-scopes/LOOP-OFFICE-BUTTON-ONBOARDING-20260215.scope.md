---
loop_id: LOOP-OFFICE-BUTTON-ONBOARDING-20260215
status: open
created: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-497  # ha.automation.create capability — CLOSED
  - GAP-OP-498  # Office button automation — CLOSED (pre-satisfied)
  - GAP-OP-499  # Office button device registry commit — CLOSED
  - GAP-OP-500  # HA device map refresh after rename — OPEN (manual step pending)
  - GAP-OP-501  # HA_API_TOKEN naming + namespace — CLOSED
---

# LOOP: Office Button Onboarding

## Objective

Onboard the IKEA BILRESA dual button (Matter device) as `office-button` in the spine,
create the `ha.automation.create` capability, and wire button_1 to toggle `light.office_desk_bulb`.

## Progress

- GAP-OP-497: **CLOSED** — `ha.automation.create` capability built + tested (e442baa)
- GAP-OP-498: **CLOSED** — `automation.office_button_desk` already exists in HA (pre-satisfied)
- GAP-OP-499: **CLOSED** — office-button registered in device registry (d30e5da)
- GAP-OP-500: **OPEN** — manual step: rename "BILRESA dual button" → "Office Button" in HA UI, then run `ha.device.map.build`
- GAP-OP-501: **CLOSED** — TOKEN→HA_TOKEN in 4 scripts + HA_API_TOKEN in namespace policy (014685c)

## Bonus: HA API token rotated
- New long-lived token stored in Infisical `home-assistant/prod/HA_API_TOKEN`
- Token works via LAN (10.0.0.100) — Tailscale IP (100.67.120.1) returning 403 (TS agent on HA may be down)

## Remaining

1. Rename BILRESA → "Office Button" in HA Settings → Devices (manual)
2. Run `./bin/ops cap run ha.device.map.build` to refresh device map
3. Close GAP-OP-500 and this loop
