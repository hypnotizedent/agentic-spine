---
loop_id: LOOP-MINT-NEW-VM-SERVICES-E2E-20260221
created: 2026-02-21
status: closed
closed_at: 2026-02-21
owner: "@ronny"
scope: mint
priority: high
objective: Cut over mint customer/service paths from legacy docker-host (100.92.156.118) to new VMs (mint-apps VM 213 100.79.183.14, mint-data VM 212 100.106.72.25). Verify E2E. Clean governance.
---

# Loop Scope: LOOP-MINT-NEW-VM-SERVICES-E2E-20260221

## Objective

Cut over mint customer/service paths from legacy docker-host to new VMs, verify E2E, and leave clean governance receipts.

## Scope

1. **Cloudflare routing cutover**: Update cloudflared extra_hosts to route mint hostnames to new VMs where replacements exist.
2. **Health probe normalization**: Disable legacy docker-host probes superseded by v2 probes on new VMs.
3. **DOMAIN_ROUTING_REGISTRY**: Update target_hints to reflect new VM routing.
4. **N8n workflow hygiene**: Verify A01-A04 workflows use NEW-only paths (no legacy/Slack).
5. **E2E verification**: Public routes, runtime health, verify lanes.

## Gap Registry

- GAP-OP-798: Cloudflare extra_hosts still route to legacy docker-host for services with new replacements
- GAP-OP-799: Legacy health probes still active for services migrated to new VMs
- GAP-OP-800: DOMAIN_ROUTING_REGISTRY target_hints stale for cutover services

## Changed Files (scope allowlist)

- `ops/bindings/services.health.yaml`
- `ops/bindings/operational.gaps.yaml`
- `mailroom/state/loop-scopes/LOOP-MINT-NEW-VM-SERVICES-E2E-20260221.scope.md`
- `docs/governance/DOMAIN_ROUTING_REGISTRY.yaml`
- `workbench: infra/cloudflare/tunnel/docker-compose.yml`
