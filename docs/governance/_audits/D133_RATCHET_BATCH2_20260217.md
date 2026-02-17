# D133 Ratchet Batch 2

**Date:** 2026-02-17
**Loop:** LOOP-D133-LEGACY-RATCHET-20260217
**Executor:** Terminal C

## Scope

5 legacy exception gates normalized to canonical output vocabulary.

## Before/After

| Metric | Before | After |
|--------|--------|-------|
| Gates checked | 103 | 108 |
| Legacy exceptions | 17 | 12 |
| Reduction | — | 5 (d58, d59, d60, d61, d64) |

## Files Changed (6)

**Gate scripts patched (5):**
- `surfaces/verify/d58-ssot-freshness-lock.sh` — `err()` → `D58 FAIL:`, added `D58 PASS:` line
- `surfaces/verify/d59-cross-registry-completeness-lock.sh` — `err()` → `D59 FAIL:`, added `D59 PASS:` line
- `surfaces/verify/d60-deprecation-sweeper.sh` — `err()` → `D60 FAIL:`, added `D60 PASS:` line
- `surfaces/verify/d61-session-loop-traceability-lock.sh` — `err()` → `D61 FAIL:`, Python print → `D61 FAIL:`, added `D61 PASS:` line
- `surfaces/verify/d64-git-remote-authority-warn.sh` — `WARN:` → `D64 WARN:`, added `D64 PASS:` line

**D133 gate updated (1):**
- `surfaces/verify/d133-output-vocabulary-lock.sh` — removed d58-d64 from exceptions

## Verification

| Check | Result |
|-------|--------|
| D133 standalone | PASS (108 checked, 12 excepted) |
| d58 standalone | D58 PASS: SSOT freshness valid (threshold=21d) |
| d59 standalone | D59 PASS: cross-registry completeness valid |
| d60 standalone | D60 PASS: deprecation sweeper clean (4 terms checked) |
| d61 standalone | D61 FAIL (pre-existing: no closeout in ledger — not a regression) |
| d64 standalone | D64 PASS: no GitHub-authored merges in last 50 commits |
| verify.core.run | 8/8 PASS |
| verify.domain.run aof --force | 18/18 PASS |

## Remaining Legacy Exceptions (12)

d68, d69, d81, d82, d83, d84, d98, d99, d103, d112, d113, d114
