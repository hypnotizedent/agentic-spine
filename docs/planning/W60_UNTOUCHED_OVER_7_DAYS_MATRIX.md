# W60 Untouched Over 7 Days Matrix

Audit date: 2026-02-28 (UTC)

## Matrix A — W59 Freshness Set Revalidation

Scope source: `docs/planning/W59_FINDINGS_TO_LOOP_ACTION_MATRIX_20260227.md` (11-file freshness set).

| finding_id | repo/path | last_touch (git) | age_days | gt_7_days | observed_truth | severity | action_decision |
|---|---|---|---:|---|---|---|---|
| W60-U7-001 | `agentic-spine/AGENTS.md` | 2026-02-23 | 3 | no | changed (freshened since W59 claim) | P3 | tombstone |
| W60-U7-002 | `agentic-spine/CLAUDE.md` | 2026-02-22 | 5 | no | changed | P3 | tombstone |
| W60-U7-003 | `agentic-spine/docs/governance/SESSION_PROTOCOL.md` | 2026-02-27 | 0 | no | changed | P3 | tombstone |
| W60-U7-004 | `agentic-spine/ops/bindings/agents.registry.yaml` | 2026-02-27 | 0 | no | changed | P3 | tombstone |
| W60-U7-005 | `agentic-spine/ops/bindings/terminal.role.contract.yaml` | 2026-02-27 | 0 | no | changed | P3 | tombstone |
| W60-U7-006 | `agentic-spine/ops/bindings/gate.domain.profiles.yaml` | 2026-02-27 | 0 | no | changed | P3 | tombstone |
| W60-U7-007 | `agentic-spine/ops/plugins/MANIFEST.yaml` | 2026-02-27 | 0 | no | changed | P3 | tombstone |
| W60-U7-008 | `agentic-spine/ops/bindings/services.health.yaml` | 2026-02-26 | 1 | no | changed | P3 | tombstone |
| W60-U7-009 | `agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` | 2026-02-26 | 1 | no | changed | P3 | tombstone |
| W60-U7-010 | `agentic-spine/ops/bindings/ssh.targets.yaml` | 2026-02-27 | 0 | no | changed | P3 | tombstone |
| W60-U7-011 | `agentic-spine/ops/bindings/docker.compose.targets.yaml` | 2026-02-26 | 1 | no | changed | P3 | tombstone |

Evidence command used:
- `git log -1 --format=%ct -- <path>` per listed path, converted to calendar date and day age.

## Matrix B — Additional Stale/Untouched Findings Across Wave Repos

| finding_id | repo/path | last_touch source | last_touch value | age_days | risk | severity | action_decision |
|---|---|---|---|---:|---|---|---|
| W60-U7-012 | `workbench/WORKBENCH_CONTRACT.md` | git | 2026-02-16 | 11 | Entry contract stale beyond 7 days while cross-repo execution is active | P2 | fix_now |
| W60-U7-013 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V1.md` | git | 2026-02-17 | 10 | Superseded canonical variant remains untouched while V2 coexists | P2 | archive |
| W60-U7-014 | `workbench/quarantine/WORKBENCH_UNTRACKED_20260208-161550/` | filesystem mtime | 2026-02-08 | 20 | Quarantine payload untouched and still pending disposition | P3 | archive |
| W60-U7-015 | `agentic-spine/receipts/sessions/` oldest node `R20260129-184428` | filesystem mtime | 2026-01-29 | 30 | Receipt sprawl and retention drift risk | P3 | archive |

Evidence commands used:
- `git log -1 --format=%ct -- WORKBENCH_CONTRACT.md`
- `git log -1 --format=%ct -- docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V1.md`
- `stat -f '%N|%Sm' -t '%Y-%m-%d' quarantine/WORKBENCH_UNTRACKED_20260208-161550`
- `find receipts/sessions -mindepth 1 -maxdepth 1 -type d -name 'R*' -print0 | xargs -0 stat -f '%m %N' | sort -n | head -n 1`

## Phase 1 Freshness Conclusion

- The original W59 11-file freshness alarm is no longer true (`0/11` are `>7` days).
- New stale surfaces now concentrate in:
  - `workbench` contract/quarantine lifecycle artifacts
  - `mint-modules` superseded canonical variants
  - `agentic-spine` receipt retention scale
