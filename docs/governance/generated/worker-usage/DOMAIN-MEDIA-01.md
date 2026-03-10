---
status: generated
owner: "@ronny"
last_verified: 2026-03-09
scope: worker-usage-domain-media-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-MEDIA-01 Usage Surface

- Terminal ID: `DOMAIN-MEDIA-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `media`
- Agent ID: `media-agent`
- Verify Command: `./bin/ops cap run verify.pack.run media`

## Write Scope
- `ops/plugins/media/`
- `../agentic-foundation/docs/agents/media-agent.contract.md`

## Capabilities (7)
- `media.backup.create`
- `media.health.check`
- `media.metrics.today`
- `media.nfs.verify`
- `media.service.status`
- `media.stack.restart`
- `media.status`

## Gates (35)
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
- `D223`
- `D224`
- `D228`
- `D229`
- `D230`
- `D231`
- `D232`
- `D240`
- `D257`
- `D303`
- `D304`
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
