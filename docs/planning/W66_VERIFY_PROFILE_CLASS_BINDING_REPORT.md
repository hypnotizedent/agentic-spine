# W66 Verify Profile Class Binding Report

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
phase_gate: P1
status: PASS

## Canonical Contract

- New contract: `ops/bindings/verify.run.profile.contract.yaml`
- Resolution policy: class-driven (`invariant | freshness | advisory`), retired gates excluded.
- Execution bridge: `verify-run` resolves IDs from contract + topology/domain bindings, then dispatches via `verify-topology ids-run`.

## Runtime Wiring Changes

| file | change |
|---|---|
| `ops/plugins/verify/bin/verify-run` | Added class-driven scope resolver, contract ingestion, core/domain class filtering, support for `--` invocation prefix |
| `ops/plugins/verify/bin/verify-topology` | Added `ids-run` subcommand for deterministic explicit gate-id execution |
| `ops/bindings/verify.run.profile.contract.yaml` | Added canonical profile-class mapping contract |

## Scope Results (W66)

| scope | run_key | wrapper_result |
|---|---|---|
| `verify.run -- fast` | `CAP-20260228-020333__verify.run__Rwz8m56771` | PASS (`total=10`, `fail=0`) |
| `verify.run -- domain communications` | `CAP-20260228-020338__verify.run__Rsttx57392` | PASS (`total=34`, `fail=0`) |

## Shadow Parity Evidence

Generated artifacts:
- `/tmp/W66_VERIFY_FAST_SHADOW.json`
- `/tmp/W66_VERIFY_DOMAIN_COMM_SHADOW.json`

| scope | parity total_delta | parity fail_delta | interpretation |
|---|---:|---:|---|
| fast | -5 | 0 | Wrapper reduced non-invariant checks; no new failures |
| domain communications | -14 | 0 | Wrapper reduced non-target-class checks; no new failures |

## W66-3 / W66-4 Gate Result

- W66-3 verify.run class-based routing active: **PASS**
- W66-4 no regression in topology/domain packs: **PASS**
  - Evidence: pack runs all pass in W66 (`core`, `secrets`, `communications`, `mint`).
