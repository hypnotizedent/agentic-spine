# loop_gap Runbook

## Scope
Primary recovery flow for domain `loop_gap`.

## Detect
1. `./bin/ops cap run spine.log.query -- --since-hours 24 --domain loop_gap --status failed`
2. `./bin/ops cap run verify.run -- domain loop_gap`

## Diagnose
1. Review latest failing run key receipt in `receipts/sessions/`.
2. Review domain contract and plugin scripts for the failing surface.
3. Confirm runtime path usage resolves through `ops/lib/spine-paths.sh`.

## Recover
1. Apply the minimal fix in the owning plugin/contract.
2. Re-run targeted domain verify.
3. Re-run `verify.run -- fast`.

## Exit Criteria
- Domain verify has zero blocking failures.
- Fast verify has zero blocking failures.
- Failure cause and remediation are reflected in commit and receipt evidence.

