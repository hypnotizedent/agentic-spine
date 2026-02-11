# LOOP-CLAUDE-DESKTOP-FINDINGS-CLOSEOUT-20260211

- **Status:** open
- **Owner:** @ronny
- **Terminal:** C (apply-owner)
- **Created:** 2026-02-11
- **Source audit:** mailroom/outbox/CLAUDE__RESULT.md (2026-02-10 full certification)
- **Additional source:** Claude Desktop session findings (P2 items)

## Goal

Close ALL findings from the 2026-02-10 Claude Desktop full certification audit.
Each finding forced into one of: fixed, open-gap, invalid/outdated, deferred.

## Scope

- 5 critical (C1-C5), 12 moderate (M1-M12), 14 minor (N1-N14) from CLAUDE__RESULT.md
- 5 additional Claude Desktop P2 findings (ledger reaper, watcher/bridge, mailroom docs, receipts discovery, authority alignment)
- No scope creep into mint build

## Acceptance Criteria

1. Finding-by-finding table with: old claim | current truth | disposition | evidence
2. All true findings fixed via governed proposals
3. All unresolved findings registered as gaps tied to this loop
4. spine.verify passes
5. "No findings stashed: YES" confirmation

## Phases

- [x] P0: Re-validate every finding with file evidence
- [ ] P1: Mark invalid/outdated findings with proof
- [ ] P2: Fix true findings in minimal proposals
- [ ] P3: Register unresolved findings as gaps
- [ ] P4: Verify and produce closeout table

## Triage Summary (P0 Complete)

### Already Fixed Before This Loop (24 findings)
C1, C2, C3, C4, C5, M1, M2, M3, M4, M5, M6, M9, M10,
N2, N4, N5, N6, N7, N9, N10, N11, N12, N13, N14

### Invalid/Outdated (3 findings)
- M8: GAP-OP-029 vs 037 — different issues (029=Gitea secrets FIXED, 037=MD1400 SAS)
- N3: .brain/ refs — all are meta-documentation about D47 gate, not actual path usage
- P2-2: watcher vs bridge — distinct components, properly documented separately

### True Findings to Fix (6 findings)
- M11: docs/README.md gate count "D1-D57" (actual: D1-D68)
- N1: AGENTS.md + root README.md missing YAML front-matter
- P2-1: Ledger has 1 stale running entry + no reaper policy
- P2-3: mailroom/README.md sparse architecture description
- P2-4: No receipts discovery index/manifest
- P2-5: SESSION_PROTOCOL.md vs AGENTS.md authority contradictions (3 items)

### Deferred (3 findings)
- M7: Loop count discrepancy — structural (context.md auto-generated vs memory.md manual)
- M12: Home backups 4/5 disabled — tracked by LOOP-HOME-BACKUP, time-gated
- N8: GOVERNANCE_INDEX.md appendix incomplete — needs tooling, register as gap
