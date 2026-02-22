---
status: draft
owner: "@ronny"
created: 2026-02-22
scope: mint-tunnel-migration-plan-gate1
loop_id: LOOP-MINT-TUNNEL-MIGRATION-CONTRACT-20260222
---

# MINT Tunnel Migration Plan (Gate 1)

Contract-only artifact. No tunnel mutation.

Evidence:
- Live ingress inventory: `CAP-20260222-001201__cloudflare.tunnel.ingress.status__Rmdsb11941`
- Legacy tunnel deployment locus: `/Users/ronnyworks/ronny-ops/infrastructure/cloudflare/tunnel/docker-compose.yml:3-24`
- V1 route/scope constraints: `/Users/ronnyworks/code/mint-modules/docs/ARCHITECTURE/V1_SCOPE_AND_ROUTE_CANON.md:14-33`

## Route-by-route migration matrix

| route | current target (observed) | target after migration | prerequisite gate | cutover state |
|---|---|---|---|---|
| `pricing.mintprints.co` | `http://100.79.183.14:3700` | `pricing@mint-apps:3700` | Rank 1 Gate 5 | done |
| `shipping.mintprints.co` | `http://100.79.183.14:3900` | `shipping@mint-apps:3900` | Rank 2 Gate 5 | done |
| `customer.mintprints.co` | `http://quote-page:3341` | `quote-page@mint-apps:3341` (explicit host:port) | V1 quote-form continuity | pending (alias disambiguation) |
| `mintprints-app.ronny.works` | `http://quote-page:3341` | `quote-page@mint-apps:3341` (explicit host:port) | V1 quote-form continuity | pending (alias disambiguation) |
| `files.mintprints.co` | `http://mint-os-minio:9000` | `minio@mint-data:9000` | data-plane bucket parity proof | pending |
| `minio.mintprints.co` | `http://mint-os-minio:9001` | `minio-console@mint-data:9001` | data-plane bucket parity proof | pending |
| `estimator.mintprints.co` | `http://100.79.183.14:3700` | `pricing@mint-apps:3700` | Route cutover complete 2026-02-22 | done |
| `api.mintprints.co` | `http://mint-os-dashboard-api:3335` | `UNVERIFIED` (future order/auth/payment API gateway surface) | Rank 5+7 Gate 5 | blocked |
| `admin.mintprints.co` | `http://mint-os-admin:3333` | `UNVERIFIED` (future admin surface) | Rank 5 + order lifecycle readiness | blocked |
| `production.mintprints.co` | `http://mint-os-production:3336` | `UNVERIFIED` (future production/workforce surface) | Rank 5 workforce auth + lifecycle readiness | blocked |
| `production.ronny.works` | `http://mint-os-production:3336` | `UNVERIFIED` | same as above | blocked |
| `kanban.mintprints.co` | `http://mint-os-kanban:3337` | `UNVERIFIED` | order lifecycle extraction | blocked |
| `kanban.ronny.works` | `http://100.92.156.118:3337` | `UNVERIFIED` | order lifecycle extraction | blocked |
| `mintprints-api.ronny.works` | `http://mint-os-dashboard-api:3335` | `UNVERIFIED` | Rank 5+7 Gate 5 | blocked |
| `stock-dst.mintprints.co` | `http://100.92.156.118:8765` | `UNVERIFIED` (suppliers/stock contract pending) | Rank 3 suppliers Gate 5 | blocked |

## Dependency-grouped cutover order

1. `already_complete`
- `pricing.mintprints.co`
- `shipping.mintprints.co`

2. `v1_quote_surface_normalization`
- `customer.mintprints.co`
- `mintprints-app.ronny.works`
- action: replace service alias targets with explicit `mint-apps` host:port endpoints.

3. `data_plane_storage_cutover`
- `files.mintprints.co`
- `minio.mintprints.co`
- action: require MinIO parity/restore evidence before switching legacy host references.

4. `post_rank5_plus_cutover`
- `api.mintprints.co`
- `admin.mintprints.co`
- `production.mintprints.co`
- `production.ronny.works`
- `mintprints-api.ronny.works`
- action: only after Auth (Rank 5), Payment (Rank 6), Order Lifecycle (Rank 7) Gate 5 completion.

5. `deprecation_or_contract_pending`
- ~~`estimator.mintprints.co`~~ (done — cutover to pricing@mint-apps:3700, 2026-02-22)
- `kanban.mintprints.co`
- `kanban.ronny.works`
- `stock-dst.mintprints.co`
- action: explicit module deprecation/extraction contract required before route movement.

## Operational notes

- Tunnel process is still hosted from legacy stack context (`docker-compose.yml` under legacy infra path).
- Migration objective is ingress-target replacement and route ownership normalization first; tunnel-runtime relocation is a separate infra step.

## Gate 1 outcome

- Route migration dependency order is defined.
- All blocked routes are explicitly tied to prerequisite module gates; no speculative cutovers permitted.
