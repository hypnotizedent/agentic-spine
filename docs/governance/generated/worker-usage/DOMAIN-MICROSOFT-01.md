---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-microsoft-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-MICROSOFT-01 Usage Surface

- Terminal ID: `DOMAIN-MICROSOFT-01`
- Terminal Type: `domain-runtime`
- Status: `planned`
- Domain: `identity`
- Agent ID: `microsoft-agent`
- Verify Command: `./bin/ops cap run verify.pack.run microsoft`

## Write Scope
- `ops/plugins/microsoft/`
- `ops/agents/microsoft-agent.contract.md`

## Capabilities (10)
- `microsoft.calendar.create`
- `microsoft.calendar.get`
- `microsoft.calendar.list`
- `microsoft.calendar.rsvp`
- `microsoft.calendar.update`
- `microsoft.mail.draft.create`
- `microsoft.mail.draft.update`
- `microsoft.mail.get`
- `microsoft.mail.search`
- `microsoft.mail.send`

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
