---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-DRIFT-GATES-CONSOLIDATION-20260210
---

# Loop Scope: LOOP-DRIFT-GATES-CONSOLIDATION-20260210

## Goal
Condense and enhance drift-gate enforcement so agents have fewer, clearer STOP
signals while preserving irreversible safety guarantees.

## Success Criteria
- A canonical proposal exists (with data) mapping current gates -> consolidated composites.
- Governance gaps are filed for any missing enforcement or ambiguous gate ownership.
- Follow-up implementation loop(s) are split from the proposal if needed.

## Phases
- P0: Data snapshot (failure stats + gate inventory) [DONE]
- P1: Consolidation proposal (what merges, what stays, what moves to preflight) [DONE]
- P2: Implement composites + keep/retire plan (optional, separate change pack) [DONE]
- P3: Verify + closeout (receipts) [DONE]

## Evidence (Receipts)
- `receipts/sessions/RCAP-20260209-202244__verify.drift_gates.certify__Rkxk068237/receipt.md`
- `receipts/sessions/RCAP-20260209-202834__verify.drift_gates.failure_stats__Rce7d70480/receipt.md`
- `receipts/sessions/RCAP-20260209-214759__docs.lint__Rc3p115916/receipt.md`
- `receipts/sessions/RCAP-20260209-215438__spine.verify__Rnfrg28010/receipt.md`
- `receipts/sessions/RCAP-20260209-215457__verify.drift_gates.certify__Rlbi531897/receipt.md`
- `receipts/sessions/RCAP-20260209-215520__spine.verify__Rbxzk32284/receipt.md` (DRIFT_VERBOSE=1)

## Deferred / Follow-ups
- DRIFT_VERBOSE implemented: default runs composites (D55-D57); verbose runs the underlying gates individually.
- Consider whether D48 should treat "no remote branch yet" as WARN (grace window) vs FAIL.
