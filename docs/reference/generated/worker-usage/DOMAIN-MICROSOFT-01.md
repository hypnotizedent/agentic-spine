---
status: generated
authority_state: projection
projection_of:
  - ops/bindings/terminal.worker.catalog.yaml
owner: "@ronny"
last_verified: 2026-04-07
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
- `ops/plugins/providers/microsoft/`
- `../agentic-foundation/docs/agents/microsoft-agent.contract.md`

## Capabilities (4)
- `microsoft.calendar.get`
- `microsoft.calendar.list`
- `microsoft.mail.get`
- `microsoft.mail.search`

## Gates (17)
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
- `D58`
- `D62`
- `D63`
- `D67`
- `D81`
- `D84`
- `D85`

## Workflow
- Startup: read `NORTH_STAR.md`, `docs/governance/SPINE.md`, and `docs/governance/SESSION_PROTOCOL.md`; then run `./bin/ops status --json`, `./bin/ops verify --core-only`, and `./bin/ops cap list`.

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
