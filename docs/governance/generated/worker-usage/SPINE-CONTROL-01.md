---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-spine-control-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# SPINE-CONTROL-01 Usage Surface

- Terminal ID: `SPINE-CONTROL-01`
- Terminal Type: `control-plane`
- Status: `active`
- Domain: `core`
- Agent ID: `none`
- Verify Command: `./bin/ops cap run verify.core.run`

## Write Scope
- `bin/`
- `ops/`
- `surfaces/`
- `docs/governance/`
- `docs/core/`
- `docs/product/`
- `docs/brain/`
- `mailroom/`

## Capabilities (9)
- `gaps.claim`
- `gaps.close`
- `gaps.file`
- `loops.reconcile`
- `proposals.apply`
- `proposals.supersede`
- `stability.control.snapshot`
- `verify.core.run`
- `verify.domain.run`

## Gates (21)
- `D1`
- `D10`
- `D12`
- `D124`
- `D126`
- `D144`
- `D148`
- `D16`
- `D17`
- `D3`
- `D31`
- `D42`
- `D44`
- `D48`
- `D58`
- `D62`
- `D63`
- `D67`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
