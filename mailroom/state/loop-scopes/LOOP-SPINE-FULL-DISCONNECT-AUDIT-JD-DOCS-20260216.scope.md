---
loop_id: LOOP-SPINE-FULL-DISCONNECT-AUDIT-JD-DOCS-20260216
opened_at: 2026-02-16T04:40:00Z
opened_by: terminal-c
status: open
base_sha: pending
lanes:
  D:
    name: "Audit findings + runtime disconnect fixes"
    description: "Full-repo disconnect scan, D67 fix, orphan cleanup"
    status: pending
  E:
    name: "Johnny Decimal taxonomy + mapping + docs index"
    description: "JD binding, index surfaces, status checker"
    status: pending
  F:
    name: "Validation tooling + tests + migration guardrails"
    description: "Smoke tests for JD status, drift gates"
    status: pending
acceptance_criteria:
  - Gate 0 rerun clean or improved with documented deltas
  - ./bin/ops cap run docs.jd.status => PASS
  - Johnny Decimal map coverage = 100% for in-scope docs
  - No duplicate JD IDs
  - ops status / loops / orchestration stay logically consistent
  - authority.project.status for workbench remains EXEMPT
  - spine.verify passes or failures are pre-existing/unrelated
---

# LOOP-SPINE-FULL-DISCONNECT-AUDIT-JD-DOCS-20260216

## Mission

1. Perform a full disconnect audit across agentic-spine (every folder scanned)
2. Implement Johnny Decimal organization for docs
3. Keep multi-agent safety and D75 compliance

## Gate 0 Baseline (captured 2026-02-16T04:39:00Z)

| Command | Status | Key Findings |
|---------|--------|--------------|
| spine.verify | FAIL | D67 capability map drift (media.status missing) |
| ops status --brief | OK | 0 loops, 1 gap (GAP-OP-526), 1 anomaly |
| gaps.status | OK | 1 open, 523 total |
| proposals.status | OK | 0 pending, 4 held |
| orchestration.status | OK | 5 closed loops |
| docs.sprawl.detect | OK | 178 docs, governance/ at threshold |
| drift_gates.certify | OK | 118 gates |
| drift_gates.failure_stats | OK | Top fail: D75 (7.95%), D48 (4.86%) |

## Disconnects Found

### P0 (Critical - Fix Now)
1. **D67 Capability Map Drift**: `media.status` missing from capability_map.yaml

### P1 (High - Fix This Loop)
2. **Split-Brain State**: 127 loop scope files vs 5 in orchestration (archived vs active)
3. **Stale References**: 1 file references "legacy-root", 15 files reference uppercase "/Code/"
4. **Orphaned Gap**: GAP-OP-526 has no parent loop (acceptable as standalone)

### P2 (Medium - Defer)
5. **Docs Authority Drift**: 1 deprecated doc (INFRASTRUCTURE_AUTHORITY.md) still in governance
6. **Plugin Test Coverage**: 26 plugins without tests, 8 with tests
7. **Legacy Docs**: 33 legacy docs need archival review

## Lane D: Audit Findings

- [ ] Fix D67 capability map drift
- [ ] Create audit report artifact
- [ ] File gaps for disconnects

## Lane E: Johnny Decimal

- [ ] Create ops/bindings/docs.johnny_decimal.yaml
- [ ] Create docs/jd/00.00-index.md
- [ ] Create docs/jd/README.md
- [ ] Create docs/jd/areas/*.md
- [ ] Add docs.jd.status capability

## Lane F: Validation

- [ ] Create ops/plugins/docs/bin/docs-jd-status
- [ ] Create smoke test in ops/plugins/docs/tests/

## Progress

### 2026-02-16T04:40:00Z - Loop Opened
- Gate 0 baseline captured
- Disconnect scan complete
- Starting fixes
