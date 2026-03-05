---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: domain-capability-catalog
domain: home-assistant
---

# home-assistant Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `ha.addon.restart` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.addons.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.automation.create` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.automation.trigger` | `mutating` | `auto` | `agents/home-assistant/docs/` |
| `ha.automations.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.backup.create` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.config.extract` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.dashboard.backup` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.dashboard.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.device.map.build` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.device.rename` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.entity.state.baseline` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.entity.status` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.hacs.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.hacs.updates.check` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.health.status` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.helpers.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.integrations.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.light.toggle` | `mutating` | `auto` | `agents/home-assistant/docs/` |
| `ha.lock.control` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.mcp.status` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.refresh` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.scene.activate` | `mutating` | `auto` | `agents/home-assistant/docs/` |
| `ha.scenes.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.script.run` | `mutating` | `auto` | `agents/home-assistant/docs/` |
| `ha.scripts.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.service.call` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.ssot.apply` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.ssot.baseline.build` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.ssot.propose` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.status` | `read-only` | `auto` | `agents/home-assistant/` |
| `ha.sync.start` | `mutating` | `manual` | `agents/home-assistant/docs/` |
| `ha.sync.status` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.sync.stop` | `mutating` | `auto` | `agents/home-assistant/docs/` |
| `ha.z2m.devices.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.z2m.health` | `read-only` | `auto` | `agents/home-assistant/docs/` |
| `ha.zwave.devices.snapshot` | `read-only` | `auto` | `agents/home-assistant/docs/` |
