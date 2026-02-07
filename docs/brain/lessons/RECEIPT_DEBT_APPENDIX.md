# Historical Receipt Debt Appendix

> **Generated:** 2026-02-07
> **Scope:** Report-only — no historical artifacts were modified.
> **Purpose:** List `receipts/sessions/` directories missing the canonical `receipt.md` proof file.

## Context

Per [RECEIPTS_CONTRACT.md](../../core/RECEIPTS_CONTRACT.md), the canonical proof artifact is
`receipts/sessions/R<RUN_KEY>/receipt.md`. Directories without this file are legacy debt
from pre-governance sessions. They are not runtime failures and do not need remediation
unless referenced in active loop evidence.

## Missing `receipt.md` (42 directories)

### ADHOC sessions (19)

| # | Directory |
|---|-----------|
| 1 | `ADHOC_20260131_231421_HOME_DRIFT_AUDIT` |
| 2 | `ADHOC_20260131_232108_HOME_DRIFT_INGEST` |
| 3 | `ADHOC_20260201_010341_outside_surface_audit` |
| 4 | `ADHOC_20260201_015227_CANON_DEDUPE_REPORT` |
| 5 | `ADHOC_20260201_024807_SPINE_LOCK` |
| 6 | `ADHOC_20260201_024830_NEEDS_REVIEW_SHORTLIST` |
| 7 | `ADHOC_20260201_025114_NEEDS_REVIEW_DECISION` |
| 8 | `ADHOC_20260201_030024_HARDCODED_PATH_SWEEP` |
| 9 | `ADHOC_20260201_030119_DEFER_REGISTRY_BUILD` |
| 10 | `ADHOC_20260201_030149_DECISION_PLAN` |
| 11 | `ADHOC_20260201_030216_DECISION_PLAN` |
| 12 | `ADHOC_20260201_030454_HARDCODED_DECISION_PACK` |
| 13 | `ADHOC_20260201_030959_OPS_HARDCODED_MUSTFIX` |
| 14 | `ADHOC_20260201_031239_QUARANTINE_INDEX` |
| 15 | `ADHOC_20260201-003956_ENABLE_WORKBENCH_ESPANSO_HAMMERSPOON_SAFE` |
| 16 | `ADHOC_20260201-004330_RELOAD_ESPANSO_HAMMERSPOON_AND_PLAN_ITERM2_SUPERWHISPER` |
| 17 | `ADHOC_20260201-004626_ESPANSO_FIX_LAUNCHCTL_EXIT3_READONLY` |
| 18 | `ADHOC_20260201-005605_HAMMERSPOON_FAST_VERIFY` |
| 19 | `ADHOC_20260201` |

### R-key sessions (14)

| # | Directory |
|---|-----------|
| 20 | `R20260129-190806` |
| 21 | `R20260129-224948` |
| 22 | `R20260129-232218` |
| 23 | `R20260129-232552` |
| 24 | `R20260129-233600` |
| 25 | `R20260129-233641` |
| 26 | `R20260129-234217` |
| 27 | `R20260129-234628` |
| 28 | `R20260129-235041` |
| 29 | `R20260129-235422` |
| 30 | `R20260129-235428` |
| 31 | `R20260130-015121` |
| 32 | `R20260130-032657` |
| 33 | `R20260201-020919` |

### OPS/SKIP/VERIFY sessions (9)

| # | Directory |
|---|-----------|
| 34 | `OPS_VERIFY_SKIP_IMMICH_20260201_023911` |
| 35 | `SKIP_IMMICH_PATCH_20260201_023529` |
| 36 | `SKIP_IMMICH_PATCH_20260201_023547` |
| 37 | `SKIP_IMMICH_PATCH_20260201_023555` |
| 38 | `SKIP_IMMICH_PATCH_20260201_023631` |
| 39 | `SKIP_IMMICH_PATCH_20260201_023745` |
| 40 | `SKIP_IMMICH_PATCH_20260201_023755` |
| 41 | `SKIP_IMMICH_PATCH_20260201_023803` |
| 42 | `VERIFY_SURFACES_CANON_20260201_023703` |

## Assessment

All 42 entries predate the current receipt contract (established 2026-02-03).
These are **legacy debt**, not active failures. No remediation is required unless
a directory is referenced as evidence in an open loop.
