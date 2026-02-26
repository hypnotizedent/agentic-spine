# Observability Domain Governance

> **Status:** authoritative
> **Owner:** @ronny
> **Last verified:** 2026-02-26
> **Loop:** LOOP-OBSERVABILITY-DOMAIN-ENRICHMENT-20260226

---

## 1. Canonical Naming Map

| Identifier | Context | When to Use |
|------------|---------|-------------|
| `DOMAIN-OBSERVABILITY-01` | Terminal role | Worker picker, terminal launcher, session wiring, write_scope enforcement |
| `observability` | Domain ID | Gate domain profiles, capability domain catalog, verify packs |

**Rules:**
- No dedicated agent yet. Capabilities are owned by `ops/plugins/observability/`.
- Stability/alerting capabilities are observability-domain even though they probe cross-domain services.

## 2. Authority Map

| File | Purpose | SSOT For |
|------|---------|----------|
| `ops/plugins/observability/` | All capability scripts | Runtime implementation |
| `ops/bindings/capability.domain.catalog.yaml` | Domain catalog | Canonical capability list |
| `ops/bindings/terminal.role.contract.yaml` | Terminal role | DOMAIN-OBSERVABILITY-01 scope |
| `ops/bindings/terminal.launcher.view.yaml` | Launcher view | UI metadata |
| `ops/bindings/gate.domain.profiles.yaml` | Gate profile | Observability domain gate IDs, path triggers |
| `ops/bindings/services.health.yaml` | Health probes | Prometheus, Grafana, Loki, Uptime Kuma, Dashy |
| `ops/bindings/docker.compose.targets.yaml` | Compose targets | observability stack on VM 205 |
| `ops/bindings/vm.lifecycle.yaml` | VM lifecycle | VM 205 services and stacks |
| `docs/governance/SERVICE_REGISTRY.yaml` | Service registry | Dashy, Prometheus, Grafana, Loki, Uptime Kuma |
| `docs/governance/STACK_REGISTRY.yaml` | Stack registry | dashy stack source + deploy info |

## 3. Infrastructure

| Component | VM | Port | Health Endpoint |
|-----------|-----|------|-----------------|
| Prometheus | 205 | 9090 | `/-/healthy` |
| Grafana | 205 | 3000 | `/api/health` |
| Loki | 205 | 3100 | `/ready` |
| Uptime Kuma | 205 | 3001 | `/` (302) |
| Node Exporter | 205 | 9100 | `/metrics` |
| Dashy | 205 | 4000 | `/` (200) |

## 4. Operator Flow

1. Check stack health: `./bin/ops cap run observability.stack.status`
2. Check Prometheus scrape targets: `./bin/ops cap run prometheus.targets.status`
3. Run stability snapshot: `./bin/ops cap run stability.control.snapshot`
4. If degraded, run reconcile planner: `./bin/ops cap run stability.control.reconcile`
5. Sync Uptime Kuma monitors: `./bin/ops cap run uptime.kuma.monitors.sync`

## 5. Drift Gate Expectations

| Gate | Description |
|------|-------------|
| D22 | Docker compose targets parity |
| D23 | Service health probe alignment |
| D79 | Raycast script registration |
| D80 | Service health status |
| D125 | Capability domain catalog parity |
| D148 | Entry surface contract |
| D234 | Boot drive usage |

## 6. Dashy Migration

Dashy migrated from docker-host (VM 200) to observability (VM 205) as part of LOOP-OBSERVABILITY-DOMAIN-ENRICHMENT-20260226. Canonical source: `workbench:infra/compose/dashy/`. Cloudflare tunnel routes `dash.ronny.works` to VM 205.
