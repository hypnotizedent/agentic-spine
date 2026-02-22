---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-finance-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-FINANCE-01 Usage Surface

- Terminal ID: `DOMAIN-FINANCE-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `finance-ops`
- Agent ID: `finance-agent`
- Verify Command: `./bin/ops cap run verify.pack.run finance`

## Write Scope
- `ops/agents/finance-agent.contract.md`

## Capabilities (1)
- `finance.stack.status`

## Gates (21)
- `D124`
- `D125`
- `D126`
- `D148`
- `D16`
- `D17`
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
- `D79`
- `D80`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
