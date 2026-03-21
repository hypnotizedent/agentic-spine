---
status: generated
owner: "@ronny"
last_verified: 2026-03-21
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
- `docs/reference/brain/`
- `mailroom/`
- `CLAUDE.md`
- `AGENTS.md`

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

## Gates (14)
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
- `D63`
- `D67`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
