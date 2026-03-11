---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-26
scope: domain-capability-catalog
domain: observability
---

# observability Capability Catalog

Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability | Safety | Approval | Implementation |
|---|---|---|---|
| `observability.stack.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `prometheus.targets.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `uptime.kuma.monitors.sync` | `mutating` | `manual` | `ops/plugins/infra/observability/` |
| `stability.control.snapshot` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `stability.control.reconcile` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `alerting.probe` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `alerting.dispatch` | `mutating` | `manual` | `ops/plugins/infra/observability/` |
| `alerting.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `nas.health.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `idrac.health.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `switch.health.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `gitea.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `immich.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `immich.ingest.watch` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `finance.stack.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `ghostfolio.portfolio.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `automation.stack.latency.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
| `infra.core.slo.status` | `read-only` | `auto` | `ops/plugins/infra/observability/` |
