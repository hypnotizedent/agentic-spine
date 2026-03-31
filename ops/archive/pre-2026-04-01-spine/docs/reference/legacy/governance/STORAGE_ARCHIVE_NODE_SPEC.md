---
status: draft
owner: "@ronny"
created_at: "2026-03-24"
scope: v3-storage-archive-node-spec
node_id: 7
related_arch: docs/governance/SPINE_V3_BOOTSTRAP.md
---

# Storage / Archive Node — V3 Node 7/7

## Role
The storage/archive node manages evidence persistence, receipt archival,
and long-term state snapshots. It is the spine's memory.

## Host
Synology DS918+ (NAS, 10.0.0.150) for cold storage.
VM 207 for hot/warm evidence cache.

## Responsibilities
| Role | Description |
|------|-------------|
| Receipt archival | Move receipts through hot→warm→cold per receipts.archival.policy.yaml |
| Evidence indexing | Maintain receipt-index.yaml with watermarks |
| State snapshots | Periodic shared_authority.db snapshots to NAS |
| Backup verification | Validate evidence integrity on cold storage |

## Retention Policy (from receipts.archival.policy.yaml)
- Hot: 0-14 days (local evidence/ directory)
- Warm: 15-90 days (NAS /volume1/spine-archive/warm/)
- Cold: 91+ days (NAS /volume1/spine-archive/cold/)

## Dependencies
- All nodes emit receipts that flow here
- receipts.archival.policy.yaml governs retention
- receipts.index.schema.yaml governs index format
- Synology NAS must be reachable (10.0.0.150)

## Phase
- Phase 1: Manual archival via capability (CURRENT — receipts.summary, receipts.trends exist)
- Phase 2: Automated archival cron via scheduler
- Phase 3: Integrity verification + cold-storage restore drills

## Open Items
- NAS archive directory creation (/volume1/spine-archive/)
- Automated hot→warm promotion cron
- Cold storage restore drill (infra.infisical.restore.drill pattern exists, adapt for evidence)
- Synology credentials in Infisical (blocked on GAP-OP-1674)
