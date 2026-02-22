---
status: generated
owner: "@ronny"
last_verified: 2026-02-22
scope: worker-usage-runtime-immich-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# RUNTIME-IMMICH-01 Usage Surface

- Terminal ID: `RUNTIME-IMMICH-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `photos`
- Agent ID: `immich-agent`
- Verify Command: `./bin/ops cap run verify.pack.run immich`

## Write Scope
- `ops/plugins/immich/`
- `ops/agents/immich-agent.contract.md`

## Capabilities (7)
- `immich.ingest.watch`
- `immich.reconcile.apply`
- `immich.reconcile.plan`
- `immich.reconcile.review`
- `immich.reconcile.rollback`
- `immich.reconcile.scan`
- `immich.status`

## Gates (19)
- `D124`
- `D125`
- `D126`
- `D148`
- `D16`
- `D17`
- `D31`
- `D42`
- `D44`
- `D48`
- `D58`
- `D62`
- `D63`
- `D67`
- `D79`
- `D80`
- `D81`
- `D84`
- `D85`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
