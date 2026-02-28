# W60 Fix To Lock Mapping

Date: 2026-02-28 (UTC)
Wave: `LOOP-SPINE-W60-SUPERVISOR-CANONICAL-UPGRADE-20260227-20260302`

| finding_id | root_cause | regression_lock_id | owner | expiry_check | lock_evidence | notes |
|---|---|---|---|---|---|---|
| W60-F003 | Ghost modules lacked an explicit lifecycle contract and machine check. | MINT-LIFECYCLE-L1 | @ronny | 2026-03-31 | `/Users/ronnyworks/code/mint-modules/scripts/guard/module-runtime-lifecycle-lock.sh` PASS | Lifecycle registry + guard added. |
| W60-F004 | Domain mapping existed across files but no parity bridge contract/gate. | D283 | @ronny | 2026-03-31 | `surfaces/verify/d283-domain-taxonomy-bridge-parity-lock.sh` PASS | Bridge contract now canonical. |
| W60-F005 | Concern winners/projections were not uniformly marker-enforced. | D275 | @ronny | 2026-03-31 | `surfaces/verify/d275-single-authority-per-concern-lock.sh` PASS | Enforces single authority + projection/tombstone states. |
| W60-F006 | Entry-surface gate metadata was hand-edited and drift-prone. | D285 | @ronny | 2026-03-31 | `surfaces/verify/d285-entry-surface-gate-metadata-no-manual-drift-lock.sh` PASS | Generated from `gate.registry` via generator contract. |
| W60-F007 | No dedicated parity lock for high-churn gate-domain profiles. | D278 | @ronny | 2026-03-31 | `surfaces/verify/d278-gate-domain-profiles-high-churn-parity-lock.sh` PASS | Prevents unknown/duplicate gate IDs. |
| W60-F008 | No dedicated parity lock for high-churn plugin manifest. | D279 | @ronny | 2026-03-31 | `surfaces/verify/d279-plugins-manifest-high-churn-parity-lock.sh` PASS | Validates plugin path/script/capability references. |
| W60-F009 | No dedicated parity lock for high-churn services health projection. | D280 | @ronny | 2026-03-31 | `surfaces/verify/d280-services-health-high-churn-parity-lock.sh` PASS | Enforces projection marker + host integrity. |
| W60-F010 | Decommissioned SSH targets had no active-reference guard rail. | D281 | @ronny | 2026-03-31 | `surfaces/verify/d281-ssh-target-lifecycle-lock.sh` PASS | Blocks dead target reuse in active surfaces. |
| W60-F011 | Wrong-domain verify routing had no targeted correctness lock. | D282 | @ronny | 2026-03-31 | `surfaces/verify/d282-verify-routing-correctness-lock.sh` PASS | Validates canonical domain routing anchors. |
| W60-F012 | Gap linkage integrity was not machine-checked across active closure docs. | D284 | @ronny | 2026-03-31 | `surfaces/verify/d284-gap-reference-integrity-lock.sh` PASS | Prevents orphan gap references. |
| W60-F013 | Freshness reconciliation scheduler lacked observed-runtime requirement lock. | D277 | @ronny | 2026-03-31 | `surfaces/verify/d277-runtime-freshness-reconcile-automation-lock.sh` PASS | Requires schedule + runtime probe wiring. |
| W60-F014 | Verify failures were not split into deterministic vs freshness classes. | D287 | @ronny | 2026-03-31 | `surfaces/verify/d287-verify-failure-snapshot-fatigue-lock.sh` PASS | Snapshot fatigue control lock added. |
| W60-F015 | Receipts subtraction lifecycle lacked checksum-gated automated path. | D288 | @ronny | 2026-03-31 | `surfaces/verify/d288-receipts-subtraction-automation-lock.sh` PASS | Automates >30d reconciliation path. |
| W60-F016 | P0/P1 closure could ship without root-cause/lock/owner/expiry evidence. | D276 | @ronny | 2026-03-31 | `surfaces/verify/d276-fix-to-lock-closure-lock.sh` PASS | Holistic-fix closure lock. |
| W60-F017 | Duplicate concern surfaces had uneven projection/tombstone metadata quality. | D275 | @ronny | 2026-03-31 | `surfaces/verify/d275-single-authority-per-concern-lock.sh` PASS | Concern-map enforcement reused. |
| W60-F018 | New W60 lock scripts were not registered in registry/topology/profile. | D278 | @ronny | 2026-03-31 | `rg -n "D27[5-9]|D28[0-8]" ops/bindings/gate.registry.yaml ops/bindings/gate.execution.topology.yaml ops/bindings/gate.domain.profiles.yaml` | Registration parity confirmed. |
