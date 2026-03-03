# Media Migration Lineage Checkpoint

> Carry-forward checkpoint linking split-era lessons to future migration execution.
> Authority: LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303
> Status: active (must be reviewed before any migration execution)
> Closes: GAP-OP-1406

## Purpose

This checkpoint exists to prevent future migration execution from repeating
known historical failure patterns. Any future media migration loop MUST
reference this document and explicitly address each lesson before promoting
execution_readiness from blocked to runnable.

## Source Loops (Lineage)

| Loop | Date | Key Lesson |
|------|------|------------|
| LOOP-MEDIA-STACK-SPLIT-20260208 | 2026-02-08 | VM 201 monolith split to VM 209/210; path assumptions changed at split time but not enforced |
| LOOP-MEDIA-STACK-ARCH-20260208 | 2026-02-08..10 | Boot ordering and network bridge hardening; cross-VM connectivity assumptions |
| LOOP-MEDIA-HISTORY-CANONICALIZATION-20260301 | 2026-03-01 | Historical reconstruction; 5 true, 1 false (Tubifarry adopted), 1 stale (sneakernet retired) |
| LOOP-MEDIA-MAINTAINERR-SEER-HUNTARR-RD-20260301 | 2026-03-01 | ARR/search pipeline remediation; Huntarr deprecated in favor of native search scheduler |
| LOOP-MEDIA-STACK-DISCONNECT-CANONICAL-TRACE-20260303 | 2026-03-03 | Forensic trace: contract-chain drift, not single-bug; path + status + verification gaps |

## Historical Failure Patterns (Must-Address)

### 1. Path Authority Drift (split-era origin)
**What happened**: During the VM 201 split, compose volume mounts were adjusted
but application-level root folder and download client paths were not normalized
end-to-end. Radarr root `/movies` diverged from compose mount `/media/movies`.

**Carry-forward requirement**: Future migration MUST define a 4-way path parity
tuple (compose mount, app root, downloader path, library path) BEFORE cutover.
See GAP-OP-1387, GAP-OP-1388, GAP-OP-1391, GAP-OP-1404.

### 2. Status Truth Split (post-split drift)
**What happened**: Jellyseerr requests remained `processing` while Radarr
reported `hasFile=true` and files existed on disk. No deterministic progression
model was enforced across services.

**Carry-forward requirement**: Future migration MUST define a canonical status
progression contract across Radarr, Jellyseerr, and Jellyfin. See GAP-OP-1389,
GAP-OP-1405.

### 3. Verification False Greens (ongoing)
**What happened**: Checks that rely on `hasFile=true` can pass while user-facing
playback/search remains broken due to path mismatches or library scan lag.

**Carry-forward requirement**: Future migration MUST include end-to-end
verification that traverses the full chain: Radarr state, filesystem access,
Jellyfin library scan, Jellyseerr request resolution. See GAP-OP-1392.

### 4. Queue Ghosting (post-split residue)
**What happened**: Completed downloads with `downloadClientUnavailable` status
remained in queue indefinitely, creating false active-work signals.

**Carry-forward requirement**: Future migration MUST include queue reconciliation
step in post-cutover verification. See GAP-OP-1390.

### 5. Rollback Target Loss
**What happened**: VM 201 was destroyed after split completion, leaving no
rollback target. All service entries in infra.relocation.plan.yaml have
`rollback_to: null`.

**Carry-forward requirement**: Future migration MUST maintain shop VMs in
provisioned state until post-cutover verification passes. Rollback window
must be explicit (24h per convention).

## Mandatory Pre-Execution Checklist

Future migration execution loops MUST verify:

- [ ] This lineage checkpoint has been read and acknowledged
- [ ] Each of the 5 historical failure patterns has an explicit mitigation
- [ ] Path authority contract exists and is enforced (GAP-OP-1404)
- [ ] Status progression contract exists and is enforced (GAP-OP-1405)
- [ ] E2E verification includes full-chain check (GAP-OP-1392)
- [ ] Queue reconciliation is part of post-cutover plan (GAP-OP-1390)
- [ ] Rollback target is maintained until verification passes
- [ ] All disconnect-trace gaps (GAP-OP-1387..1393) are resolved or explicitly deferred

## Gate Recommendation

A future gate (e.g., D33X) should enforce that this checkpoint was reviewed
by checking for an acknowledgment field in the migration execution loop scope.
