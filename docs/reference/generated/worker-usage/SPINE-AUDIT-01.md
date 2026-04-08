---
status: generated
authority_state: projection
projection_of:
  - ops/bindings/terminal.worker.catalog.yaml
owner: "@ronny"
last_verified: 2026-04-07
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
- `evidence/verify/governance/`

## Capabilities (5)
- `spine.verify`
- `stability.control.snapshot`
- `verify.core.run`
- `verify.domain.run`
- `verify.release.run`

## Gates (20)
- `D124`
- `D126`
- `D127`
- `D148`
- `D150`
- `D153`
- `D3`
- `D389`
- `D391`
- `D406`
- `D410`
- `D416`
- `D422`
- `D423`
- `D425`
- `D426`
- `D62`
- `D63`
- `D67`

## Workflow
- Startup: read `NORTH_STAR.md`, `docs/governance/SPINE.md`, and `docs/governance/SESSION_PROTOCOL.md`; then run `./bin/ops status --json`, `./bin/ops verify --core-only`, and `./bin/ops cap list`.

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
