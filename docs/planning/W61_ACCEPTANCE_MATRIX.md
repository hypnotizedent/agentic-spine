# W61_ACCEPTANCE_MATRIX

Status: final
Wave: LOOP-SPINE-W61-ENTRY-PROJECTION-VERIFY-UNIFICATION-20260228-20260303
Owner: @ronny
Mode: deterministic fill-only (no freeform substitutions)

## Metadata
| field | expected | actual |
|---|---|---|
| branch | `codex/w61-entry-projection-verify-unification-20260228` | `codex/w61-entry-projection-verify-unification-20260228` |
| base_main_sha | `<sha>` | `5c2454f27d8a5e3483180ed3913f6e082f9b9e2e` |
| final_main_sha | `<sha>` | `2c07e4a337eea4eae95889a80cf35118743f843a` |
| decision | `DONE` or `HOLD_WITH_BLOCKERS` | `DONE` |
| protected_lane_mutation | `false` | `false` |
| vm_infra_runtime_mutation | `false` | `false` |
| secret_values_printed | `false` | `false` |

## Required Run Keys
| check | expected | run_key | result | notes |
|---|---|---|---|---|
| session.start | done | `CAP-20260227-220057__session.start__R0qds9179` | PASS | fast session started |
| gate.topology.validate | pass | `CAP-20260227-215557__gate.topology.validate__R4p3d64506` | PASS | topology + assignments valid |
| verify.route.recommend | done | `CAP-20260227-215600__verify.route.recommend__Rynzc64960` | PASS | recommended `core` |
| verify.pack.run core | pass | `CAP-20260227-215602__verify.pack.run__R0aqc65390` | PASS | 15/15 pass |
| verify.pack.run secrets | pass | `CAP-20260227-215610__verify.pack.run__Rarrp66516` | PASS | 23/23 pass |
| verify.pack.run communications | pass or known-exception | `CAP-20260227-215610__verify.pack.run__R4fvg66515` | PASS | 32/32 pass |
| verify.pack.run mint | pass or known-exception | `CAP-20260227-215610__verify.pack.run__R8e0366517` | PASS | 39/39 pass (includes D275) |
| loops.status | done | `CAP-20260227-215651__loops.status__Rag9x81111` | PASS | open loops reported |
| gaps.status | done | `CAP-20260227-215652__gaps.status__Runk881109` | PASS | orphaned gaps=0 |

## Acceptance Matrix

### A. Authority Concern Map
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-A1 | Canonical concern map exists | `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml` present | file present and committed | `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml` | PASS |  |  |
| W61-A2 | Single-authority lock consumes concern map | D275 (or successor) reads concern map path | D275 reads `ops/bindings/authority.concerns.yaml` | `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d275-single-authority-per-concern-lock.sh` + run key `CAP-20260227-215610__verify.pack.run__R8e0366517` | PASS |  |  |
| W61-A3 | No duplicate authorities per concern | zero duplicate authority claims across mapped surfaces | enforced by D275; no violation | run key `CAP-20260227-215610__verify.pack.run__R8e0366517` (D275 PASS) | PASS |  |  |
| W61-A4 | No-new-authority rule enforced | commit introducing new authority also updates concern map | D275 scans authoritative markers and fails unmapped claims | `/Users/ronnyworks/code/agentic-spine/surfaces/verify/d275-single-authority-per-concern-lock.sh` | PASS |  |  |

### B. Entry Projection
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-B1 | Projection capabilities exist | `docs.projection.sync` registered | capability registered and runnable | run key `CAP-20260227-215730__docs.projection.sync__R8q4i88368` | PASS |  |  |
| W61-B2 | Projection verify capability exists | `docs.projection.verify` registered | capability registered and runnable | run key `CAP-20260227-215730__docs.projection.verify__Rj4gt88742` | PASS |  |  |
| W61-B3 | AGENTS projection marker present | projection metadata points to gate registry / concern map | `entry_surface_gate_metadata: projection` and `projection_of` present | `/Users/ronnyworks/code/agentic-spine/AGENTS.md` | PASS |  |  |
| W61-B4 | CLAUDE projection marker present | projection metadata points to gate registry / concern map | `entry_surface_gate_metadata: projection` and `projection_of` present | `/Users/ronnyworks/code/agentic-spine/CLAUDE.md` | PASS |  |  |
| W61-B5 | Generated block drift lock passes | D285 (or successor) PASS | D285 direct run PASS | `./surfaces/verify/d285-entry-surface-gate-metadata-no-manual-drift-lock.sh` | PASS |  |  |

