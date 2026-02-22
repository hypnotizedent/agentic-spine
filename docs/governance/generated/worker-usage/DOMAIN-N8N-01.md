---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-n8n-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-N8N-01 Usage Surface

- Terminal ID: `DOMAIN-N8N-01`
- Terminal Type: `domain-runtime`
- Status: `planned`
- Domain: `automation`
- Agent ID: `n8n-agent`
- Verify Command: `./bin/ops cap run verify.pack.run n8n`

## Write Scope
- `ops/plugins/n8n/`
- `ops/agents/n8n-agent.contract.md`

## Capabilities (11)
- `n8n.infra.health`
- `n8n.workflows.activate`
- `n8n.workflows.deactivate`
- `n8n.workflows.delete`
- `n8n.workflows.export`
- `n8n.workflows.get`
- `n8n.workflows.import`
- `n8n.workflows.list`
- `n8n.workflows.snapshot`
- `n8n.workflows.snapshot.status`
- `n8n.workflows.update`

## Gates (23)
- `D124`
- `D125`
- `D126`
- `D148`
- `D16`
- `D17`
- `D18`
- `D22`
- `D23`
- `D31`
- `D42`
- `D44`
- `D48`
- `D58`
- `D62`
- `D63`
- `D67`
- `D73`
- `D79`
- `D80`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
