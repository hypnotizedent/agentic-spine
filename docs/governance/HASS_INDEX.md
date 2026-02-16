---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: ha-doc-index
parent_loop: LOOP-HA-GOVERNANCE-CONSOLIDATION-20260216
---

# Home Assistant Documentation Index

> Single entry point for all HA governance in the spine.
> When in doubt, start here.

## Quick Start

| I want to... | Go to |
|---|---|
| Run all HA snapshots at once | `./bin/ops cap run ha.refresh` |
| See full HA status dashboard | `./bin/ops cap run ha.status` |
| Check Z2M device health | `./bin/ops cap run ha.z2m.health` |
| Look up a single entity | `./bin/ops cap run ha.entity.status <entity_id>` |
| Discover all HA capabilities | `./bin/ops cap list \| grep ha.` |
| Run HA drift gates only | `./bin/ops cap run spine.verify` (D92-D120) |

## Primary Documents

| Document | What it covers | When to use |
|---|---|---|
| [HASS_OPERATIONAL_RUNBOOK.md](HASS_OPERATIONAL_RUNBOOK.md) | VM 100 identity, integrations, automations, HACS, coordinators, Z2M/Matter/Thread, backup/restore, recovery | Day-to-day HA operations, troubleshooting, adding devices |
| [HASS_SSOT_BASELINE.md](HASS_SSOT_BASELINE.md) | Binding architecture, two-tier model, refresh procedures, regression detection | Understanding how HA bindings work, refreshing SSOTs |
| [HASS_AGENT_GOTCHAS.md](HASS_AGENT_GOTCHAS.md) | 7 agent friction points: SSH quoting, Supervisor API, entity naming, add-on slugs | Before scripting HA interactions, debugging API failures |
| [HASS_MCP_INTEGRATION.md](HASS_MCP_INTEGRATION.md) | MCP `ha_call_service` blocked, approved capability path, domain allowlist | Understanding why MCP direct calls are blocked |
| [HASS_LEGACY_EXTRACTION_MATRIX.md](HASS_LEGACY_EXTRACTION_MATRIX.md) | Legacy-to-spine migration audit (95 files inventoried, 7 extracted) | Historical reference only (status: proposed) |

## Bindings (SSOTs)

| Binding | Content | Refreshed by |
|---|---|---|
| `ha.ssot.baseline.yaml` | Unified index: entity/device/automation counts, health summary | `ha.ssot.baseline.build` |
| `ha.automations.yaml` | All 27 automations with state, last triggered | `ha.automations.snapshot` |
| `ha.device.map.yaml` | 58 devices cross-referenced with Z2M + network registry | `ha.device.map.build` |
| `ha.entity.state.baseline.yaml` | 517 entities with expected-unavailable/unknown allowlists | `ha.entity.state.baseline` |
| `ha.addons.yaml` | 20 Supervisor add-ons with status | `ha.addons.snapshot` |
| `ha.integrations.yaml` | 40 integrations across 30 domains | `ha.integrations.snapshot` |
| `ha.dashboards.yaml` | 10 Lovelace dashboards | `ha.dashboard.snapshot` |
| `ha.hacs.yaml` | 46 HACS repositories | `ha.hacs.snapshot` |
| `ha.helpers.yaml` | 10 helper entities (input_boolean, input_select, etc.) | `ha.helpers.snapshot` |
| `ha.scenes.yaml` | Scene entities | `ha.scenes.snapshot` |
| `ha.scripts.yaml` | 19 script entities | `ha.scripts.snapshot` |
| `z2m.devices.yaml` | 6 Z2M devices with IEEE, battery, LQI, last seen | `ha.z2m.devices.snapshot` |
| `z2m.naming.yaml` | Canonical name to IEEE to entity ID mapping | Hand-maintained |
| `ha.device.map.overrides.yaml` | Manual device name overrides | Hand-maintained |
| `ha.sync.config.yaml` | Sync agent event-to-capability mappings | Hand-maintained |
| `ha.entity.state.expected-unavailable.yaml` | 82 entities expected to be unavailable | Hand-maintained |
| `ha.entity.state.expected-unknown.yaml` | 29 entities expected to have unknown state | Hand-maintained |

## Drift Gates

| Gate | What it checks | Severity |
|---|---|---|
| D92 | HA config files extracted to workbench, fresh < 30d | medium |
| D98 | Z2M device registry exists, non-empty, fresh < 14d | medium |
| D99 | HA API token valid (HTTP 200) | high |
| D101 | Add-on inventory exists, non-empty, fresh < 14d | medium |
| D102 | Device map exists, non-empty, fresh < 14d | medium |
| D104 | DHCP audit summary exists, fresh < 14d | medium |
| D105 | MCP governance lock (ha_call_service blocked) | low |
| D113 | Coordinator health (Z2M started, SLZB-06MU up) | medium |
| D114 | Automation count matches expected (27) | medium |
| D115 | SSOT baseline exists, fresh < 7d | medium |
| D117 | IoT device naming parity (Tuya entities) | medium |
| D118 | Z2M battery > 20%, staleness < 48h, bridge connected | medium |
| D119 | Z2M naming parity across 3 bindings | medium |
| D120 | HA device areas match canonical naming | medium |

## Supporting Infrastructure

| Document | HA relevance |
|---|---|
| [MINILAB_SSOT.md](MINILAB_SSOT.md) | VM 100 identity, resources, coordinator IPs |
| [DEVICE_IDENTITY_SSOT.md](DEVICE_IDENTITY_SSOT.md) | Device naming conventions, tier definitions |
| [HOME_NETWORK_AUDIT_RUNBOOK.md](HOME_NETWORK_AUDIT_RUNBOOK.md) | DHCP audit, network device discovery |
| [HOME_NETWORK_DEVICE_ONBOARDING.md](HOME_NETWORK_DEVICE_ONBOARDING.md) | New device registration procedure |
| [HOME_BACKUP_STRATEGY.md](HOME_BACKUP_STRATEGY.md) | Backup cadence (details in operational runbook) |
| [DR_RUNBOOK.md](DR_RUNBOOK.md) | Disaster recovery including HA restore |
| `docs/core/INFISICAL_PROJECTS.md` | HA_API_TOKEN secret binding |
| `docs/legacy/brain-lessons/HOME_ASSISTANT_LESSONS.md` | Historical lessons (legacy, consolidated into runbook) |

## Maintenance

- **Refresh all bindings:** `./bin/ops cap run ha.refresh`
- **Check everything:** `./bin/ops cap run ha.status`
- **Verify gates:** `./bin/ops cap run spine.verify`
- **Onboard new device:** Update `home.device.registry.yaml` + run `ha.device.map.build` + add to `z2m.naming.yaml` if Zigbee
- **Add automation:** Use `ha.automation.create` + run `ha.automations.snapshot` + update D114 expected count
