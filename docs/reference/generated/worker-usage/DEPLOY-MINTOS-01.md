---
status: generated
authority_state: projection
projection_of:
  - ops/bindings/terminal.worker.catalog.yaml
owner: "@ronny"
last_verified: 2026-03-24
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
- `../agentic-foundation/docs/agents/mint-os-agent.contract.md`

## Capabilities (1)
- `mcp.runtime.status`

## Gates (10)
- `D148`
- `D225`
- `D226`
- `D235`
- `D236`
- `D260`
- `D390`
- `D391`
- `D394`
- `D395`

## Workflow
- Startup: read `NORTH_STAR.md`, `docs/governance/SPINE.md`, and `docs/governance/SESSION_PROTOCOL.md`; then run `./bin/ops status --json`, `./bin/ops verify --core-only`, and `./bin/ops cap list`.

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
