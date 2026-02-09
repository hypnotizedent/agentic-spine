# LOOP-INFRA-VM-RESTRUCTURE-20260206

> **Status:** COMPLETE
> **Closed:** 2026-02-08
> **Owner:** @ronny
> **Created:** 2026-02-06
> **Severity:** high

---

## Executive Summary

Restructure the shop infrastructure by decomposing services off the monolithic `docker-host` (VM 200) into purpose-built VMs on pve (shop R730XD). This loop provisioned VMs 204 (infra-core), 205 (observability), and 206 (dev-tools), migrated core infrastructure services, and established the foundation for all subsequent VM-based deployments.

**Why this matters for agents:** Before this restructure, nearly all infrastructure services ran on `docker-host` (VM 200). After this loop, docker-host retains ONLY Mint OS business workloads. All infrastructure, monitoring, and dev tooling now lives on dedicated VMs. If an agent reads `INFRASTRUCTURE_MAP.md` or legacy workbench docs that reference services on `docker-host`, those references are stale unless they describe Mint OS (API, Postgres, MinIO, Redis).

---

## Migration Map (What Moved Where)

### docker-host (VM 200) → infra-core (VM 204)

| Service | Old Location | New Location | Port | Notes |
|---------|-------------|--------------|------|-------|
| cloudflared | docker-host | infra-core | host network | CF tunnel daemon; `network_mode: host` required |
| pihole | docker-host (:80) | infra-core (:8053) | 8053 | Port changed to free :80 for Caddy |
| infisical | docker-host | infra-core | 8088 (internal), 443 (via Caddy) | Secrets management |
| vaultwarden | docker-host | infra-core | 8081 | Password vault; fronted by Caddy+Authentik |

### New deployments on infra-core (VM 204)

| Service | Port | Notes |
|---------|------|-------|
| caddy | 80 (host network) | Reverse proxy + forward auth; deployed in LOOP-INFRA-CADDY-AUTH-20260207 |
| authentik (server+worker) | 9000, 9443 | SSO/auth provider; deployed in LOOP-INFRA-CADDY-AUTH-20260207 |
| authentik postgres | 5432 (internal) | Authentik database |
| authentik redis | 6379 (internal) | Authentik cache |

### Fresh deployments on observability (VM 205)

| Service | Port | Notes |
|---------|------|-------|
| prometheus | 9090 | Metrics collection (was never properly deployed on docker-host) |
| grafana | 3000 | Dashboards; deployed in LOOP-OBSERVABILITY-DEPLOY-20260208 |
| loki | 3100 | Log aggregation |
| uptime-kuma | 3001 | Uptime monitoring |
| node-exporter | 9100 | Host metrics |

### Fresh deployments on dev-tools (VM 206)

| Service | Port | Notes |
|---------|------|-------|
| gitea | 3000 (HTTP), 2222 (SSH) | Git forge; deployed in LOOP-DEV-TOOLS-DEPLOY-20260208 |
| gitea runner | — | CI runner; labels=[ubuntu-latest, ubuntu-24.04, ubuntu-22.04] |
| gitea postgres | 5432 (internal) | Gitea database |

---

## What REMAINS on docker-host (VM 200)

After this restructure, docker-host exclusively runs **Mint OS business workloads**:

| Service | Port | Purpose |
|---------|------|---------|
| mint-os-dashboard-api | 3335 (mapped from 3456) | Business API |
| mint-os-postgres | 15432 | Business database |
| mint-os-redis | 16379 | Business cache |
| minio | 9000, 9001 | File storage (standalone in `infrastructure/storage/`) |
| mint-os-job-estimator | 3001 | Pricing calculator |
| mint-os-admin | — | Admin UI container |
| mint-os-customer | — | Customer portal container |
| mint-os-production | — | Production portal container |
| finance stack | — | Firefly III + related |

**Rule:** No new infrastructure services should be deployed on docker-host. All infra goes to purpose-built VMs.

---

## VM Provisioning Summary

All VMs created from template 9000 (`ubuntu-2404-cloudinit-template`) using `spine-ready-v1` profile.

