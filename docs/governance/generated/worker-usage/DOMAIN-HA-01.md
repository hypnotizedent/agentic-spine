---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-ha-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-HA-01 Usage Surface

- Terminal ID: `DOMAIN-HA-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `home-automation`
- Agent ID: `home-assistant-agent`
- Verify Command: `./bin/ops cap run verify.pack.run home`

## Write Scope
- `ops/plugins/ha/`
- `ops/agents/home-assistant-agent.contract.md`

## Capabilities (13)
- `ha.automation.create`
- `ha.automation.trigger`
- `ha.device.map.build`
- `ha.entity.status`
- `ha.health.status`
- `ha.refresh`
- `ha.service.call`
- `ha.ssot.apply`
- `ha.ssot.propose`
- `ha.status`
- `ha.sync.start`
- `ha.sync.status`
- `ha.sync.stop`

## Gates (25)
- `D101`
- `D102`
- `D104`
- `D105`
- `D120`
- `D124`
- `D125`
- `D126`
- `D148`
- `D16`
- `D17`
- `D31`
- `D42`
- `D44`
- `D48`
- `D58`
- `D62`
- `D63`
- `D67`
- `D81`
- `D84`
- `D85`
- `D92`
- `D98`
- `D99`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
