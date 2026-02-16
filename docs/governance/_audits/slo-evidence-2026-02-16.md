---
date: 2026-02-16
type: slo-evidence-daily
snapshot_status: warn
verify_pass: 100%
slo_pass: PASS
---

# SLO Evidence Daily Report

**Date:** 2026-02-16  
**Snapshot Status:** warn  
**SLO Result:** PASS

## SLO Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Verify Gates | 14/14 (100%) | 100% | ✅ |
| Incidents | 0 | 0 | ✅ |
| Warnings | 1 | 0 | ⚠️ |
| Open Loops | 1 | - | ℹ️ |
| Open Gaps | 0 | - | ℹ️ |

## Domain Status

| Domain | Status |
|--------|--------|
| automation-stack | healthy |
| finance-stack | healthy |
| z2m-bridge | healthy |
| immich-stack | warn |

## Failing Verify Gates

None

## Evidence Trail

- **Generated:** 2026-02-16T16:05:14Z
- **Run Command:** `./bin/ops cap run slo.evidence.daily`

---

*Day 1 of 7-day SLO monitoring period*
