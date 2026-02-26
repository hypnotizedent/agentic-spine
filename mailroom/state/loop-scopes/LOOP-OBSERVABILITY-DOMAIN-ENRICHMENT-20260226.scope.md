# LOOP-OBSERVABILITY-DOMAIN-ENRICHMENT-20260226

- **status**: closed
- **priority**: medium
- **scope**: governance + runtime
- **terminal**: SPINE-CONTROL-01
- **opened**: 2026-02-26
- **closed**: 2026-02-26

## Objective

Normalize observability into a first-class governed domain lane, migrate Dashy from docker-host (VM 200) to observability (VM 205), and safely deprecate old docker-host Dashy.

## Phases Completed

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Session start + baseline receipts | DONE |
| 1 | Create observability governed lane (DOMAIN-OBSERVABILITY-01) | DONE |
| 2 | Normalize Dashy bindings to VM 205 across 6 registries | DONE |
| 3 | Runtime cutover — deploy Dashy on VM 205, update CF tunnel ingress | DONE |
| 4 | Deprecate docker-host Dashy — stop + remove container | DONE |
| 5 | Drift gate + verification sweep — all gates pass (D79 pre-existing) | DONE |
| 6 | Governance closure + handoff bundle | DONE |

## Artifacts Created/Modified

- `docs/governance/OBSERVABILITY_DOMAIN_GOVERNANCE.md` — NEW canonical governance doc
- `ops/bindings/gate.domain.profiles.yaml` — added `observability` domain profile (7 gates, 9 prefixes)
- `ops/bindings/capability.domain.catalog.yaml` — added observability domain (18 capabilities)
- `ops/bindings/terminal.role.contract.yaml` — added DOMAIN-OBSERVABILITY-01 (12 capabilities)
- `ops/bindings/terminal.worker.catalog.yaml` — added DOMAIN-OBSERVABILITY-01 full entry
- `ops/bindings/terminal.launcher.view.yaml` — added DOMAIN-OBSERVABILITY-01 launcher entry
- `ops/bindings/gate.registry.yaml` — fixed gate count 237→238
- `ops/bindings/docker.compose.targets.yaml` — moved dashy from docker-host to observability
- `ops/bindings/services.health.yaml` — repointed dashy probe to 100.120.163.70:4000
- `ops/bindings/vm.lifecycle.yaml` — removed dashy from VM 200, added to VM 205
- `docs/governance/SERVICE_REGISTRY.yaml` — repointed dashy to host: observability
- `docs/governance/STACK_REGISTRY.yaml` — updated dashy deploy target to proxmox:vm-205
- `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml` — updated dash.ronny.works target_hint

## Runtime Changes

- Dashy container deployed on VM 205 (`/opt/stacks/dashy/`)
- Port binding: `4000:8080` (all interfaces, for Tailscale access)
- CF tunnel ingress: `dash.ronny.works → http://100.120.163.70:4000`
- Docker-host Dashy container stopped + removed

## Verify Results

- `verify.pack.run observability`: 6/7 PASS (D79 pre-existing)
- D59 cross-registry: PASS
- D85 gate registry parity: PASS (238 gates, 237 active, 1 retired)
- D22 nodes drift: PASS
