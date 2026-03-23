---
status: generated
owner: "@ronny"
last_verified: 2026-03-23
scope: worker-usage-domain-observability-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-OBSERVABILITY-01 Usage Surface

- Terminal ID: `DOMAIN-OBSERVABILITY-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `observability`
- Agent ID: `none`
- Verify Command: `./bin/ops cap run verify.pack.run observability`

## Write Scope
- `ops/plugins/infra/observability/`
- `ops/plugins/providers/gitea/`

## Capabilities (16)
- `alerting.dispatch`
- `alerting.probe`
- `alerting.status`
- `gitea.pr.close`
- `gitea.pr.list`
- `gitea.pr.merge`
- `gitea.pr.status`
- `gitea.status`
- `idrac.health.status`
- `nas.health.status`
- `observability.stack.status`
- `prometheus.targets.status`
- `stability.control.reconcile`
- `stability.control.snapshot`
- `switch.health.status`
- `uptime.kuma.monitors.sync`

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

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
