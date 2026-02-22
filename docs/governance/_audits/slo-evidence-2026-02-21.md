---
date: 2026-02-21
type: slo-evidence-daily
snapshot_status: warn
verify_pass: 87%
slo_pass: FAIL
---

# SLO Evidence Daily Report

**Date:** 2026-02-21  
**Snapshot Status:** warn  
**SLO Result:** FAIL

## SLO Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Verify Gates | 7/8 (87%) | 100% | ❌ |
| Incidents | 0 | 0 | ✅ |
| Warnings | 6 | 0 | ⚠️ |
| Automation Latency Budget | warn (p95=1368ms, p99=2087ms, n8n=4412ms) | non-incident | ⚠️ |
| Automation Latency Samples | total=20, failed=0 | failed <= budget | ✅ |
| Open Loops | 8 | - | ℹ️ |
| Open Gaps | 0 | - | ℹ️ |

## Domain Status

| Domain | Status |
|--------|--------|
| automation-stack | healthy |
| finance-stack | warn |
| z2m-bridge | healthy |
| immich-stack | warn |
| infra-core-stack | warn |
| observability-stack | warn |
| dev-tools-stack | warn |
| mint-stack | warn |

## Failing Verify Gates

D148

## Evidence Trail

- **Generated:** 2026-02-22T05:01:38Z
- **Run Command:** `./bin/ops cap run slo.evidence.daily`

---

*Day 1 of 7-day SLO monitoring period*
