# Media Stack RCA Decision Note

| Field | Value |
|-------|-------|
| Loop | `LOOP-MEDIA-STACK-RCA-20260205` |
| Generated | `2026-02-07T20:57Z` |
| Severity | high |

## Current State

**Media-stack is DOWN.** SSH probe to `100.117.1.53:22` timed out at 2026-02-07 ~20:57Z (live observation, not receipt-backed). This is consistent with the daily crash pattern described in the loop. Note: `host.drift.audit` (RCAP-20260207-130245) does not capture this timeout — it runs against governed SSH targets only, and `media-stack` is missing from `ssh.targets.yaml` (see GAP-OP-010).

## Root Causes (from loop evidence)

| # | Cause | Severity | Quick-Win? |
|---|-------|----------|-----------|
| 1 | SQLite on NFS causing database locks | HIGH | No — architectural (move DBs to local SSD) |
| 2 | Tailscale → NFS → Docker boot dependency race | HIGH | Partial — add `systemd` ordering |
| 3 | 32 containers on 16GB VM resource exhaustion | MEDIUM | Yes — disable Tdarr/Huntarr |
| 4 | Tdarr/downloads saturating NFS I/O | MEDIUM | Yes — reduce concurrency or disable |

## Quick-Win Assessment

**Quick wins are sufficient for stabilization.** Disabling Tdarr and Huntarr reduces container count and NFS I/O saturation — the two most immediate crash triggers. However, the SQLite-on-NFS issue remains a ticking time bomb and requires the architectural fix.

## Decision: Quick-Win First, Then Split

**Recommended approach (2-phase):**

1. **Immediate (when media-stack recoverable):** Disable Tdarr + Huntarr containers (`docker stop tdarr huntarr && docker update --restart=no tdarr huntarr`). This buys stability.

2. **Architecture loop (new):** Create `LOOP-MEDIA-STACK-ARCH-20260208` to plan and execute SQLite → local SSD migration + boot dependency ordering. This is too large for the current RCA loop scope.

## Split-Loop Recommendation

**YES — create split loop.** The RCA loop's scope is diagnosis + quick-wins. The architectural remediation (move databases to local SSD, restructure boot dependencies, right-size the VM) is a separate body of work with its own phases.

Proposed split:
- **LOOP-MEDIA-STACK-RCA-20260205** — close after quick-wins applied and stability confirmed over 24h
- **LOOP-MEDIA-STACK-ARCH-20260208** (new) — SQLite migration, boot ordering, VM right-sizing

## Blockers

| Blocker | Status | Mitigation |
|---------|--------|-----------|
| Media-stack unreachable | ACTIVE | Need physical/console recovery or wait for VM auto-restart |
| No SSH target in ssh.targets.yaml | GAP | Binding missing — needs to be added for governed access |

## Next Actions

1. **Recover media-stack** — console access via `pve` (shop Proxmox, `100.96.211.33`) or wait for restart cycle
2. **Apply quick-wins** — stop Tdarr + Huntarr, confirm stability
3. **Add ssh.targets.yaml binding** — `media-stack` missing from governed SSH targets
4. **Create arch loop** — scope the database migration + boot ordering work
5. **Close RCA loop** — after quick-wins confirmed stable for 24h
