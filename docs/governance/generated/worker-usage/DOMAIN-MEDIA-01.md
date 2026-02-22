---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-media-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-MEDIA-01 Usage Surface

- Terminal ID: `DOMAIN-MEDIA-01`
- Terminal Type: `domain-runtime`
- Status: `planned`
- Domain: `media`
- Agent ID: `media-agent`
- Verify Command: `./bin/ops cap run verify.pack.run media`

## Write Scope
- `ops/plugins/media/`
- `ops/agents/media-agent.contract.md`

## Capabilities (5)
- `media.health.check`
- `media.metrics.today`
- `media.nfs.verify`
- `media.service.status`
- `media.status`

## Gates (24)
- `D106`
- `D107`
- `D108`
- `D109`
- `D110`
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
- `D79`
- `D80`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
