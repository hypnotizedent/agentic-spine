---
loop_id: LOOP-AOF-POLICY-KNOBS-PHASE-B-20260215
created: 2026-02-15
status: open
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
