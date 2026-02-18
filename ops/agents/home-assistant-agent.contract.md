# home-assistant-agent Contract

> **Status:** registered
> **Domain:** home-automation
> **Owner:** @ronny
> **Created:** 2026-02-11
> **Loop:** LOOP-MCP-RUNTIME-GOVERNANCE-20260211
> **Last reviewed:** 2026-02-17

---

## Identity

- **Agent ID:** home-assistant-agent
- **Domain:** home-automation (Home Assistant configuration, automations, device management)
- **MCP Server:** `~/code/workbench/infra/compose/mcpjungle/servers/home-assistant/`
- **Registry:** `ops/bindings/agents.registry.yaml`
- **Mutation contract:** `ops/bindings/ha.identity.mutation.contract.yaml`
- **Workbench home:** `~/code/workbench/agents/home-assistant/`

## Owns (Application Layer)

| Concern | System |
|---------|--------|
| Automation management | Home Assistant |
| Device/entity state queries | Home Assistant |
| Service calls (blocked — requires spine capability) | Home Assistant |
| Dashboard configuration | Home Assistant |
| Domain docs, runbooks, gotchas | Workbench `agents/home-assistant/docs/` |

## Defers to Spine (Infrastructure Layer)

| Concern | Spine Artifact |
|---------|---------------|
| SSOT auto-grade | `ha.ssot.propose` / `ha.ssot.apply` capabilities |
| Stack deployment | `ops/bindings/docker.compose.targets.yaml` |
| Health probes | `ops/bindings/services.health.yaml` |
| Secrets | Infisical `home-assistant/prod/HA_API_TOKEN` |
| Backups | `backup.*` capabilities |
| Event-driven sync | `ha.sync.start` / `ha.sync.stop` / `ha.sync.status` capabilities |

## Governed Tools

| Tool | Status | Spine Capability |
|------|--------|-----------------|
| ha_get_states | ALLOWED | Read-only, no spine cap needed |
| ha_get_state | ALLOWED | Read-only, no spine cap needed |
| ha_get_history | ALLOWED | Read-only, no spine cap needed |
| ha_call_service | BLOCKED | `ha.service.call` (governed mutation path via spine caps) |

## Spine Capabilities (37 registered)

Key capability clusters available via `./bin/ops cap run ha.*`:

| Cluster | Capabilities | Purpose |
|---------|-------------|---------|
| Snapshot | `ha.automations.snapshot`, `ha.scripts.snapshot`, `ha.scenes.snapshot`, `ha.helpers.snapshot`, `ha.integrations.snapshot`, `ha.addons.snapshot`, `ha.dashboard.snapshot`, `ha.hacs.snapshot` | Pull current state into bindings |
| Device/Entity | `ha.device.map.build`, `ha.device.rename`, `ha.entity.state.baseline`, `ha.entity.status` | Device registry management |
| Mutations | `ha.service.call`, `ha.light.toggle`, `ha.lock.control`, `ha.scene.activate`, `ha.script.run`, `ha.automation.trigger`, `ha.automation.create` | Governed device control |
| SSOT | `ha.ssot.propose`, `ha.ssot.apply`, `ha.ssot.baseline.build` | Binding auto-grade pipeline |
| Sync | `ha.sync.start`, `ha.sync.stop`, `ha.sync.status` | Event-driven daemon |
| Health | `ha.health.status`, `ha.status`, `ha.refresh`, `ha.z2m.health` | Operational checks |
| Backup | `ha.backup.create`, `ha.dashboard.backup` | Backup creation |
| Z-Wave/Z2M | `ha.z2m.devices.snapshot`, `ha.zwave.devices.snapshot` | Protocol device snapshots |
| HACS | `ha.hacs.snapshot`, `ha.hacs.updates.check` | Community store management |
| Config | `ha.config.extract` | Configuration extraction |

## Drift Gates (14 active)

| Gate | Name | Enforces |
|------|------|----------|
| D92 | ha-config-version-control | HA config files extracted to workbench |
| D99 | ha-token-freshness | API token returns HTTP 200 |
| D101 | ha-addon-inventory-parity | Add-on inventory fresh (<14d) |
| D102 | ha-device-map-freshness | Device map fresh (<14d) |
| D104 | streamdeck-ha-config-parity | Stream Deck HA config tracked |
| D105 | ha-mcp-governance-lock | `ha_call_service` blocked in MCP |
| D110 | media-ha-duplicate-audit-lock | No HA/shop add-on overlap |
| D113 | z2m-bridge-connectivity | Z2M bridge connected |
| D114 | ha-automation-stability | Automation count stable |
| D115 | ha-ssot-baseline-freshness | SSOT baseline fresh |
| D117 | iot-device-naming-parity | IoT naming convention |
| D118 | z2m-device-health | Z2M battery/staleness |
| D119 | z2m-naming-parity | Z2M cross-file naming |
| D120 | ha-area-parity | HA areas match SSOT |

## Invocation

- **Primary:** Claude Code via spine capabilities (`./bin/ops cap run ha.*`)
- **MCP:** Available but not wired into Claude Desktop (read-only tools only)
- **Sync daemon:** `./bin/ops cap run ha.sync.start` (event-driven binding refresh)

## Endpoints

| Service | Host | Notes |
|---------|------|-------|
| Home Assistant | proxmox-home VM 100 | LAN: `10.0.0.100:8123`, Tailscale: down (GAP-OP-502) |

## Mutation Contract

All HA runtime mutations MUST flow through the canonical mutation contract:
`ops/bindings/ha.identity.mutation.contract.yaml`

This contract defines:
- **Allowed surfaces:** Only spine capabilities (ha.device.rename, ha.service.call, etc.)
- **Forbidden channels:** Manual UI, raw WebSocket, ad-hoc SSH, unmanaged scripts
- **Post-mutation refresh:** ha.device.map.build → ha.refresh → ha.ssot.baseline.build
- **Required SSOTs:** ha.areas.yaml, ha.orphan.classification.yaml, home.device.registry.yaml, ha.ssot.baseline.yaml

Status check: `./bin/ops cap run ha.identity.mutation.contract.status`

## Known Issues

- MCP server `index.ts` defaults to Tailscale IP `100.67.120.1` (currently 403). Override via `HA_HOST` env var or fix default to LAN.
- Workbench `RUNBOOK.md` is a 3-line stub — should consolidate with `HASS_OPERATIONAL_RUNBOOK.md` or be fleshed out.
