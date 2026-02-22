---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-domain-firefly-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-FIREFLY-01 Usage Surface

- Terminal ID: `DOMAIN-FIREFLY-01`
- Terminal Type: `domain-runtime`
- Status: `planned`
- Domain: `finance`
- Agent ID: `firefly-agent`
- Verify Command: `./bin/ops cap run verify.pack.run finance`

## Write Scope
- `ops/agents/firefly-agent.contract.md`

## Capabilities (1)
- `finance.stack.status`

## Gates (6)
- `D125`
- `D148`
- `D22`
- `D23`
- `D79`
- `D80`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
