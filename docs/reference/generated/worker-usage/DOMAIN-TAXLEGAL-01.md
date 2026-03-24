---
status: generated
authority_state: projection
projection_of:
  - ops/bindings/terminal.worker.catalog.yaml
owner: "@ronny"
last_verified: 2026-03-24
scope: worker-usage-domain-taxlegal-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-TAXLEGAL-01 Usage Surface

- Terminal ID: `DOMAIN-TAXLEGAL-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `tax-legal`
- Agent ID: `tax-legal-agent`
- Verify Command: `./bin/ops cap run verify.core.run`

## Write Scope
- `ops/plugins/domains/taxlegal/`
- `../agentic-foundation/docs/agents/tax-legal-agent.contract.md`
- `runtime/domain-state/taxlegal/cases/`

## Capabilities (8)
- `taxlegal.case.intake`
- `taxlegal.case.status`
- `taxlegal.deadlines.refresh`
- `taxlegal.deadlines.status`
- `taxlegal.packet.generate`
- `taxlegal.research.answer`
- `taxlegal.source.ingest`
- `taxlegal.source.recall`

## Gates (16)
- `D124`
- `D126`
- `D127`
- `D148`
- `D150`
- `D153`
- `D3`
- `D389`
- `D391`
- `D410`
- `D411`
- `D415`
- `D416`
- `D418`
- `D63`
- `D67`

## Workflow
- Canonical session entry: `./bin/ops cap run session.v3.attach -- --allow-no-loop`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
