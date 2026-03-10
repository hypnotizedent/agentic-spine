---
status: generated
owner: "@ronny"
last_verified: 2026-03-09
scope: worker-usage-mint-dutchman-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# MINT-DUTCHMAN-01 Usage Surface

- Terminal ID: `MINT-DUTCHMAN-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `mint`
- Agent ID: `flying-dutchman`
- Verify Command: `./bin/ops cap run verify.pack.run mint`

## Write Scope
- `ops/plugins/mint/`
- `../agentic-foundation/docs/agents/flying-dutchman.contract.md`

## Capabilities (7)
- `mint.deploy.status`
- `mint.deploy.sync`
- `mint.live.baseline.status`
- `mint.loop.daily`
- `mint.migrate.dryrun`
- `mint.modules.health`
- `mint.runtime.proof`

## Gates (6)
- `D148`
- `D225`
- `D226`
- `D235`
- `D236`
- `D260`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
