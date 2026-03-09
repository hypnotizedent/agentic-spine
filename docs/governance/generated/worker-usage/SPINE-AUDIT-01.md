---
status: generated
owner: "@ronny"
last_verified: 2026-03-09
scope: worker-usage-spine-audit-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# SPINE-AUDIT-01 Usage Surface

- Terminal ID: `SPINE-AUDIT-01`
- Terminal Type: `observation`
- Status: `active`
- Domain: `core`
- Agent ID: `none`
- Verify Command: `./bin/ops cap run verify.core.run`

## Write Scope
- `receipts/`
- `docs/governance/_audits/`

## Capabilities (5)
- `spine.verify`
- `stability.control.snapshot`
- `verify.core.run`
- `verify.domain.run`
- `verify.release.run`

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
