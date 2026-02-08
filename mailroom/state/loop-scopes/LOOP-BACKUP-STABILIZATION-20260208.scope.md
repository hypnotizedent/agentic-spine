# LOOP-BACKUP-STABILIZATION-20260208

> **Status:** open
> **Blocked By:** none
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** medium

---

## Executive Summary

The infrastructure has grown from 5 VMs to 10, but the vzdump backup job on `pve` only covers VMs 200-204. VMs 205 (observability) and 206 (dev-tools) are running and unprotected. VMs 207, 209, 210 are provisioned or in-progress but also unprotected. Additionally, app-level backup targets (infisical, mint-postgres) are disabled, and the offsite sync to NAS shows `no_matches` (sync job broken).

This loop closes the backup coverage gap across all running VMs, wires app-level database backups, and repairs offsite sync.

---

## Current State

### vzdump Job Coverage (as of 2026-02-08)

| VM | Name | Status | In vzdump? | In binding? |
|----|------|--------|------------|-------------|
| 200 | docker-host | running | YES | enabled |
| 202 | (legacy) | running | YES | enabled |
| 203 | (legacy) | running | YES | enabled |
| 204 | infra-core | running | YES | enabled |
| 205 | observability | running | **NO** | enabled |
| 206 | dev-tools | running | **NO** | enabled |
| 207 | ai-consolidation | provisioned | **NO** | disabled |
| 209 | download-stack | provisioned | **NO** | disabled |
| 210 | streaming-stack | provisioned | **NO** | disabled |

### App-Level Backup Gaps

| Target | Binding Status | Actual Status |
|--------|---------------|---------------|
| app-infisical | disabled | No pg_dump cron exists |
| app-mint-postgres | disabled | Legacy — evaluate if needed |
| app-vaultwarden | enabled | Needs verification |

### Offsite Sync

| Target | Status |
|--------|--------|
| vm-200-docker-host-offsite | `no_matches` (NAS path may not exist) |

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Audit current vzdump job (read-only) | None | **done** |
| P1 | Add running VMs 205, 206 to vzdump job | P0 | **done** (prior session) |
| P2 | Add VMs 207, 209, 210 to vzdump job | Per-VM deployment | **done** |
| P3 | App-level backups (infisical pg_dump, vaultwarden tar) | P1 | **done** |
| P4 | Offsite sync (pve → NAS over Tailscale) | P1 | **done** |
| P5 | Verify + closeout | P3 + P4 | pending (wait 24h for first run) |

---

## Phase Details

### P0 — Audit current vzdump job (read-only)

SSH to pve and capture baseline:
- `cat /etc/pve/jobs.cfg` to confirm which VMIDs are in the job
- `ls -lt /tank/backups/vzdump/dump/ | head -20` to verify recent backups exist
- Run `ops cap run backup.status` to get current inventory health
- Document baseline state

**Deliverable:** Baseline receipt with vzdump job config and recent backup file listing.

### P1 — Add running VMs to vzdump job

- SSH to pve, edit `/etc/pve/jobs.cfg` to add VMIDs 205, 206
- These VMs are running, deployed, and have `enabled: true` in the binding
- Wait 24h, verify backup files appear in `/tank/backups/vzdump/dump/`
- Run `ops cap run backup.status` — VM 205 and 206 targets should show OK

### P2 — Enable future VMs as they stabilize

Gating checklist (not a single action — execute as each VM is deployed):

| VM | Condition | Actions |
|----|-----------|---------|
| 207 (AI) | LOOP-AI-CONSOLIDATION-20260208 reaches P1+ | Add to vzdump job, flip `enabled: true` in binding |
| 209 (download-stack) | LOOP-MEDIA-STACK-SPLIT-20260208 reaches P2+ | Add to vzdump job, flip `enabled: true` in binding |
| 210 (streaming-stack) | LOOP-MEDIA-STACK-SPLIT-20260208 reaches P3+ | Add to vzdump job, flip `enabled: true` in binding |

### P3 — App-level backup gaps

| Target | Action |
|--------|--------|
| Infisical | Create pg_dump cron on infra-core, push dumps to NAS `/volume1/backups/apps/infisical/`. Flip `enabled: true` in binding. |
| Mint-postgres | Evaluate if VM 200 still runs a postgres instance worth backing up. If yes, wire pg_dump. If no, remove target from binding. |

### P4 — Offsite sync repair

- Diagnose NAS offsite sync (vm-200 offsite target shows `no_matches`)
- Verify NAS path `/volume1/backups/proxmox/vzdump` exists and has content
- Fix or re-create rsync/Hyper Backup job from pve → NAS
- Add offsite targets for critical VMs (204, 207) once onsite backups are stable

### P5 — Verify + closeout

- `ops cap run backup.status` — all enabled targets must show OK (not STALE/MISSING)
- D19 drift gate passes
- No STALE targets over threshold (26h critical, 48h important)
- Close loop

---

## Classification Reference (from binding)

| Classification | Threshold | VMs / Targets |
|----------------|-----------|---------------|
| critical | 26h | infra-core (204), AI (207), vaultwarden, macbook |
| important | 48h | observability (205), dev-tools (206), download-stack (209), streaming-stack (210) |
| rebuildable | 168h | _(none currently)_ |

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| All running VMs in vzdump job | `/etc/pve/jobs.cfg` includes 200-206 |
| `backup.status` reports 0 degraded | All enabled targets show OK |
| Infisical app backup operational | pg_dump cron running, files appear on NAS |
| Offsite sync functional | vm-200-docker-host-offsite target shows OK (not no_matches) |
| D19 drift gate passes | `ops verify` includes D19 PASS |

---

## Non-Goals

- Do NOT change backup retention policy (keep current vzdump retention settings)
- Do NOT set up cross-site replication beyond NAS offsite sync
- Do NOT back up VMs that haven't been deployed yet (207, 209, 210 wait for their loops)
- Do NOT change backup schedules (keep daily vzdump cadence)

---

## Evidence

- `ops/bindings/backup.inventory.yaml` — current target definitions
- `surfaces/verify/d19-backup-drift.sh` — backup drift gate
- `ops/plugins/backup/bin/backup-status` — backup status capability
- Memory: "vzdump only covers VMs 200-204 — gap: 205-210 not backed up"

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-08_
