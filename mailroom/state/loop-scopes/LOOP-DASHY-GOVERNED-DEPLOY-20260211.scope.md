---
loop_id: LOOP-DASHY-GOVERNED-DEPLOY-20260211
status: closed
owner: "@ronny"
priority: medium
created: "2026-02-11"
closed: "2026-02-11"
parent_gap: GAP-OP-101
---

# LOOP: Dashy Governed Deploy

## Objective

Register Dashy as a fully governed spine service and deploy it on docker-host.
Dashy serves as the visual runtime map of all spine-managed services.

## Scope

1. Register Dashy in all spine bindings (docker.compose.targets, services.health, SERVICE_REGISTRY, STACK_REGISTRY)
2. Fix stale STACK_REGISTRY path (`infrastructure/dashy` -> `infra/compose/dashy`)
3. Deploy Dashy stack to docker-host (`~/stacks/dashy/`)
4. Validate health probe and CF tunnel route (dash.ronny.works)
5. Update Dashy config.yml to reflect spine-era topology (media split, new VMs)

## Out of Scope

- Finance VM migration (separate loop)
- Mint OS feature work
- MCP utility server policy (separate gap)

## Evidence Required

- `docker.compose.status` showing dashy stack healthy
- `services.health.status` showing dashy probe OK
- HTTP response from dash.ronny.works
- spine.verify passing

## Completion Criteria

- Dashy registered in all 4 spine bindings
- Container running and healthy on docker-host
- dash.ronny.works accessible
- spine.verify clean
