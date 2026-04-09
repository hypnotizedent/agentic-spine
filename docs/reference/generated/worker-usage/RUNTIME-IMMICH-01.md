---
status: generated
authority_state: projection
projection_of:
  - ops/bindings/terminal.worker.catalog.yaml
owner: "@ronny"
last_verified: 2026-04-09
scope: worker-usage-runtime-immich-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# RUNTIME-IMMICH-01 Usage Surface

- Terminal ID: `RUNTIME-IMMICH-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `immich`
- Agent ID: `none`
- Verify Command: `./bin/ops cap run verify.pack.run immich`

## Write Scope
- (none)

## Capabilities (0)
- (none)

## Gates (18)
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

## Workflow
- Canonical session entry: `./bin/ops cap run session.v3.attach -- --allow-no-loop`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
