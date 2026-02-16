---
loop_id: LOOP-OFFICE-BUTTON-ONBOARDING-20260215
status: open
created: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-497  # ha.automation.create capability
  - GAP-OP-498  # Office button automation (BILRESA → office desk bulb)
  - GAP-OP-499  # Office button device registry commit
  - GAP-OP-500  # HA device map refresh after rename
---

# LOOP: Office Button Onboarding

## Objective

Onboard the IKEA BILRESA dual button (Matter device) as `office-button` in the spine,
create the `ha.automation.create` capability, and wire button_1 to toggle `light.office_desk_bulb`.

## Scope

1. **GAP-OP-497**: Build `ha.automation.create` capability — REST API `POST /api/config/automation/config/{id}`
   - Script: `ops/plugins/ha/bin/ha-automation-create`
   - Register in capabilities.yaml + capability_map.yaml
   - Scoped: only creates automations, does not delete

2. **GAP-OP-498**: Create the office button automation via the new capability
   - Trigger: `event.bilresa_dual_button_button_1` (button press)
   - Action: `light.toggle` on `light.office_desk_bulb`
   - Button 2: TBD (brightness cycle or second device)

3. **GAP-OP-499**: Commit office-button device registry entry + D117 gate updates
   - Already registered in home.device.registry.yaml (unstaged)
   - Includes `controls: office-desk-bulb` cross-reference

4. **GAP-OP-500**: Refresh HA device map after renaming button in HA UI
   - Manual step: rename "BILRESA dual button" → "Office Button" in HA Settings
   - Then run `ha.device.map.build` to capture updated entities

## Prerequisites

- HA API token must be valid (D99 currently failing — may need rotation)
- Button must be renamed in HA UI before GAP-OP-500

## Exit Criteria

- `ha.automation.create` capability registered and tested
- Office button toggles office desk bulb via HA automation
- Device registry, device map, and D117 gate all pass
