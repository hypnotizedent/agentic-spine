---
status: generated
owner: "@ronny"
last_verified: 2026-03-13
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
- `../agentic-foundation/docs/agents/firefly-agent.contract.md`

## Capabilities (1)
- `finance.stack.status`

## Gates (1)
- `D148`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
