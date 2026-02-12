---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-N8N-AUTOMATION-RECOVERY-HARDENING-20260212
severity: high
---

# Loop Scope: LOOP-N8N-AUTOMATION-RECOVERY-HARDENING-20260212

## Goal

Harden n8n/automation-stack recovery so workflows are exportable, restorable,
and snapshot-backed on schedule. Close GAP-OP-114.

## Acceptance Criteria

1. Governed export-all command exports every active workflow to deterministic path — DONE
2. Restore command path tested (at least one workflow dry-run) — DONE
3. Recovery runbook exists (export/import/activate/deactivate/rollback) — DONE
4. Daily scheduled snapshot with 7-day retention on automation-stack — DONE
5. Snapshot status observable via spine capability — DONE
6. New capabilities registered in capability_map.yaml + capabilities.yaml — DONE
7. Backup inventory entry for n8n workflow snapshots — DONE
8. spine.verify PASS (60/61, D66 pre-existing media parity) — DONE
9. GAP-OP-114 status changed to fixed — DONE

## Phases

| Phase | Scope | Status | Commit/Proposal |
|-------|-------|--------|-----------------|
| P0 | Loop + gap registration | DONE | (this commit) |
| P1 | Export-all script + snapshot deploy to VM | DONE | (this commit) |
| P2 | Recovery runbook + capability registration | DONE | (this commit) |
| P3 | Validation + close | DONE | (this commit) |

## Evidence

- First snapshot: 35 workflows exported to `/home/automation/backups/n8n-workflows/20260212-011826/`
- Cron installed: `0 3 * * * /home/automation/scripts/n8n-snapshot-cron.sh`
- Receipts: RCAP-20260211-201920 (list), RCAP-20260211-202249 (snapshot.status)
- spine.verify: 60/61 PASS (D66 pre-existing, unrelated)
