---
status: generated
owner: "@ronny"
last_verified: 2026-03-09
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

## Gates (9)
- `D124`
- `D126`
- `D127`
- `D148`
- `D150`
- `D153`
- `D3`
- `D63`
- `D67`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
