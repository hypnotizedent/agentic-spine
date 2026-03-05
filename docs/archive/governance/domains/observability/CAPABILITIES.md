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
| `observability.stack.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `prometheus.targets.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `uptime.kuma.monitors.sync` | `mutating` | `manual` | `ops/plugins/observability/` |
| `stability.control.snapshot` | `read-only` | `auto` | `ops/plugins/observability/` |
| `stability.control.reconcile` | `read-only` | `auto` | `ops/plugins/observability/` |
| `alerting.probe` | `read-only` | `auto` | `ops/plugins/observability/` |
| `alerting.dispatch` | `mutating` | `manual` | `ops/plugins/observability/` |
| `alerting.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `nas.health.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `idrac.health.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `switch.health.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `gitea.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `immich.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `immich.ingest.watch` | `read-only` | `auto` | `ops/plugins/observability/` |
| `finance.stack.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `ghostfolio.portfolio.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `automation.stack.latency.status` | `read-only` | `auto` | `ops/plugins/observability/` |
| `infra.core.slo.status` | `read-only` | `auto` | `ops/plugins/observability/` |
