---
status: generated
owner: "@ronny"
last_verified: 2026-03-09
scope: worker-usage-spine-execution-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# SPINE-EXECUTION-01 Usage Surface

- Terminal ID: `SPINE-EXECUTION-01`
- Terminal Type: `control-plane`
- Status: `active`
- Domain: `core`
- Agent ID: `none`
- Verify Command: `./bin/ops cap run verify.core.run`

## Write Scope
- `mailroom/`
- `receipts/`

## Capabilities (4)
- `spine.control.cycle`
- `spine.control.execute`
- `spine.control.plan`
- `spine.control.tick`

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
