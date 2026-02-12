# LOOP-MINT-MINIO-ACCESS-CONTRACT-20260212

> **Status:** CLOSED
> **Opened:** 2026-02-12
> **Closed:** 2026-02-12
> **Owner:** Terminal C (apply-owner)

## Scope

Establish canonical MinIO access contract for mint-modules and operator macOS tooling.
Fix broken Finder mount. Standardize aliases. Define 14-day transition window.

## Hard Constraints

- No cutover or removal of old MinIO runtime
- No immediate alias deletion — deprecate-first
- Canonical Finder mount path: /Volumes/mintfiles
- Keep direct fallback alias for large uploads
- Transition policy: dual-read/single-write for 14 days

## Phases

- [x] P0: Baseline receipts (spine.verify, gaps.status, authority.project.status)
- [x] P1: Contract lock (bucket defaults, env/doc alignment, 14-day transition window)
- [x] P2: Mount reliability (fix LaunchAgent, macFUSE mount at /Volumes/mintfiles)
- [x] P3: Alias hygiene (canonical: mintfiles + mintfiles-direct; 5 aliases deprecated)
- [x] P4: Recert (mount active, both buckets visible, rclone/mc roundtrip, spine.verify PASS)

## Deliverables

- `mint-modules/docs/ARCHITECTURE/MINIO_ACCESS_CONTRACT.md` — authoritative contract
- `mint-modules/artwork/ingest/FINDER_MOUNT_SPEC.md` — updated, references contract
- LaunchAgent fixed: `~/Library/LaunchAgents/com.ronnyworks.minio-mount.plist`
- rclone remote added: `mintfiles-direct` (LAN direct)
- mc alias fixed: `mintfiles-direct` updated from 192.168.12.191 to 192.168.1.200
- Commit: `bf6b6cc` (mint-modules)

## Receipt IDs

| Phase | Receipt |
|-------|---------|
| P0 spine.verify | CAP-20260212-110523__spine.verify__R10nx52110 |
| P0 gaps.status | CAP-20260212-110550__gaps.status__Rrjz761729 |
| P0 authority.project.status | CAP-20260212-110550__authority.project.status__Rrt1161788 |
| P4 spine.verify | CAP-20260212-111409__spine.verify__Rjrjk62656 |
| P4 gaps.status | CAP-20260212-111436__gaps.status__R7qzm72296 |
| P4 authority.project.status | CAP-20260212-111436__authority.project.status__Rsu4972355 |
