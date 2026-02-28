# W61 Verify Wrapper Shadow Parity Report

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W61-ENTRY-PROJECTION-VERIFY-UNIFICATION-20260228-20260303`

## Shadow Runs

| scope | run_key | wrapper_result | legacy_result | parity_diff | status |
|---|---|---|---|---|---|
| `fast` | `CAP-20260227-214501__verify.run__R3j1x74833` | total=15 pass=15 fail=0 | total=15 pass=15 fail=0 | total_delta=0, pass_delta=0, fail_delta=0, wrapper_only_failures=[], legacy_only_failures=[] | PASS |
| `domain communications` | `CAP-20260227-214507__verify.run__Rz8x676732` | total=47 pass=47 fail=0 | total=47 pass=47 fail=0 | total_delta=0, pass_delta=0, fail_delta=0, wrapper_only_failures=[], legacy_only_failures=[] | PASS |

## Non-Shadow Release Profile Validation

| scope | run_key | wrapper_result | note |
|---|---|---|---|
| `release` | `CAP-20260227-214554__verify.run__Rfp4f82295` | status=fail (`DRIFT GATE: FAIL`) | Wrapper path executes and emits classification telemetry; failure is runtime drift, not wrapper parity regression. |

## Conclusion

- Canonical wrapper `verify.run <scope>` is operational.
- Shadow parity against existing verify paths is proven for `fast` and `domain` scopes.
- Existing verify commands remain intact and usable in parallel.