### C. Verify Surface Unification (Shadow Mode)
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-C1 | Canonical wrapper exists | `verify.run <scope>` capability/command exists | capability + wrapper script committed | `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/bin/verify-run` | PASS |  |  |
| W61-C2 | Fast profile mapped | `fast = invariants only` documented + enforced | `fast` maps to core invariants | run key `CAP-20260227-215731__verify.run__Rcax889244` | PASS |  |  |
| W61-C3 | Domain profile mapped | `domain = invariants + freshness(domain)` | wrapper runs `core + <domain>` | run key `CAP-20260227-215734__verify.run__Rok4g88361` | PASS |  |  |
| W61-C4 | Release profile mapped | `release = full` | wrapper executes release path | run key `CAP-20260227-214554__verify.run__Rfp4f82295` | PASS |  |  |
| W61-C5 | Shadow parity report emitted | wrapper vs existing verify paths diff report exists | report emitted | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_VERIFY_WRAPPER_SHADOW_PARITY_REPORT.md` | PASS |  |  |
| W61-C6 | Shadow parity acceptable | no blocking mismatches unexplained | parity deltas zero for fast + domain(communications) | run keys `CAP-20260227-215731__verify.run__Rcax889244`, `CAP-20260227-215734__verify.run__Rok4g88361` | PASS |  |  |

### D. Failure Classification Telemetry
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-D1 | Failure class emitted | blocking failures include `failure_class` | wrapper emits class buckets in output | run key `CAP-20260227-215731__verify.run__Rcax889244` output + history entries | PASS |  |  |
| W61-D2 | Allowed classes enforced | `deterministic`, `freshness`, `gate_bug` only | only allowed classes used | `/Users/ronnyworks/code/agentic-spine/ops/bindings/verify.failure.classification.contract.yaml` | PASS |  |  |
| W61-D3 | Failure history persisted | machine-readable history artifact produced | NDJSON history persisted | `/Users/ronnyworks/code/agentic-spine/ops/plugins/verify/state/verify-failure-class-history.ndjson` | PASS |  |  |
| W61-D4 | Initial quality report produced | gate quality baseline report exists | report emitted | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_FAILURE_CLASS_BASELINE_REPORT.md` | PASS |  |  |

### E. Regression & Closure Integrity
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-E1 | Fix-to-lock closure enforced | D276 (or successor) PASS | D276 direct run PASS | `./surfaces/verify/d276-fix-to-lock-closure-lock.sh` | PASS |  |  |
| W61-E2 | Closed P0/P1 include lock metadata | `root_cause`, `regression_lock_id`, `owner`, `expiry_check` complete | required rows complete | D276 output: `required_rows=14` | PASS |  |  |
| W61-E3 | Gap reference integrity | D284 (or successor) PASS, orphan refs = 0 | D284 PASS + gaps.status orphaned=0 | `./surfaces/verify/d284-gap-reference-integrity-lock.sh` + run key `CAP-20260227-215652__gaps.status__Runk881109` | PASS |  |  |

### F. Lifecycle/Parity/Closeout
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-F1 | Promotion method | ff-only merge path used | used `git merge --ff-only` for all repos | shell history + `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_PROMOTION_PARITY_RECEIPT.md` | PASS |  |  |
| W61-F2 | Main parity | local == origin == github (and share when required) | parity confirmed (`agentic-spine` includes share) | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_PROMOTION_PARITY_RECEIPT.md` | PASS |  |  |
| W61-F3 | Clean status | all touched repos `## main...origin/main` and no dirty files | verified for spine/workbench/mint | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_BRANCH_ZERO_STATUS_REPORT.md` | PASS |  |  |
| W61-F4 | Protected lanes untouched | mail-archiver / GAP-OP-973 / EWS / MD1400 untouched | no edits/mutations to protected lanes | attestation in supervisor receipt | PASS |  |  |
| W61-F5 | Required receipts emitted | supervisor + parity + shadow + failure-class reports exist | all required W61 artifacts emitted | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_SUPERVISOR_MASTER_RECEIPT.md` and related docs | PASS |  |  |

## Evidence Artifacts (must be absolute paths)
| artifact | required_path | actual_path | exists (yes/no) |
|---|---|---|---|
| supervisor_receipt | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_SUPERVISOR_MASTER_RECEIPT.md` | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_SUPERVISOR_MASTER_RECEIPT.md` | yes |
| promotion_parity_receipt | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_PROMOTION_PARITY_RECEIPT.md` | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_PROMOTION_PARITY_RECEIPT.md` | yes |
| verify_shadow_report | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_VERIFY_WRAPPER_SHADOW_PARITY_REPORT.md` | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_VERIFY_WRAPPER_SHADOW_PARITY_REPORT.md` | yes |
| failure_class_report | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_FAILURE_CLASS_BASELINE_REPORT.md` | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_FAILURE_CLASS_BASELINE_REPORT.md` | yes |
| concern_map | `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml` | `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml` | yes |

## Known Exceptions Register
| id | scope | exception_rule | approval_reference | expiry | status |
|---|---|---|---|---|---|
| W61-X1 | none | none | n/a | n/a | closed |

## Final Decision Block
| field | value |
|---|---|
| final_decision | DONE |
| blocker_count | 0 |
| blockers_open | none |
| promoted_to_main | true |
| promotion_sha | `2c07e4a337eea4eae95889a80cf35118743f843a` |
| attestation_no_protected_lane_mutation | true |
| attestation_no_vm_infra_runtime_mutation | true |
| attestation_no_secret_value_printing | true |

## Signoff
- supervisor_terminal: `SPINE-CONTROL-01`
- completion_utc: `2026-02-28T03:00:00Z`
- reviewer_1: `n/a`
- reviewer_2: `n/a`
- reviewer_3: `n/a`
