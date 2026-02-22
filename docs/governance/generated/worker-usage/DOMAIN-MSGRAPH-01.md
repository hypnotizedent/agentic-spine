---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-msgraph-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-MSGRAPH-01 Usage Surface

- Terminal ID: `DOMAIN-MSGRAPH-01`
- Terminal Type: `domain-runtime`
- Status: `planned`
- Domain: `identity`
- Agent ID: `ms-graph-agent`
- Verify Command: `./bin/ops cap run verify.pack.run ms-graph`

## Write Scope
- `ops/plugins/ms-graph/`
- `ops/agents/ms-graph-agent.contract.md`

## Capabilities (10)
- `graph.calendar.create`
- `graph.calendar.get`
- `graph.calendar.list`
- `graph.calendar.rsvp`
- `graph.calendar.update`
- `graph.mail.draft.create`
- `graph.mail.draft.update`
- `graph.mail.get`
- `graph.mail.search`
- `graph.mail.send`

## Gates (18)
- `D124`
- `D125`
- `D126`
- `D146`
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

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
