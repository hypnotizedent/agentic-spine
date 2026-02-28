# W60 Regression Lock Catalog

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W60-SUPERVISOR-CANONICAL-UPGRADE-20260227-20260302`

| lock_id | issue_class | artifact | run_command | status |
|---|---|---|---|---|
| D274 | receipt closeout completeness | `surfaces/verify/d274-receipt-closeout-completeness-lock.sh` | `surfaces/verify/d274-receipt-closeout-completeness-lock.sh` | active |
| D275 | single authority per concern | `surfaces/verify/d275-single-authority-per-concern-lock.sh` | `surfaces/verify/d275-single-authority-per-concern-lock.sh` | active |
| D276 | fix-to-lock closure completeness | `surfaces/verify/d276-fix-to-lock-closure-lock.sh` | `surfaces/verify/d276-fix-to-lock-closure-lock.sh` | active |
| D277 | runtime freshness reconciliation automation | `surfaces/verify/d277-runtime-freshness-reconcile-automation-lock.sh` | `surfaces/verify/d277-runtime-freshness-reconcile-automation-lock.sh` | active |
| D278 | high-churn gate domain profiles parity | `surfaces/verify/d278-gate-domain-profiles-high-churn-parity-lock.sh` | `surfaces/verify/d278-gate-domain-profiles-high-churn-parity-lock.sh` | active |
| D279 | high-churn plugins manifest parity | `surfaces/verify/d279-plugins-manifest-high-churn-parity-lock.sh` | `surfaces/verify/d279-plugins-manifest-high-churn-parity-lock.sh` | active |
| D280 | high-churn services health parity | `surfaces/verify/d280-services-health-high-churn-parity-lock.sh` | `surfaces/verify/d280-services-health-high-churn-parity-lock.sh` | active |
| D281 | SSH target lifecycle lock | `surfaces/verify/d281-ssh-target-lifecycle-lock.sh` | `surfaces/verify/d281-ssh-target-lifecycle-lock.sh` | active |
| D282 | verify routing correctness | `surfaces/verify/d282-verify-routing-correctness-lock.sh` | `surfaces/verify/d282-verify-routing-correctness-lock.sh` | active |
| D283 | domain taxonomy bridge parity | `surfaces/verify/d283-domain-taxonomy-bridge-parity-lock.sh` | `surfaces/verify/d283-domain-taxonomy-bridge-parity-lock.sh` | active |
| D284 | gap reference integrity | `surfaces/verify/d284-gap-reference-integrity-lock.sh` | `surfaces/verify/d284-gap-reference-integrity-lock.sh` | active |
| D285 | entry-surface metadata no-manual-drift | `surfaces/verify/d285-entry-surface-gate-metadata-no-manual-drift-lock.sh` | `surfaces/verify/d285-entry-surface-gate-metadata-no-manual-drift-lock.sh` | active |
| D286 | critical asset utilization freshness | `surfaces/verify/d286-critical-asset-utilization-freshness-lock.sh` | `surfaces/verify/d286-critical-asset-utilization-freshness-lock.sh` | active |
| D287 | snapshot-fatigue deterministic/freshness split | `surfaces/verify/d287-verify-failure-snapshot-fatigue-lock.sh` | `surfaces/verify/d287-verify-failure-snapshot-fatigue-lock.sh` | active |
| D288 | receipts subtraction automation | `surfaces/verify/d288-receipts-subtraction-automation-lock.sh` | `surfaces/verify/d288-receipts-subtraction-automation-lock.sh` | active |
| WB-AOF-SECRETS_ALIAS_LOCK | workbench deprecated secret key alias usage in active paths | `workbench/scripts/root/aof/workbench-aof-check.sh` | `cd /Users/ronnyworks/code/workbench && ./scripts/root/aof/workbench-aof-check.sh --mode secrets` | active |
| WB-AOF-RUNTIME-ENDPOINT-LOCK | workbench HA runtime endpoint authority + deprecated endpoint block | `workbench/scripts/root/aof/workbench-aof-check.sh` | `cd /Users/ronnyworks/code/workbench && ./scripts/root/aof/workbench-aof-check.sh --mode secrets` | active |
| MINT-LIFECYCLE-L1 | mint ghost-module deployability lifecycle safety | `mint-modules/scripts/guard/module-runtime-lifecycle-lock.sh` | `cd /Users/ronnyworks/code/mint-modules && ./scripts/guard/module-runtime-lifecycle-lock.sh` | active |

## Coverage Notes

- Required W60 minimum lock set is satisfied by `D274` through `D288` plus workbench/mint repo-native locks.
- `D276` enforces holistic fix closure fields (`root_cause`, `regression_lock_id`, `owner`, `expiry_check`) for closed P0/P1 rows.
