---
date: 2026-02-21
type: slo-evidence-daily
snapshot_status: warn
verify_pass: 85%
slo_pass: FAIL
---

# SLO Evidence Daily Report

**Date:** 2026-02-21  
**Snapshot Status:** warn  
**SLO Result:** FAIL

## SLO Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Verify Gates | 6/7 (85%) | 100% | ❌ |
| Incidents | 0 | 0 | ✅ |
| Warnings | 4 | 0 | ⚠️ |
| Automation Latency Budget | pass (p95=158ms, p99=189ms, n8n=904ms) | non-incident | ✅ |
| Automation Latency Samples | total=20, failed=0 | failed <= budget | ✅ |
| Open Loops | 3 | - | ℹ️ |
| Open Gaps | 0 | - | ℹ️ |

## Domain Status

| Domain | Status |
|--------|--------|
| automation-stack | healthy |
| finance-stack | warn |
| z2m-bridge | healthy |
| immich-stack | warn |
| infra-core-stack | warn |
| observability-stack | healthy |
| dev-tools-stack | warn |
| mint-stack | healthy |

## Failing Verify Gates

D126

## Evidence Trail

- **Generated:** 2026-02-21T07:01:25Z
- **Run Command:** `./bin/ops cap run slo.evidence.daily`

---

*Day 1 of 7-day SLO monitoring period*
