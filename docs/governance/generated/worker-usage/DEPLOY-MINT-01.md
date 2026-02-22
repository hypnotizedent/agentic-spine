---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-deploy-mint-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DEPLOY-MINT-01 Usage Surface

- Terminal ID: `DEPLOY-MINT-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `mint`
- Agent ID: `mint-agent`
- Verify Command: `./bin/ops cap run verify.pack.run mint`

## Write Scope
- `ops/plugins/mint/`
- `ops/agents/mint-agent.contract.md`

## Capabilities (6)
- `mint.deploy.status`
- `mint.intake.validate`
- `mint.loop.daily`
- `mint.migrate.dryrun`
- `mint.modules.health`
- `mint.seeds.query`

## Gates (22)
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
- `D79`
- `D80`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
