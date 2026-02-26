---
status: generated
owner: "@ronny"
last_verified: 2026-02-26
scope: worker-usage-domain-observability-01
source_catalog: ops/bindings/terminal.worker.catalog.yaml
---

# DOMAIN-OBSERVABILITY-01 Usage Surface

- Terminal ID: `DOMAIN-OBSERVABILITY-01`
- Terminal Type: `domain-runtime`
- Status: `active`
- Domain: `observability`
- Agent ID: (none)
- Verify Command: `./bin/ops cap run verify.pack.run observability`

## Write Scope
- `ops/plugins/observability/`

## Capabilities (12)
- `observability.stack.status`
- `prometheus.targets.status`
- `uptime.kuma.monitors.sync`
- `stability.control.snapshot`
- `stability.control.reconcile`
- `alerting.probe`
- `alerting.dispatch`
- `alerting.status`
- `nas.health.status`
- `idrac.health.status`
- `switch.health.status`
- `gitea.status`

## Gates (7)
- `D22`
- `D23`
- `D79`
- `D80`
- `D125`
- `D148`
- `D234`

## Boundaries
- Runtime surface is generated from registration and role contracts.
- Do not hand-edit this file; regenerate via the generator script.
