---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-comms-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-COMMS-01 Usage Surface

- Terminal ID: `DOMAIN-COMMS-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `communications`
- Agent ID: `communications-agent`
- Verify Command: `./bin/ops cap run verify.pack.run communications`

## Write Scope
- `ops/plugins/communications/`
- `ops/agents/communications-agent.contract.md`

## Capabilities (12)
- `communications.delivery.anomaly.dispatch`
- `communications.delivery.anomaly.status`
- `communications.delivery.log`
- `communications.mail.search`
- `communications.mail.send.test`
- `communications.mailboxes.list`
- `communications.policy.status`
- `communications.provider.status`
- `communications.send.execute`
- `communications.send.preview`
- `communications.stack.status`
- `communications.templates.list`

## Gates (18)
- `D124`
- `D125`
- `D126`
- `D147`
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
