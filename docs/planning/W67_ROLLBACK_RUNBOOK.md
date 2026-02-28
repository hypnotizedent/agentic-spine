# W67 Rollback / Kill-Switch Runbook

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
scope: enforcement flips only

## Kill Switch

- Env var: `SPINE_ENFORCEMENT_MODE`
- Allowed values: `enforce`, `report-only`
- Current W67 default: `enforce` for `D291`

## Immediate Rollback Procedure (non-destructive)

1. Export kill switch in the active shell:
   ```bash
   export SPINE_ENFORCEMENT_MODE=report-only
   ```
2. Re-run the affected control:
   ```bash
   bash surfaces/verify/d291-gate-budget-add-one-retire-one-lock.sh
   ```
3. Confirm output contains `D291 PASS (report-only)`.
4. Run validation block:
   ```bash
   ./bin/ops cap run gate.topology.validate
   ./bin/ops cap run verify.run -- fast
   ./bin/ops cap run verify.run -- domain communications
   ```

## Persistent Rollback (contract level)

1. Update `ops/bindings/gate.budget.add_one_retire_one.contract.yaml`:
   - `mode: report-only`
2. Keep `D291` in registry while rollback investigation is active.
3. Capture receipt with reason and expiry.

## Dry Path Validation (executed in W67)

- Enforce mode probe: PASS (`D291 PASS (enforce): no budget violations`)
- Kill-switch probe: PASS (`D291 PASS (report-only): no budget violations`)

W67-3 result: **PASS** (rollback path documented and validated via dry path).
