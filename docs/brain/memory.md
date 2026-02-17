---
status: brain-memory
owner: "@ronny"
last_verified: 2026-02-17
scope: agent-memory
---

# Session Memory — 2026-02-09 (EST)

> UDR swap caused home site unreachable. Nothing blocked remotely tonight that doesn't create churn.

## Open Loops (4)

| Loop | Next Action | Gate |
|------|-------------|------|
| **LOOP-BACKUP-STABILIZATION-20260208** (high) | P3: wait for first full vzdump run with `prune-backups keep-last=2` active, then verify auto-prune | Tomorrow ~07:00 EST |
| **LOOP-MEDIA-STACK-SPLIT-20260208** (medium) | COMPLETE — VM 201 destroyed, media split to VMs 209/210, loop closed | 2026-02-11 |
| **LOOP-CAMERA-BASELINE-20260208** (medium) | P2: restore ch2-4 cameras (physical visit to 9U rack) | On-site visit |
| **OL_SHOP_BASELINE_FINISH** (medium) | Physical audit (drives, cameras, AP, cron) | On-site visit |

## Open Gaps (1)

| Gap | Severity | Blocker |
|-----|----------|---------|
| **GAP-OP-037** — MD1400 SAS shelf invisible (PM8072 PCI ID mismatch) | critical | Maintenance window + cold power cycle required (all 10 VMs down) |
| **D54** — SSOT IP parity lock | medium | `network.shop.audit.status` enforces bindings ↔ SSOT parity + coverage for shop LAN identity |

## Health Receipts (anchor truth)

- **backup.status**: `receipts/sessions/RCAP-20260208-211446__backup.status__Rzyzc33301/receipt.md` — 9/9 onsite OK, 4 NAS targets connect_timeout (home unreachable)
- **services.health.status**: `receipts/sessions/RCAP-20260208-211520__services.health.status__Rteom34195/receipt.md` — 31 endpoints monitored
- **spine.verify**: `receipts/sessions/RCAP-20260208-211555__spine.verify__Rpvny34677/receipt.md` — 49/49 PASS

## Legacy Extraction Learnings (Jan 22-25, 2026)

Source merged from legacy memory:
`/Users/ronnyworks/ronny-ops/.brain/memory.md`

- `RAG enforcement`: retrieval quality is irrelevant if sessions are not forced through governed query paths; require capability-first lookup for discovery work.
- `Long-running transfer safety`: run large `rsync`/copy jobs with `nohup`/screen (not foreground SSH) to avoid silent partial migrations on disconnect.
- `Count vs size mismatch`: matching file counts can still hide block-allocation/sparse-file differences; verify both object counts and bytes before cutover claims.
- `MinIO control-plane prerequisite`: set `mc alias` inside the active MinIO execution context before bucket/policy operations; otherwise commands appear healthy but do nothing.
- `NFS for stateful services`: prefer hard mounts for database-backed services; soft mounts are acceptable for non-critical read paths only.
- `Printavo rename reality`: historical rename was approximately 50% complete with large orphan pool; always validate live bucket state before marking migration phases complete.
- `Merge-gate pattern`: reliable execution gate is `scope check + file-count expectation + guardrail/verify pass` before merge/closeout.
