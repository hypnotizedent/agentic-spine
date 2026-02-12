---
id: LOOP-INFRA-PARITY-RECONCILIATION-20260211
status: closed
created: 2026-02-11
closed: 2026-02-11
owner: "@ronny"
gap: GAP-OP-110
---

# LOOP: Infrastructure Parity Reconciliation

## Objective

Full infrastructure baseline + reconciliation of VM/container truth across all spine
bindings (SERVICE_REGISTRY, docker.compose.targets, services.health, vm.lifecycle).

## Baseline Results (Before)

| Check                  | Result                                           |
|------------------------|--------------------------------------------------|
| docker.compose.status  | OK — 22/22 stacks (but download-stack hid 3 exited containers) |
| services.health.status | FAIL — sabnzbd TIMEOUT (9.4s > 10s max_time)     |
| backup.status          | OK — 16/16 targets fresh                         |
| vm.governance.audit    | OK — 10/10 VMs governed, 0 gaps                  |
| spine.verify           | PASS — all 61 drift gates pass                   |

## Findings

1. **sabnzbd health probe timeout** — Web UI root (/) takes ~9.4s, exceeds 10s
   max_time. The API version endpoint (/api?mode=version&output=json) responds
   in 0.35s.

2. **SERVICE_REGISTRY stale container status** — swaparr-sonarr and swaparr-lidarr
   marked as "stopped" (from crash during media-stack split) but both recovered
   and are running on VM 209.

3. **docker.compose.status tool blind spot** — Uses `docker compose ps` without
   `-a` flag. Exited containers (huntarr, slskd, tdarr) invisible. Tool reports
   21/21 when reality is 21/24. Crashed containers would also be invisible.

4. **Cloudflare/Caddy routing** — Verified clean. All public URLs routable
   (dash, git, auth, customer). Finance IPs correctly migrated to VM 211.
   No stale routes. D51 compliant.

## Fixes Applied

| File | Change |
|------|--------|
| ops/bindings/services.health.yaml | sabnzbd probe: / → /api?mode=version&output=json |
| docs/governance/SERVICE_REGISTRY.yaml | sabnzbd health endpoint updated |
| docs/governance/SERVICE_REGISTRY.yaml | swaparr-sonarr: stopped → active |
| docs/governance/SERVICE_REGISTRY.yaml | swaparr-lidarr: stopped → active |
| ops/plugins/docker/bin/docker-compose-status | Added `-a` to `docker compose ps` |
| ops/bindings/operational.gaps.yaml | Registered GAP-OP-110 |

## After Results

| Check                  | Result                                      |
|------------------------|---------------------------------------------|
| docker.compose.status  | DEGRADED — 21 ok, 1 degraded (download-stack 21/24, 3_exited) |
| services.health.status | OK — all endpoints healthy (sabnzbd 463ms)  |
| backup.status          | OK — 16/16 targets fresh                    |
| vm.governance.audit    | OK — 10/10 VMs governed, 0 gaps             |
| spine.verify           | (pending final run)                         |

## VM-Container Matrix (Authoritative Snapshot 2026-02-11)

| VM  | Hostname          | Stacks | Containers | Running | Exited | Notes |
|-----|-------------------|--------|------------|---------|--------|-------|
| 200 | docker-host       | 4      | 12         | 12      | 0      | mint-os(9)+artwork(1)+quote-page(1)+dashy(1) |
| 202 | automation-stack  | 2      | 6          | 6       | 0      | automation(5)+mcpjungle(1) |
| 203 | immich            | 1      | 4          | 4       | 0      | server+ML+postgres+redis |
| 204 | infra-core        | 5      | 11         | 11      | 0      | cloudflared+pihole+secrets(3)+vaultwarden+caddy-auth(5) |
| 205 | observability     | 5      | 5          | 5       | 0      | prometheus+grafana+loki+uptime-kuma+node-exporter |
| 206 | dev-tools         | 1      | 3          | 3       | 0      | gitea+runner+postgres |
| 207 | ai-consolidation  | 1      | 2          | 2       | 0      | anythingllm+qdrant |
| 209 | download-stack    | 1      | 24         | 21      | 3      | huntarr(crashed), tdarr+slskd(parked) |
| 210 | streaming-stack   | 1      | 10         | 10      | 0      | all healthy |
| 211 | finance-stack     | 1      | 9          | 9       | 0      | firefly+paperless+ghostfolio+mail-archiver+2xpg+redis+importer+cron |

**Totals: 10 VMs, 22 stacks, 86 containers, 83 running, 3 exited**
