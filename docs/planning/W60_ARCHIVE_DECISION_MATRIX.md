# W60 Archive Decision Matrix

Date: 2026-02-28 (UTC)
Lifecycle: `report-only -> archive-only -> delete(token-gated)`
Delete token: `RELEASE_MAIN_CLEANUP_WINDOW` not provided

| artifact_id | repo/path | class | decision | checksum_parity_required | owner | due_window | evidence |
|---|---|---|---|---|---|---|---|
| W60-AR-001 | `agentic-spine/receipts/sessions/` | retention >30d | archive-only queued | yes | `@ronny` | 2026-03-02 to 2026-03-05 | `ops/plugins/evidence/bin/receipts-checksum-parity-report` + `ops/runtime/receipts-archive-reconcile-daily.sh` |
| W60-AR-002 | `workbench/quarantine/WORKBENCH_UNTRACKED_20260208-161550/` | stale quarantine payload | report-only now | yes | `@ronny` | next cleanup window | `find /Users/ronnyworks/code/workbench/quarantine -type f | wc -l` |
| W60-AR-003 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_DECISIONS_V1.yaml` | superseded canonical loser | tombstoned retained (no delete) | yes | `@ronny` | next cleanup window | `rg -n "status: tombstoned|superseded_by|do_not_use_for_runtime" /Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_SUPPLIER_DECISIONS_V1.yaml` |
| W60-AR-004 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_DECISIONS_V2.yaml` | superseded canonical loser | tombstoned retained (no delete) | yes | `@ronny` | next cleanup window | `rg -n "status: tombstoned|superseded_by|do_not_use_for_runtime" /Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_SUPPLIER_DECISIONS_V2.yaml` |
| W60-AR-005 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V1.md` | superseded contract loser | tombstoned retained (no delete) | yes | `@ronny` | next cleanup window | `rg -n "status: tombstoned|superseded_by|do_not_use_for_runtime" /Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V1.md` |
| W60-AR-006 | `agentic-spine/.archive/staged/` | staged projection archive | keep archive projection | yes | `@ronny` | continuous | `rg -n "authority_state: projection|do_not_use_for_runtime" .archive/staged/README.md` |

## Policy Notes

- Archive/deletion lifecycle is now checksum-gated by `D288`.
- No artifact deletion/prune was performed in W60.
