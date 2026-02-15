---
id: LOOP-HA-AGENT-FRICTION-ELIMINATION-20260215
status: closed
closed: 2026-02-15
opened: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-462
  - GAP-OP-463
  - GAP-OP-464
  - GAP-OP-465
---

# HA Agent Friction Elimination

## Objective

Eliminate all known friction points that cause agents to fail or waste cycles when
performing Home Assistant operations. Every pattern that broke during the coordinator
activation session (2026-02-15) gets documented, hardened, or cleaned up.

## Phase 1: Agent Gotchas Document (GAP-OP-462)

Create `docs/governance/HASS_AGENT_GOTCHAS.md` — canonical friction reference covering:
- `ha apps` vs deprecated `ha addons` CLI
- Supervisor API full-option-replacement behavior
- SUPERVISOR_TOKEN access (bash -l wrapper required)
- OTBR network_device bare host:port format
- Add-on slug formats (core_* vs community a0d7b954_*)
- `ha apps options` doesn't exist (must use Supervisor REST API)
- OTBR schema: device required even with network_device
- Z2M bridge entity naming

## Phase 2: Script Hardening (GAP-OP-463, GAP-OP-464)

- GAP-OP-463: Fix ha-addons-snapshot to use SSH bash -l pattern instead of docker exec.
  Add slug format annotation to ha.addons.yaml header comments.
- GAP-OP-464: Fix ha-z2m-devices-snapshot to discover container name dynamically
  instead of hardcoding addon_45df7312_zigbee2mqtt.

## Phase 3: Legacy Cleanup (GAP-OP-465)

- Retire or update HOME_ASSISTANT_LESSONS.md (`ha addons` → `ha apps`)
- Sweep for any remaining deprecated HA CLI references across docs/

## Exit Criteria

- HASS_AGENT_GOTCHAS.md exists and covers all 8+ friction points
- ha-addons-snapshot uses bash -l pattern (no docker exec)
- ha-z2m-devices-snapshot discovers container name dynamically
- Zero references to `ha addons` in non-legacy governance docs
- spine.verify PASS (D85, D67, D63 all green)
