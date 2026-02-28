# W60 Archive Decision Matrix

Date: 2026-02-28 (UTC)  
Lifecycle policy: `report-only -> archive-only -> delete(token-gated)`  
Delete token present: `no` (`RELEASE_MAIN_CLEANUP_WINDOW` not supplied)

| artifact_id | repo/path | issue class | current evidence | lifecycle_decision | token_required_for_delete | owner | due_window |
|---|---|---|---|---|---|---|---|
| W60-AR-001 | `agentic-spine/receipts/sessions/` | receipt/session sprawl | ~49,990 session dirs; oldest observed `R20260129-184428` | report-only now; plan archive-only rotation lane | yes | `@ronny` | 2026-03-02 to 2026-03-05 |
| W60-AR-002 | `workbench/quarantine/WORKBENCH_UNTRACKED_20260208-161550/` | quarantine pending triage | mtime `2026-02-08`; 12 files remain | report-only now; retain quarantine; archive-only disposition plan | yes | `@ronny` | 2026-03-02 to 2026-03-05 |
| W60-AR-003 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_ORDER_AUTOMATION_POLICY_V1.md` | superseded version coexistence | V1 and V2 both present | keep active for now; archive-only candidate once V2 attested as sole authority | yes | `@ronny` | 2026-03-03 to 2026-03-06 |
| W60-AR-004 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V1.md` | superseded version coexistence | V1 and V2 both present; V1 untouched 10 days | keep active for now; archive-only candidate once V2 parity note is receipted | yes | `@ronny` | 2026-03-03 to 2026-03-06 |
| W60-AR-005 | merged local branches in `agentic-spine` (`codex/w55-worktree-lifecycle-governance-20260227`, `codex/w59-three-loop-cleanup-20260227`) | branch hygiene | merged to `main`; still present locally | report-only only in this wave; no prune/delete | yes | `@ronny` | with next cleanup window |
| W60-AR-006 | `workbench/WORKBENCH_CONTRACT.md` | stale >7 day contract surface | last git touch `2026-02-16` (11 days) | refresh-in-place (not archive) in next governance sweep | n/a | `@ronny` | 2026-03-02 to 2026-03-04 |

## Enforcement Notes

- Archive-only actions are queued as decisions only in this wave.
- No artifact deletion or branch pruning has been executed.
- Any delete/prune action remains blocked until explicit token: `RELEASE_MAIN_CLEANUP_WINDOW`.