| VM ID | Hostname | Tailscale IP | LAN IP | Resources | Purpose |
|-------|----------|-------------|--------|-----------|---------|
| 204 | infra-core | 100.92.91.128 | 192.168.12.128 | 8GB RAM, 50GB disk, 4 cores | Core infra services |
| 205 | observability | 100.120.163.70 | 192.168.12.70 | 8GB RAM, 50GB disk, 4 cores | Monitoring + logging |
| 206 | dev-tools | 100.90.167.39 | 192.168.12.206 | 8GB RAM, 50GB disk, 4 cores | Git forge + CI |

---

## Child / Follow-on Loops

| Loop | Relationship | Status |
|------|-------------|--------|
| LOOP-INFRA-CADDY-AUTH-20260207 | Deployed Caddy + Authentik on infra-core | Complete |
| LOOP-OBSERVABILITY-DEPLOY-20260208 | Deployed monitoring stack on VM 205 | Complete |
| LOOP-AI-CONSOLIDATION-20260208 | AI services to VM 207 (Qdrant, AnythingLLM) | Complete |
| LOOP-MEDIA-STACK-SPLIT-20260208 | Media from VM 201 to VMs 209, 210 | Open (P6 soak) |
| LOOP-AUDIT-WORKBENCH-SYNC-20260208 | Clean up stale workbench refs to pre-restructure state | Open |

---

## Cloudflare Tunnel Updates

All CF tunnel routes updated to point through infra-core's Caddy (:80):

| Hostname | Old Target | New Target |
|----------|-----------|------------|
| pihole.ronny.works | docker-host:80 | infra-core:80 (Caddy → :8053) |
| vault.ronny.works | docker-host:8081 | infra-core:80 (Caddy → :8081) |
| secrets.ronny.works | docker-host:8088 | infra-core:80 (Caddy → :8088) |
| auth.ronny.works | — (new) | infra-core:80 (Caddy → :9000) |
| grafana.ronny.works | — (new) | observability:3000 |
| git.ronny.works | — (new) | dev-tools:3000 |

---

## NFS / Storage

docker-host retains its NFS mounts for Mint OS data:
- `192.168.12.184:/tank/docker → /mnt/docker` (rw)
- `192.168.12.184:/tank/backups → /mnt/backups` (rw)

New VMs use stack-specific ZFS datasets (no shared NFS with docker-host).

---

## SSOT Documents Updated

All authoritative documents were updated as part of this restructure:
- `docs/governance/DEVICE_IDENTITY_SSOT.md` — VM entries added
- `docs/governance/SERVICE_REGISTRY.yaml` — service locations updated
- `docs/governance/STACK_REGISTRY.yaml` — new stacks registered
- `ops/bindings/ssh.targets.yaml` — SSH targets for new VMs
- `ops/bindings/services.health.yaml` — health probes for new services
- `ops/bindings/docker.compose.targets.yaml` — compose targets updated
- `ops/bindings/infra.relocation.plan.yaml` — relocation state tracked

---

## Known Post-Restructure Gaps

| Gap | Description | Status |
|-----|-------------|--------|
| LOOP-AUDIT-WORKBENCH-SYNC-20260208 | 23 stale workbench artifacts still reference docker-host for migrated services | Open |
| docker-host NFS uses Tailscale IP | fstab had `100.96.211.33` instead of LAN IP `192.168.12.184` — causes D-state deadlocks when Tailscale flaps | Fixed 2026-02-08 |
| INFRASTRUCTURE_MAP.md stale | Historical import still shows all services on docker-host | Noted (workbench-owned) |

---

## Success Criteria (All Met)

| Criteria | Validation |
|----------|------------|
| VMs 204, 205, 206 provisioned | SSH reachable, Tailscale joined |
| cloudflared on infra-core | CF tunnel connected, all routes working |
| pihole on infra-core | DNS resolution working, admin UI accessible |
| infisical on infra-core | API healthy, secrets accessible |
| vaultwarden on infra-core | Vault accessible, data migrated |
| Monitoring on observability | Prometheus scraping, Grafana dashboards loading |
| Gitea on dev-tools | Repos mirrored, runner active |
| CF tunnel routes updated | All external URLs resolve to new VMs |
| Drift gates passing | 47/47 PASS on `ops verify` |

---

_Scope document backfilled by: Opus 4.6_
_Created: 2026-02-06_
_Closed: 2026-02-08_
_Backfilled: 2026-02-08 (scope doc was missing; migration details reconstructed from SSOT docs, memory, and relocation plan)_
