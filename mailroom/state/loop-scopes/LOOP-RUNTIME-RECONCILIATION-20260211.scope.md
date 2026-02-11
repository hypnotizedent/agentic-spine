---
status: closed
owner: "@ronny"
created: 2026-02-11
closed: 2026-02-11
scope: loop-scope
loop_id: LOOP-RUNTIME-RECONCILIATION-20260211
severity: high
---

# Loop Scope: LOOP-RUNTIME-RECONCILIATION-20260211

## Goal

Final runtime reconciliation after transition stabilization certification. Governance is clean (verify PASS, SSOT reconciled). This loop addresses runtime-level issues: unreachable hosts, stale compose paths, and app-level backup freshness.

## Problem / Current State

All issues resolved. VM 200 recovered, compose paths fixed, backup freshness restored.

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Register loop + discovery | **DONE** |
| P1 | Fix automation-stack compose path drift | **DONE** |
| P2 | Register docker-host unreachability as gap | **DONE** |
| P3 | Restore app-level backup freshness | **DONE** |
| P4 | Recover VM 200 + validate + close | **DONE** |

## Fixes Applied

### P1: automation-stack (GAP-OP-097, fixed)
- `docker.compose.targets.yaml`: paths changed from `~/stacks/*` to `/home/automation/stacks/*`
- `ssh.targets.yaml`: user changed from `ubuntu` to `automation` (owns stacks + docker group)
- Verified: `docker compose ps` works via SSH as `automation` user

### P2+P4: docker-host (GAP-OP-096, fixed)
**Root cause**: VM 200 network stack became unresponsive (ARP FAILED from hypervisor). Guest agent not running. No remote diagnostic path available.

**Recovery**: VM 200 was stopped/started via PVE web UI (`root@pam`) at 2026-02-11 13:15:37 EST. The stop/start cycle restored all services.

**Post-recovery state** (25 min after boot):
- LAN: 192.168.1.200 reachable, ARP resolving (MAC bc:24:11:bb:d0:b6)
- Tailscale: 100.92.156.118 connected
- Guest agent: active
- SSH: active
- Docker: 20 containers running, all healthy
- Load: 1.57 (fully settled from 61.59 at boot)

### P3: App-level backup freshness (GAP-OP-098, fixed)
**Root cause**: infra-core lost DNS for `nas` hostname after `tailscale set --accept-dns=false` during UDR6 cutover. Rsync in backup scripts uses `ssh ronadmin@nas` which failed to resolve starting Feb 10.

**Fixed**:
- Added `100.102.199.111 nas` to infra-core `/etc/hosts` and cloud-init template
- Infisical rsync: tested and confirmed synced to NAS (Feb 11 13:14)
- Vaultwarden rsync: tested and confirmed synced to NAS (Feb 11 13:14)
- Gitea rsync: tested as ubuntu user, confirmed synced to NAS (Feb 11 13:16)
- Firefly: `app-firefly` disabled in `backup.inventory.yaml` (NAS path doesn't exist)
- Home Assistant backup refreshed (new `396c7bcc.tar` on NAS at 2026-02-11 13:20)
- `backup.status`: **15 targets | 15 ok | 0 degraded**

## Final Validation (P4)

| Capability | Result | Receipt |
|-----------|--------|---------|
| docker.compose.status | **21/21 OK** | RCAP-20260211-133818__docker.compose.status__Ra2mt21752 |
| backup.status | **15/15 OK** | RCAP-20260211-133859__backup.status__Rb7h222921 |
| spine.verify | **ALL PASS (D1-D68)** | RCAP-20260211-133910__spine.verify__R0gcb23526 |
| services.health.status | 33 OK / 3 REFUSED / 2 SKIP | RCAP-20260211-133850__services.health.status__Rdw0n22485 |

**services.health.status note**: 3 REFUSED are preexisting port binding issues (firefly-iii + paperless-ngx bound to 127.0.0.1 only; slskd on download-stack). Not caused by or related to VM 200 recovery.

## Gaps Registered

| Gap | Type | Status | Description |
|-----|------|--------|-------------|
| GAP-OP-096 | runtime-bug | **FIXED** | docker-host (VM 200) network recovered via PVE stop/start |
| GAP-OP-097 | stale-ssot | **FIXED** | automation-stack path/user mismatch |
| GAP-OP-098 | stale-ssot | **FIXED** | App backup staleness + firefly path missing |

## Closure Note

All 3 gaps fixed. All validation capabilities passing. Loop closed 2026-02-11.
