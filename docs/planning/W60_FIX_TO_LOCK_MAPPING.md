# W60 Fix-to-Lock Mapping

Source: docs/planning/W60_FINDING_TRUTH_MATRIX.md
Generated: 2026-02-28

| finding_id | root_cause | regression_lock_id | owner | expiry_check | lock_evidence |
|---|---|---|---|---|---|
| W60-F003 | Untracked module lifecycle contract allowed implicit deployability assumptions. | `MINT-LIFECYCLE-L1` | `@ronny` | `2026-03-31` | `test -f /Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_MODULE_LIFECYCLE_REGISTRY_V1.yaml`; `/Users/ronnyworks/code/mint-modules/scripts/guard/module-runtime-lifecycle-lock.sh` |
| W60-F004 | Domain slug/folder mapping existed but parity contract was missing. | `D283` | `@ronny` | `2026-03-31` | `test -f ops/bindings/domain.taxonomy.bridge.contract.yaml`; `surfaces/verify/d283-domain-taxonomy-bridge-parity-lock.sh` |
| W60-F005 | Concern winners were declared but not uniformly marker-locked across all projections/tombstones. | `D275` | `@ronny` | `2026-03-31` | `test -f ops/bindings/single.authority.contract.yaml`; `surfaces/verify/d275-single-authority-per-concern-lock.sh` |
| W60-F006 | Metadata was hand-edited instead of generated from registry authority. | `D285` | `@ronny` | `2026-03-31` | `test -x bin/generators/gen-entry-surface-gate-metadata.sh`; `surfaces/verify/d285-entry-surface-gate-metadata-no-manual-drift-lock.sh` |
| W60-F007 | Repeated drift risk from frequent edits in profile routing surface. | `D278` | `@ronny` | `2026-03-31` | `surfaces/verify/d278-gate-domain-profiles-high-churn-parity-lock.sh` |
| W60-F008 | Frequent plugin inventory edits lacked targeted structure parity enforcement. | `D279` | `@ronny` | `2026-03-31` | `surfaces/verify/d279-plugins-manifest-high-churn-parity-lock.sh` |
| W60-F009 | Projection drift and host-integrity mismatches recurred in health surface updates. | `D280` | `@ronny` | `2026-03-31` | `surfaces/verify/d280-services-health-high-churn-parity-lock.sh` |
| W60-F010 | Lifecycle state existed, but no runtime lock blocked decommissioned target reuse. | `D281` | `@ronny` | `2026-03-31` | `surfaces/verify/d281-ssh-target-lifecycle-lock.sh` |
| W60-F011 | Routing regressions were caught late via broader packs, not targeted domain-routing checks. | `D282` | `@ronny` | `2026-03-31` | `surfaces/verify/d282-verify-routing-correctness-lock.sh` |
| W60-F012 | Gap linkage lacked automated cross-surface integrity check. | `D284` | `@ronny` | `2026-03-31` | `surfaces/verify/d284-gap-reference-integrity-lock.sh` |
| W60-F013 | Scheduled freshness path did not require runtime probe evidence in lock form. | `D277` | `@ronny` | `2026-03-31` | `surfaces/verify/d277-runtime-freshness-reconcile-automation-lock.sh` |
| W60-F014 | Snapshot freshness noise and deterministic breakages were conflated in operator loops. | `D287` | `@ronny` | `2026-03-31` | `surfaces/verify/d287-verify-failure-snapshot-fatigue-lock.sh` |
| W60-F015 | Retention flow relied on manual hygiene cadence with no parity prerequisite lock. | `D288` | `@ronny` | `2026-03-31` | `surfaces/verify/d288-receipts-subtraction-automation-lock.sh`; `ops/plugins/evidence/bin/receipts-checksum-parity-report` |
| W60-F016 | Closure discipline was narrative-only and not machine-checked. | `D276` | `@ronny` | `2026-03-31` | `surfaces/verify/d276-fix-to-lock-closure-lock.sh` |
