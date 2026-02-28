# W66/W67 Combined Acceptance Matrix

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
combined_target: 14/14 PASS

| id | check | result | evidence |
|---|---|---|---|
| C01 | W66-1 projection sync/verify pass | PASS | `W66_ACCEPTANCE_MATRIX.md` |
| C02 | W66-2 boot surfaces match registry claims | PASS | `W66_PROJECTION_GENERATION_REPORT.md` |
| C03 | W66-3 class-based verify.run routing active | PASS | `W66_VERIFY_PROFILE_CLASS_BINDING_REPORT.md` |
| C04 | W66-4 no topology/domain regression | PASS | W66 pack run keys |
| C05 | W67-1 eligibility matrix complete | PASS | `W67_ENFORCEMENT_ELIGIBILITY_MATRIX.md` |
| C06 | W67-2 enforce flips applied correctly | PASS | `W67_ENFORCEMENT_FLIP_REPORT.md` |
| C07 | W67-3 rollback path documented + dry-path validated | PASS | `W67_ROLLBACK_RUNBOOK.md` |
| C08 | W67-4 verification suite clean for intended policy | PASS | `W67_ACCEPTANCE_MATRIX.md` |
| C09 | required run keys captured in ledger | PASS | `W66_W67_RUN_KEY_LEDGER.md` |
| C10 | all required W66/W67 artifacts present | PASS | files under `docs/planning/` |
| C11 | branch parity proven (`local=origin=github=share`) | PASS | `W66_W67_PROMOTION_PARITY_RECEIPT.md` |
| C12 | branch clean status proven | PASS | `W66_W67_BRANCH_ZERO_STATUS_REPORT.md` |
| C13 | attestations all true (protected lanes/runtime/secrets) | PASS | `W66_W67_COMBINED_MASTER_RECEIPT.md` |
| C14 | run keys resolve to receipts/sessions artifacts | PASS | `receipts/sessions/RCAP-.../receipt.md` |

Acceptance score: **14/14 PASS**
