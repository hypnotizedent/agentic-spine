# W66/W67 Combined Master Receipt

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
loop_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
branch: codex/w66-w67-projection-enforcement-20260228

decision: MERGE_READY

## Chronology

| milestone | value |
|---|---|
| preflight_branch_head | dbc18d53e9f630ff60afbfac690aa05cdb821186 |
| w66_phase_gate | PASS |
| w67_phase_gate | PASS |
| closeout_branch_head | f0527ce45ad1c0f667acb7850db7be0579409d12 |
| promotion_head | n/a (no `RELEASE_MAIN_MERGE_WINDOW`) |

## Baseline vs Final Counters

| metric | baseline | final | delta |
|---|---:|---:|---:|
| open_loops | 18 | 19 | +1 |
| open_gaps | 54 | 54 | 0 |
| orphaned_open_gaps | 0 | 0 | 0 |
| freshness_class_failures_24h | 0 | 2 | +2 |

## Phase Results

| phase | result | evidence |
|---|---|---|
| Phase 0 preflight | PASS | run keys in `W66_W67_RUN_KEY_LEDGER.md` |
| Phase 1 W66 Projection Generation | PASS | `W66_ACCEPTANCE_MATRIX.md` |
| Phase 2 W67 Enforcement Flip | PASS | `W67_ACCEPTANCE_MATRIX.md` |

## Combined Acceptance

- Score: **14/14 PASS**
- Matrix: `docs/planning/W66_W67_COMBINED_ACCEPTANCE_MATRIX.md`

## Blockers

none

## Attestation Flags

| flag | value |
|---|---|
| no_protected_lane_mutation | true |
| no_vm_infra_runtime_mutation | true |
| no_secret_values_printed | true |

## Run Keys

See `docs/planning/W66_W67_RUN_KEY_LEDGER.md` (all required keys + receipts paths).
