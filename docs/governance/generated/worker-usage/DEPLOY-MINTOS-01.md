---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-deploy-mintos-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DEPLOY-MINTOS-01 Usage Surface

- Terminal ID: `DEPLOY-MINTOS-01`
- Terminal Type: `domain-runtime`
- Status: `planned`
- Domain: `commerce`
- Agent ID: `mint-os-agent`
- Verify Command: `./bin/ops cap run verify.pack.run mint`

## Write Scope
- `ops/agents/mint-os-agent.contract.md`

## Capabilities (1)
- `mcp.runtime.status`

## Gates (7)
- `D125`
- `D148`
- `D18`
- `D22`
- `D23`
- `D79`
- `D80`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
