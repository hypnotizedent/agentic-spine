---
status: active
owner: "@ronny"
created: 2026-02-11
scope: loop-scope
loop_id: LOOP-RUNTIME-RECONCILIATION-20260211
severity: high
---

# Loop Scope: LOOP-RUNTIME-RECONCILIATION-20260211

## Goal

Final runtime reconciliation after transition stabilization certification. Governance is clean (verify PASS, SSOT reconciled). This loop addresses runtime-level issues: unreachable hosts, stale compose paths, and app-level backup freshness.

## Problem / Current State

1. **docker-host (VM 200)**: Running but network-dead — no LAN ping (.200), no Tailscale (100.92.156.118), no QEMU guest agent. Cannot diagnose remotely.
2. **automation-stack (VM 202)**: Reachable but compose paths and SSH user were wrong.
3. **App-level backup freshness**: Restored. Firefly target corrected (disabled false path), all active app targets now green.

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Register loop + discovery | **DONE** |
| P1 | Fix automation-stack compose path drift | **DONE** |
| P2 | Register docker-host unreachability as gap | **DONE** |
| P3 | Restore app-level backup freshness | **DONE** |
| P4 | Run validation capabilities + close | ACTIVE (blocked on GAP-OP-096) |

## Fixes Applied

### P1: automation-stack (GAP-OP-097, fixed)
- `docker.compose.targets.yaml`: paths changed from `~/stacks/*` to `/home/automation/stacks/*`
- `ssh.targets.yaml`: user changed from `ubuntu` to `automation` (owns stacks + docker group)
- Verified: `docker compose ps` works via SSH as `automation` user

### P2: docker-host (GAP-OP-096, open)
- VM 200 running, balloon stats visible (96GB allocated, 84GB free) — guest OS alive
- NIC hardware OK: virtio on vmbr0, tap200i0 present on bridge
- ARP for 192.168.1.200 FAILED — guest not responding to ARP
- Serial console configured (serial0: socket) but requires interactive TTY
- **Requires PVE VNC console or physical access to diagnose**

### P3: App-level backup freshness (GAP-OP-098, fixed)
**Root cause**: infra-core lost DNS for `nas` hostname after `tailscale set --accept-dns=false` during UDR6 cutover. Rsync in backup scripts uses `ssh ronadmin@nas` which failed to resolve.

**Fixed**:
- Added `100.102.199.111 nas` to infra-core `/etc/hosts` and cloud-init template
- Infisical rsync: tested and confirmed synced to NAS (Feb 11 13:14)
- Vaultwarden rsync: tested and confirmed synced to NAS (Feb 11 13:14)
- Gitea rsync: tested as ubuntu user, confirmed synced to NAS (Feb 11 13:16)
- Firefly: `app-firefly` disabled in `backup.inventory.yaml` (NAS path doesn't exist)

**Current state**:
- Home Assistant backup refreshed (new `396c7bcc.tar` on NAS at 2026-02-11 13:20)
- Gitea cron restored as ubuntu user (`/etc/cron.d/gitea-backup`)
- `backup.status` now reports: **15 targets | 15 ok | 0 degraded**

## Gaps Registered

| Gap | Type | Status | Description |
|-----|------|--------|-------------|
| GAP-OP-096 | runtime-bug | **OPEN** | docker-host (VM 200) network unreachable |
| GAP-OP-097 | stale-ssot | **FIXED** | automation-stack path/user mismatch |
| GAP-OP-098 | stale-ssot | **FIXED** | App backup staleness + firefly path missing |

## Constraints

- No speculative edits — only fix what was observed via SSH
- Governed commits: `fix(LOOP-RUNTIME-RECONCILIATION-20260211): ...`
