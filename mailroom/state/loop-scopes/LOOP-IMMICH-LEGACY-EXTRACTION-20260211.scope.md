---
status: active
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-IMMICH-LEGACY-EXTRACTION-20260211
severity: high
---

# Loop Scope: LOOP-IMMICH-LEGACY-EXTRACTION-20260211

## Goal

Extract critical Immich operational knowledge from legacy source into spine-native governed docs before legacy source becomes unavailable. Promote only spine-compatible outputs per `docs/core/EXTRACTION_PROTOCOL.md`.

## Problem / Current State (2026-02-11)

- Immich (VM 203) is a running service with 135K+ assets (3TB library) and 4 users.
- Spine has device identity, VM-level backup targets, and secrets namespace for Immich.
- Spine has **zero** app-level operational coverage: no backup/restore procedures, no deduplication governance, no service registry entry, no health check, no compose target.
- All app-level operational knowledge exists only in legacy `ronny-ops/immich/` (commit `1ea9dfa`).
- Daily PostgreSQL backup script on VM may reference legacy path — silent failure risk.
- The previous media legacy extraction loop (`LOOP-MEDIA-LEGACY-EXTRACTION-20260211`) covered media-stack (VM 209/210) but not Immich (VM 203). That loop is now closed.
- Legacy local path `~/ronny-ops` was removed for D30 compliance. Remote source: `https://github.com/hypnotizedent/ronny-ops.git`.

## Extraction Contract (No Garbage Import)

- Follow `docs/core/EXTRACTION_PROTOCOL.md`:
  - Move A first (doc-only snapshot and rewrite).
  - Move B only for small, clean, governed wrappers.
- No direct runtime dependency on legacy source.
- No blind copy/paste of legacy markdown or scripts.
- Every promoted artifact must include: owner, authority/scope, verification method, receipts.

## Extraction Matrix Reference

Full extraction matrix with coverage analysis, loss-if-deleted report, and extraction decisions:
`docs/governance/IMMICH_LEGACY_EXTRACTION_MATRIX.md`

## Classification

**Recommended:** Upgrade Immich from Utility to Stack in `EXTRACTION_PROTOCOL.md`.

Justification: 4 containers, 3TB data, custom backup topology (pg_dump + library rsync + offsite), deduplication governance (THE RULE), multi-user management, planned MCP tooling. Decision tree evaluates to STACK (3-10 containers, lessons + runbook needed).

## Success Criteria

- 2 spine-native docs created: `IMMICH_BACKUP_RESTORE.md` + `IMMICH_OPERATIONS_LESSONS.md`
- 3 registry entries added: SERVICE_REGISTRY, STACK_REGISTRY, services.health
- Classification updated in EXTRACTION_PROTOCOL.md
- Extraction matrix governs all dispositions
- Cron path verified on immich-1 VM
- `spine.verify` passes

## Phases

- P0: COMPLETE -- Terminal D audit: inventory legacy artifacts, assess spine coverage, produce extraction matrix.
- P1: BLOCKED (GAP-OP-094) -- Cron path verification blocked by VM 203 network isolation. VM running per Proxmox but unreachable on all paths (LAN, Tailscale, guest agent). Registered GAP-OP-094. P1 resumes after VM network is restored via VNC console. P2 docs can proceed independently (legacy source is sufficient for spine-native rewrite).
- P2: COMPLETE -- Spine-native docs created: `IMMICH_BACKUP_RESTORE.md` + `IMMICH_OPERATIONS_LESSONS.md` (commit 3c06216).
- P3: COMPLETE -- Registry entries added: SERVICE_REGISTRY (4 services + host), STACK_REGISTRY (stack entry), services.health (probe, disabled until GAP-OP-094 fixed). Classification upgraded Utility->Stack in EXTRACTION_PROTOCOL.md.
- P4: PENDING -- Validate (`spine.verify`) and close with receipt-linked summary.

## P1 Evidence (2026-02-11)

Cron verification attempted via 4 access paths, all failed:
1. `ssh ronny@immich-1` — Tailscale hostname timeout
2. `ssh ubuntu@192.168.1.203` — Network unreachable (not on shop LAN)
3. `ssh -J root@pve ronny@192.168.1.203` — No route to host
4. `qm guest exec 203` — QEMU guest agent not running

Diagnostic findings from pve:
- `qm status 203`: running, uptime ~154633s (~1.8 days), 16GB RAM (14GB free)
- `tailscale status | grep immich`: immich-1 offline, last seen 1d ago
- `ip neigh | grep 192.168.1.203`: FAILED (ARP never resolved)
- `tap203i0`: UP, in vmbr0 bridge, state forwarding (host-side healthy)
- Cloud-init `ipconfig0`: `ip=192.168.12.230/24,gw=192.168.12.1` (old network — not updated for UDR6 cutover)
- VM SSH user per legacy docs: `ronny` (not `ubuntu` — deviation from standard)

Root cause hypothesis: VM internal netplan still configured for 192.168.12.x network. After UDR6 cutover, old gateway 192.168.12.1 no longer routes. VM is network-isolated but OS/Docker still running.

## Notes

- Immich is a separate service (VM 203) from media-stack (VM 209/210); gets its own extraction loop.
- CRITICAL: VM 203 network-isolated (GAP-OP-094). Immich service down, daily backup cannot push offsite, mobile sync broken. Fix requires VNC console access.
- P2 docs not blocked by P1 — legacy source has sufficient detail for spine-native rewrite.
- MCP server spec (`infrastructure/mcpjungle/servers/immich-photos/SPEC.md`) deferred to future loop when implementation begins.
- Deduplication scripts (`.archive/2026-01-05-full-reset/scripts/dedupe/`) deferred to future tooling loop.
