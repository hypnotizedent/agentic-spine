# home-assistant

Canonical domain policy for `home-assistant`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/home-assistant.bundle.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain home-assistant`
- Runtime namespace: capability ids remain `ha.*` or `ha-inventory-*`; live runtime paths remain `ops/plugins/domains/ha/` and `ops/bindings/domains/ha/`.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `ha-inventory-snapshot-build` |
| `ha.addon.restart` |
| `ha.addons.snapshot` |
| `ha.automation.create` |
| `ha.automation.trigger` |
| `ha.automations.snapshot` |
| `ha.backup.create` |
| `ha.config.extract` |
| `ha.dashboard.backup` |
| `ha.dashboard.snapshot` |
| `ha.device.map.build` |
| `ha.device.rename` |
| `ha.entity.state.baseline` |
| `ha.entity.status` |
| `ha.hacs.snapshot` |
| `ha.hacs.updates.check` |
| `ha.health.status` |
| `ha.helpers.snapshot` |
| `ha.integrations.snapshot` |
| `ha.light.toggle` |
| `ha.lock.control` |
| `ha.mcp.status` |
| `ha.refresh` |
| `ha.scene.activate` |
| `ha.scenes.snapshot` |
| `ha.script.run` |
| `ha.scripts.snapshot` |
| `ha.service.call` |
| `ha.ssot.apply` |
| `ha.ssot.baseline.build` |
| `ha.ssot.propose` |
| `ha.status` |
| `ha.sync.start` |
| `ha.sync.status` |
| `ha.sync.stop` |
| `ha.z2m.devices.snapshot` |
| `ha.z2m.health` |
| `ha.zwave.devices.snapshot` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
