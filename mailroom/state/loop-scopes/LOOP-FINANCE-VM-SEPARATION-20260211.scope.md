---
status: active
owner: "@ronny"
created: 2026-02-11
scope: loop-scope
loop_id: LOOP-FINANCE-VM-SEPARATION-20260211
severity: high
---

# Loop Scope: LOOP-FINANCE-VM-SEPARATION-20260211

## Goal

Separate the finance runtime (Firefly III, Paperless-ngx, Ghostfolio) from the legacy docker-host (VM 200) onto a dedicated, governed VM. This improves isolation, maintainability, and aligns finance with the spine-native provisioning model (cloud-init, governed bindings, dedicated backup target).

## Current State

Finance stack runs on docker-host (VM 200) — a legacy host with no cloud-init, shared with mint-os production storefronts.

| Service | Container | Port | Public URL |
|---------|-----------|------|------------|
| Firefly III | firefly-iii | 127.0.0.1:8090 | https://finances.ronny.works |
| Firefly Importer | firefly-importer | 0.0.0.0:8091 | (internal) |
| Firefly Cron | firefly-cron | — | (internal) |
| Paperless-ngx | paperless-ngx | 127.0.0.1:8092 | https://docs.ronny.works |
| Ghostfolio | ghostfolio | 127.0.0.1:3340 | https://portfolio.ronny.works |
| PostgreSQL 16 | firefly-postgres | 127.0.0.1:5434 | (internal) |
| Redis 7 | firefly-redis | 127.0.0.1:6381 | (internal) |

**Data**: ~88MB on local disk (`/mnt/data/finance/`), primarily Paperless media.
**Routing**: CF tunnel → infra-core Caddy → docker-host ports.
**Secrets**: `.env` on docker-host, backed by Infisical `/spine/vm-docker-host/finance/`.

## Target State

| Field | Value |
|-------|-------|
| VM ID | 211 |
| Hostname | finance-stack |
| IP | 192.168.1.211 |
| User | ubuntu |
| Template | 9000 (ubuntu-2404-cloudinit-template) |
| Specs | 4 cores, 8GB RAM, 50GB disk |
| Stack path | /opt/stacks/finance |
| Data path | /opt/stacks/finance/data |

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Register gap + loop | ACTIVE |
| P1 | Control-plane bindings (proposal) | PENDING |
| P2 | Provision VM + shadow deploy | PENDING |
| P3 | Data migration + validation | PENDING |
| P4 | Traffic cutover (Caddy upstream switch) | PENDING |
| P5 | Legacy cleanup (disable finance on docker-host) | PENDING |
| P6 | Verify + close | PENDING |

## Rollback Criteria

- **P4 rollback trigger**: Any finance endpoint returns non-200 after cutover, OR data integrity check fails (transaction count mismatch, document count mismatch).
- **P4 rollback action**: Revert Caddy upstream to docker-host IPs. Finance on docker-host remains live until P5.
- **P5 guard**: Do NOT disable legacy finance until ≥1 hour soak with zero errors on new VM.

## Constraints

- Proposals workflow only (submit/apply with receipts)
- No Mint feature work
- No destructive cutover until shadow validation passes
- Governed commits: `fix(LOOP-FINANCE-VM-SEPARATION-20260211): ...` or `gov(...):`
