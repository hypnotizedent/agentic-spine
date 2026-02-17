# D133 Ratchet Batch 1

**Date:** 2026-02-17
**Loop:** LOOP-D133-LEGACY-RATCHET-20260217
**Executor:** Terminal C

## Scope

5 legacy exception gates normalized to canonical output vocabulary.

## Before/After

| Metric | Before | After |
|--------|--------|-------|
| Gates checked | 98 | 103 |
| Legacy exceptions | 22 | 17 |
| Reduction | — | 5 (d45, d48, d51, d52, d53) |

## Files Changed (6)

**Gate scripts patched (5):**
- `surfaces/verify/d45-naming-consistency-lock.sh` — `err()` → `D45 FAIL:`, added `D45 PASS:` line
- `surfaces/verify/d48-codex-worktree-hygiene.sh` — Python `print()` → `D48 PASS:`/`D48 FAIL:` prefixed
- `surfaces/verify/d51-caddy-proto-lock.sh` — bare `FAIL:` → `D51 FAIL:`, added `D51 PASS:` line
- `surfaces/verify/d52-udr6-gateway-assertion.sh` — bare `FAIL:` → `D52 FAIL:`, added `D52 PASS:` line
- `surfaces/verify/d53-change-pack-integrity-lock.sh` — bare `FAIL:` → `D53 FAIL:`, added `D53 PASS:` line

**D133 gate updated (1):**
- `surfaces/verify/d133-output-vocabulary-lock.sh` — removed d45-d53 from exceptions, extended grep to match `print` (Python gates)

## Verification

| Check | Result |
|-------|--------|
| D133 standalone | PASS (103 checked, 17 excepted) |
| d45 standalone | D45 PASS: naming consistency lock (19 hosts checked) |
| d48 standalone | D48 PASS: worktrees clean (count=1), stashes=1 (0 orphaned) |
| d51 standalone | D51 PASS: caddy proto lock (4 proxy blocks) |
| d52 standalone | D52 PASS: UDR6 gateway assertions valid |
| d53 standalone | D53 PASS: change pack integrity valid |
| verify.core.run | 8/8 PASS |
| verify.domain.run aof --force | 18/18 PASS |

## Remaining Exceptions (17)

d58, d59, d60, d61, d64, d68, d69, d81, d82, d83, d84, d98, d99, d103, d112, d113, d114
