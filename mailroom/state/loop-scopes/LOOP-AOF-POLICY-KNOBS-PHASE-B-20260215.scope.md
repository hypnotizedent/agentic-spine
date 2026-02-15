---
loop_id: LOOP-AOF-POLICY-KNOBS-PHASE-B-20260215
created: 2026-02-15
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Wire remaining 6 policy knobs from contract into runtime enforcement paths
---

# Loop Scope: AOF Policy Knobs Phase B

## Problem Statement

Phase A wired 4/10 policy knobs (drift_gate_mode, approval_default, session_closeout_sla_hours,
warn_policy) into runtime enforcement via resolve-policy.sh. The remaining 6 knobs are declared
in policy.presets.yaml and policy.runtime.contract.yaml but produce no runtime effect.

## Deliverables

| Lane | Gap ID | Knob | Enforcement Point |
|------|--------|------|-------------------|
| D | GAP-OP-354 | stale_ssot_max_days | drift-gate.sh (D58 threshold) |
| E | GAP-OP-355 | gap_auto_claim | gaps-file auto-claim behavior |
| F | GAP-OP-356 | proposal_required | cap.sh write path enforcement |
| F | GAP-OP-359 | multi_agent_writes | cap.sh + pre-commit enforcement |
| G | GAP-OP-357 | receipt_retention_days | evidence.export.plan capability |
| H | GAP-OP-358 | commit_sign_required | pre-commit hook guard |

## Child Gaps

| Gap ID | Severity | Description |
|--------|----------|-------------|
| GAP-OP-354 | high | stale_ssot_max_days runtime wiring |
| GAP-OP-355 | medium | gap_auto_claim runtime wiring |
| GAP-OP-356 | high | proposal_required runtime wiring |
| GAP-OP-357 | medium | receipt_retention_days runtime wiring |
| GAP-OP-358 | medium | commit_sign_required runtime wiring |
| GAP-OP-359 | high | multi_agent_writes runtime wiring |

## Acceptance Criteria

- All 6 knobs wired: resolve-policy.sh exports them, enforcement points consume them
- policy.runtime.contract.yaml updated: all 10 knobs wired=true
- Tests for each knob enforcement behavior
- policy.runtime.audit shows 100% coverage
- spine.verify PASS
- All 6 gaps closed with evidence references

## Constraints

- Governed flow only (gaps.file/claim/close, receipts, verify)
- No destructive shortcuts
- Keep working tree clean except intentional changes

## Evidence

All 6 child gaps closed. Acceptance criteria met:

| Criterion | Result |
|-----------|--------|
| All 6 knobs wired in resolve-policy.sh | PASS (10/10 exported) |
| policy.runtime.contract.yaml all wired=true | PASS (10/10) |
| Tests for each knob enforcement | PASS (7 resolver + 9 enforcement = 16/16) |
| policy.runtime.audit 100% coverage | PASS (10 wired, 0 unwired) |
| spine.verify PASS | PASS (D1-D99 all pass) |
| All 6 gaps closed | PASS |

### Gap Transitions

| Gap | Status | Fixed In |
|-----|--------|----------|
| GAP-OP-354 | fixed | 9f16ce4 |
| GAP-OP-355 | fixed | 9f16ce4 |
| GAP-OP-356 | fixed | 9f16ce4 |
| GAP-OP-357 | fixed | 9f16ce4 |
| GAP-OP-358 | fixed | 9f16ce4 |
| GAP-OP-359 | fixed | 9f16ce4 |

### Enforcement Table

| Knob | Wired In | Validates Via |
|------|----------|---------------|
| stale_ssot_max_days | drift-gate.sh (D58) | SSOT_FRESHNESS_DAYS from RESOLVED_STALE_SSOT_MAX_DAYS |
| gap_auto_claim | gaps-file | claim_gap() after filing when true |
| proposal_required | cap.sh | Blocks mutating caps when true |
| receipt_retention_days | evidence-export-plan | Overrides session_receipts retention |
| commit_sign_required | .githooks/pre-commit | Blocks unsigned commits when true |
| multi_agent_writes | cap.sh + .githooks/pre-commit | Blocks direct writes when proposal-only |

### Completion

- Loop closed: 2026-02-15
- Implementation commit: 9f16ce4
- Note: Implementation changes were swept into 9f16ce4 by concurrent gaps.file from another terminal (multi-agent collision)
