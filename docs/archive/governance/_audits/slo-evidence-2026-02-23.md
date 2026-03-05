---
date: 2026-02-23
type: slo-evidence-daily
snapshot_status: unknown
verify_pass: 100%
slo_pass: PASS
---

# SLO Evidence Daily Report

**Date:** 2026-02-23  
**Snapshot Status:** unknown  
**SLO Result:** PASS

## SLO Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Verify Gates | 15/15 (100%) | 100% | ✅ |
| Incidents | 0 | 0 | ✅ |
| Warnings | 0 | 0 | ✅ |
| Automation Latency Budget | pass (p95=241ms, p99=242ms, n8n=1412ms) | non-incident | ✅ |
| Automation Latency Samples | total=20, failed=0 | failed <= budget | ✅ |
| Open Loops | 2 | - | ℹ️ |
| Open Gaps | 0 | - | ℹ️ |

## Domain Status

| Domain | Status |
|--------|--------|
| (timeout) | (timeout) |

## Failing Verify Gates

None

## Evidence Trail

- **Generated:** 2026-02-24T05:00:09Z
- **Run Command:** `./bin/ops cap run slo.evidence.daily`

---

*Day 1 of 7-day SLO monitoring period*
