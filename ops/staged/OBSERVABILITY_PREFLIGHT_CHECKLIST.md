# Observability (VM 205) Preflight Checklist

| Field | Value |
|-------|-------|
| Generated | `2026-02-07T20:57Z` |
| Target VM | `observability` (VM 205) |
| Proxmox Host | `pve` (shop) |
| Profile | `spine-ready-v1` |
| Blocking Gate | Vaultwarden promotion (2026-02-08T04:41:00Z) |

## Prerequisites

| # | Prerequisite | Status | Notes |
|---|-------------|--------|-------|
| 1 | Vaultwarden promotion complete | PENDING | Soak expires 2026-02-08T04:41:00Z |
| 2 | D35 parity gate passing | PASS | Verified 2026-02-07 |
| 3 | D37 placement gate passing | PASS | Verified 2026-02-07 |
| 4 | D39 hypervisor identity gate passing | PASS | Verified 2026-02-07 |
| 5 | All drift gates passing | PASS | D1-D40 all active |
| 6 | Template VM 9000 exists on pve | PASS | `ubuntu-2404-cloudinit-template` |

## Compose Stack Readiness

| Service | Compose | Config | Health Check | Gaps |
|---------|---------|--------|-------------|------|
| Prometheus | READY | READY (prometheus.yml) | `/-/healthy` | None |
| Node Exporter | READY | N/A (self-contained) | `/metrics` | **NEW** — added during preflight |
| Grafana | READY | READY (datasources.yml) | `/api/health` | `.env.example` created |
| Loki | READY | READY (loki-config.yml) | `/ready` | None |
| Uptime Kuma | READY | N/A (UI-driven) | `extra/healthcheck` | Phase 5 (deferred) |

## Gaps Addressed During Preflight

| Gap | Status | Resolution |
|-----|--------|-----------|
| Grafana admin password template | FIXED | Created `grafana/.env.example` |
| Node-exporter not bundled | FIXED | Created `node-exporter/docker-compose.yml` |
| Promtail/log forwarder | DEFERRED | Metrics-first strategy; log shipping is Phase 4+ scope |
| CF tunnel for grafana | DEFERRED | Requires Caddy loop (LOOP-INFRA-CADDY-AUTH-20260207) |
| SSOT update templates | NOTED | Runbook Step 7 covers; inline snippets not critical |

## Expected Pre-Provision Failures

These failures are expected and should NOT be treated as blockers:

| Check | Expected Result | Reason |
|-------|----------------|--------|
| `infra.vm.ready.status --target observability` | FAIL (all 8 checks) | VM not provisioned |
| SSH to observability | FAIL | No host, no Tailscale IP |
| `services.health.yaml` observability entries | Missing | Not deployed yet |

## Staged File Inventory

```
ops/staged/observability/
├── prometheus/
│   ├── docker-compose.yml
│   └── prometheus.yml
├── node-exporter/
│   └── docker-compose.yml          ← NEW
├── grafana/
│   ├── docker-compose.yml
│   ├── .env.example                ← NEW
│   └── provisioning/datasources/datasources.yml
├── loki/
│   ├── docker-compose.yml
│   └── loki-config.yml
└── uptime-kuma/
    └── docker-compose.yml
```

## Deploy Sequence (Post-Promotion)

Per runbook (PHASE4_OBSERVABILITY_RUNBOOK.md):

1. `infra.vm.provision --target observability --dry-run` then `--execute`
2. Get Tailscale IP, add SSH target binding
3. `infra.vm.bootstrap --target observability --dry-run` then `--execute`
4. `infra.vm.ready.status --target observability` (all 8 checks pass)
5. `scp -r ops/staged/observability/* ubuntu@observability:/opt/stacks/`
6. Deploy in order: node-exporter → prometheus → loki → grafana → (uptime-kuma deferred to P5)
7. Health checks per service
8. SSOT updates (SERVICE_REGISTRY, services.health, docker.compose.targets, DEVICE_IDENTITY)
9. Final gates: preflight + parity + placement + spine.verify

## Readiness Verdict

**READY TO EXECUTE** — contingent on vaultwarden promotion gate clearing.

All compose configs are staged and health-checked. Two gaps (Grafana password, node-exporter) resolved during this preflight pass. Remaining gaps (promtail, CF tunnel) are explicitly deferred to later phases.
