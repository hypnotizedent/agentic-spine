# W60 Untouched Over 7 Days Matrix

Audit date: 2026-02-28 (UTC)

| finding_id | repo/path | last_touch (git) | age_days | gt_7_days | observed_truth | severity | action_decision | evidence |
|---|---|---|---:|---|---|---|---|---|
| W60-U7-001 | `agentic-spine/AGENTS.md` | 2026-02-27 | 1 | no | STALE_ALREADY_FIXED | P3 | tombstone | `git log -1 --date=short --format='%ad' -- AGENTS.md` |
| W60-U7-002 | `agentic-spine/CLAUDE.md` | 2026-02-27 | 1 | no | STALE_ALREADY_FIXED | P3 | tombstone | `git log -1 --date=short --format='%ad' -- CLAUDE.md` |
| W60-U7-003 | `agentic-spine/ops/bindings/gate.domain.profiles.yaml` | 2026-02-27 | 1 | no | STALE_ALREADY_FIXED | P3 | tombstone | `git log -1 --date=short --format='%ad' -- ops/bindings/gate.domain.profiles.yaml` |
| W60-U7-004 | `agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` | 2026-02-26 | 2 | no | STALE_ALREADY_FIXED | P3 | tombstone | `git log -1 --date=short --format='%ad' -- docs/governance/SERVICE_REGISTRY.yaml` |
| W60-U7-005 | `workbench/infra/contracts/workbench.aof.contract.yaml` | 2026-02-17 | 11 | yes | CONFIRMED | P2 | fix_now | `git -C /Users/ronnyworks/code/workbench log -1 --date=short --format='%ad' -- infra/contracts/workbench.aof.contract.yaml` |
| W60-U7-006 | `mint-modules/docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V2.md` | 2026-02-26 | 2 | no | STALE_ALREADY_FIXED | P3 | tombstone | `git -C /Users/ronnyworks/code/mint-modules log -1 --date=short --format='%ad' -- docs/CANONICAL/MINT_SUPPLIER_SYNC_CONTRACT_V2.md` |

## Result

- Stale `>7d`: `1` surface (`workbench/infra/contracts/workbench.aof.contract.yaml`), tracked for refresh in W60 cleanup closure.
- Prior broad stale claims were not true at wave execution time.
