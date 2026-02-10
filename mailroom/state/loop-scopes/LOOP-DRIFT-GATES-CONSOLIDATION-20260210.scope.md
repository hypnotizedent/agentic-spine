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
- P1: Consolidation proposal (what merges, what stays, what moves to preflight) [TODO]
- P2: Implement composites + keep/retire plan (optional, separate change pack) [TODO]
- P3: Verify + closeout (receipts) [TODO]

## Evidence (Receipts)
- `receipts/sessions/RCAP-20260209-202244__verify.drift_gates.certify__Rkxk068237/receipt.md`
- `receipts/sessions/RCAP-20260209-202834__verify.drift_gates.failure_stats__Rce7d70480/receipt.md`

## Deferred / Follow-ups
- Decide whether to keep individual gates as "verbose mode" behind an env flag.
