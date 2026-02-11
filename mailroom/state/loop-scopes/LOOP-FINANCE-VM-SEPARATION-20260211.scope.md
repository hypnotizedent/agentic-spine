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
| P0 | Register gap + loop | **DONE** |
| P1 | Control-plane bindings (proposal) | **DONE** |
| P2 | Provision VM + shadow deploy | **DONE** |
| P3 | Data migration + validation | **DONE** |
| P4 | Traffic cutover (cloudflared upstream switch) | **DONE** |
| P5 | Legacy cleanup (disable finance on docker-host) | PENDING |
| P6 | Verify + close | PENDING |

## P2 Evidence

**VM 211 provisioned**: `qm clone 9000 211 --full --storage local-lvm` + cloud-init (192.168.1.211/24)
**Specs**: 4 cores, 8GB RAM, 50GB disk, Ubuntu 24.04 (6.8.0-100-generic)
**Runtime**: Docker CE 29.2.1, Compose v5.0.2, Tailscale 1.94.1
**Tailscale IP**: 100.76.153.100
**Guest agent**: active
**LAN IP**: 192.168.1.211

### Shadow Deploy (7/7 containers healthy)

| Container | Status | Port | Smoke Test |
|-----------|--------|------|------------|
| firefly-postgres | healthy | 127.0.0.1:5434 | 3 DBs (firefly, ghostfolio, paperless) |
| firefly-redis | healthy | 127.0.0.1:6381 | PONG |
| firefly-iii | healthy | 0.0.0.0:8080 | HTTP 302 (redirect to login) |
| firefly-importer | healthy | 0.0.0.0:8091 | HTTP 200 |
| firefly-cron | running | — | cron scheduled |
| ghostfolio | running | 0.0.0.0:3333 | HTTP 301 |
| paperless-ngx | healthy | 0.0.0.0:8000 | HTTP 302 (redirect to login) |

### Validation Receipts

| Capability | Result | Receipt |
|-----------|--------|---------|
| docker.compose.status | **23/23 OK** (finance 7/7) | RCAP-20260211-144304__docker.compose.status__Rej0h96984 |
| services.health.status | OK (finance SKIP=disabled) | RCAP-20260211-144325__services.health.status__Rbcoa97766 |
| backup.status | **15/15 OK** | RCAP-20260211-144350__backup.status__Rixm298269 |
| spine.verify | **ALL PASS (D1-D68)** | RCAP-20260211-144409__spine.verify__Ryh7098942 |

### Proposals Applied

| Proposal | Commit | Scope |
|----------|--------|-------|
| CP-20260211-190056 (P1 control-plane) | 122cb4c | 6 bindings with placeholders |
| CP-20260211-194123 (P2 IP + enable) | aed01a1 | Replace PENDING_TAILSCALE_IP, enable compose |

## P3 Evidence

### Source Baselines (docker-host VM 200)

| Service | Metric | Count |
|---------|--------|-------|
| Firefly III | transaction_journals | 894 |
| Firefly III | accounts | 62 |
| Firefly III | transactions | 1788 |
| Ghostfolio | orders | 0 |
| Ghostfolio | accounts | 2 |
| Ghostfolio | symbol_profiles | 0 |
| Paperless-ngx | documents | 45 |
| Paperless-ngx | tags | 13 |
| Paperless-ngx | correspondents | 24 |
| Mail-archiver | tables | 0 (empty/fresh) |
| File data | total | ~88MB (Paperless media) |

### Migration Method

- **Databases**: `pg_dump` via SSH pipe from docker-host → `psql` restore on VM 211 (firefly, ghostfolio, paperless)
- **File data**: `tar | ssh` pipe from docker-host `/mnt/data/finance/` → VM 211 `/opt/stacks/finance/data/`
- **Mail-archiver**: Fresh deploy on VM 211 with isolated Postgres 17 DB (mail-archiver-db container, separate from finance postgres). Data-protection-keys transferred from docker-host.

### Post-Migration Counts (VM 211) — ALL MATCH

| Service | Metric | Source | Target | Match |
|---------|--------|--------|--------|-------|
| Firefly III | transaction_journals | 894 | 894 | YES |
| Firefly III | accounts | 62 | 62 | YES |
| Firefly III | transactions | 1788 | 1788 | YES |
| Ghostfolio | orders | 0 | 0 | YES |
| Ghostfolio | accounts | 2 | 2 | YES |
| Ghostfolio | symbol_profiles | 0 | 0 | YES |
| Paperless-ngx | documents | 45 | 45 | YES |
| Paperless-ngx | tags | 13 | 13 | YES |
| Paperless-ngx | correspondents | 24 | 24 | YES |
| Mail-archiver | EF migrations table | present | present | YES |

### VM 211 Final State (9/9 containers)

| Container | Status | Port | Smoke Test |
|-----------|--------|------|------------|
| firefly-postgres | healthy | 127.0.0.1:5434 | 3 DBs migrated |
| firefly-redis | healthy | 127.0.0.1:6381 | PONG |
| firefly-iii | healthy | 0.0.0.0:8080 | HTTP 302 |
| firefly-importer | healthy | 0.0.0.0:8091 | HTTP 200 |
| firefly-cron | running | — | cron scheduled |
| ghostfolio | running | 0.0.0.0:3333 | HTTP 301 |
| paperless-ngx | healthy | 0.0.0.0:8000 | HTTP 302 |
| mail-archiver | running | 0.0.0.0:5100 | HTTP 302 |
| mail-archiver-db | healthy | (internal) | MailArchiver DB ready |

## P4 Evidence

### Cutover Method

Updated cloudflared `extra_hosts` on infra-core (VM 204) to point finance service hostnames from docker-host (100.92.156.118) to finance-stack VM 211 (100.76.153.100):

| extra_host | Old IP | New IP |
|-----------|--------|--------|
| firefly-iii | 100.92.156.118 | 100.76.153.100 |
| ghostfolio | 100.92.156.118 | 100.76.153.100 |
| paperless-ngx | 100.92.156.118 | 100.76.153.100 |
| mail-archiver | 100.92.156.118 | 100.76.153.100 |

Backup saved: `/opt/stacks/cloudflared/docker-compose.yml.bak-pre-p4`

### Public URL Verification

| URL | HTTP Code | Status |
|-----|-----------|--------|
| https://finances.ronny.works/ | 302 | OK (login redirect) |
| https://docs.ronny.works/ | 302 | OK (login redirect) |
| https://investments.ronny.works/ | 301 | OK (HTTPS redirect) |
| https://mail-archive.ronny.works/ | 302 | OK (login redirect) |

### Health Probe Changes

- **Enabled**: firefly-iii-vm211, paperless-ngx-vm211, ghostfolio-vm211, mail-archiver-vm211
- **Legacy docker-host probes**: remain disabled (were already disabled due to localhost-binding)

## Rollback Criteria

- **P4 rollback trigger**: Any finance endpoint returns non-200 after cutover, OR data integrity check fails (transaction count mismatch, document count mismatch).
- **P4 rollback action**: Revert Caddy upstream to docker-host IPs. Finance on docker-host remains live until P5.
- **P5 guard**: Do NOT disable legacy finance until ≥1 hour soak with zero errors on new VM.

## Constraints

- Proposals workflow only (submit/apply with receipts)
- No Mint feature work
- No destructive cutover until shadow validation passes
- Governed commits: `fix(LOOP-FINANCE-VM-SEPARATION-20260211): ...` or `gov(...):`
