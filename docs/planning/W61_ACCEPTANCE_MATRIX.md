# W61_ACCEPTANCE_MATRIX

Status: draft-template
Wave: LOOP-SPINE-W61-ENTRY-PROJECTION-VERIFY-UNIFICATION-20260228-20260303
Owner: @ronny
Mode: deterministic fill-only (no freeform substitutions)

## Fill Rules
1. Fill every `actual` and `evidence` cell.
2. `result` must be one of: `PASS`, `FAIL`, `BLOCKED`, `N/A`.
3. If `FAIL` or `BLOCKED`, fill `blocker_id` and `next_action`.
4. Use exact run keys (`CAP-...`) and exact file paths.
5. Do not delete rows.

## Metadata
| field | expected | actual |
|---|---|---|
| branch | `codex/w61-entry-projection-verify-unification-20260228` | |
| base_main_sha | `<sha>` | |
| final_main_sha | `<sha>` | |
| decision | `DONE` or `HOLD_WITH_BLOCKERS` | |
| protected_lane_mutation | `false` | |
| vm_infra_runtime_mutation | `false` | |
| secret_values_printed | `false` | |

## Required Run Keys
| check | expected | run_key | result | notes |
|---|---|---|---|---|
| session.start | done | | | |
| gate.topology.validate | pass | | | |
| verify.route.recommend | done | | | |
| verify.pack.run core | pass | | | |
| verify.pack.run secrets | pass | | | |
| verify.pack.run communications | pass or known-exception | | | |
| verify.pack.run mint | pass or known-exception | | | |
| loops.status | done | | | |
| gaps.status | done | | | |

## Acceptance Matrix

### A. Authority Concern Map
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-A1 | Canonical concern map exists | `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml` present | | | | | |
| W61-A2 | Single-authority lock consumes concern map | D275 (or successor) reads concern map path | | | | | |
| W61-A3 | No duplicate authorities per concern | zero duplicate authority claims across mapped surfaces | | | | | |
| W61-A4 | No-new-authority rule enforced | commit introducing new authority also updates concern map | | | | | |

### B. Entry Projection
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-B1 | Projection capabilities exist | `docs.projection.sync` registered | | | | | |
| W61-B2 | Projection verify capability exists | `docs.projection.verify` registered | | | | | |
| W61-B3 | AGENTS projection marker present | projection metadata points to gate registry / concern map | | | | | |
| W61-B4 | CLAUDE projection marker present | projection metadata points to gate registry / concern map | | | | | |
| W61-B5 | Generated block drift lock passes | D285 (or successor) PASS | | | | | |

### C. Verify Surface Unification (Shadow Mode)
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-C1 | Canonical wrapper exists | `verify.run <scope>` capability/command exists | | | | | |
| W61-C2 | Fast profile mapped | `fast = invariants only` documented + enforced | | | | | |
| W61-C3 | Domain profile mapped | `domain = invariants + freshness(domain)` | | | | | |
| W61-C4 | Release profile mapped | `release = full` | | | | | |
| W61-C5 | Shadow parity report emitted | wrapper vs existing verify paths diff report exists | | | | | |
| W61-C6 | Shadow parity acceptable | no blocking mismatches unexplained | | | | | |

### D. Failure Classification Telemetry
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-D1 | Failure class emitted | blocking failures include `failure_class` | | | | | |
| W61-D2 | Allowed classes enforced | `deterministic`, `freshness`, `gate_bug` only | | | | | |
| W61-D3 | Failure history persisted | machine-readable history artifact produced | | | | | |
| W61-D4 | Initial quality report produced | gate quality baseline report exists | | | | | |

### E. Regression & Closure Integrity
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-E1 | Fix-to-lock closure enforced | D276 (or successor) PASS | | | | | |
| W61-E2 | Closed P0/P1 include lock metadata | `root_cause`, `regression_lock_id`, `owner`, `expiry_check` complete | | | | | |
| W61-E3 | Gap reference integrity | D284 (or successor) PASS, orphan refs = 0 | | | | | |

### F. Lifecycle/Parity/Closeout
| id | requirement | expected | actual | evidence | result | blocker_id | next_action |
|---|---|---|---|---|---|---|---|
| W61-F1 | Promotion method | ff-only merge path used | | | | | |
| W61-F2 | Main parity | local == origin == github (and share when required) | | | | | |
| W61-F3 | Clean status | all touched repos `## main...origin/main` and no dirty files | | | | | |
| W61-F4 | Protected lanes untouched | mail-archiver / GAP-OP-973 / EWS / MD1400 untouched | | | | | |
| W61-F5 | Required receipts emitted | supervisor + parity + shadow + failure-class reports exist | | | | | |

## Evidence Artifacts (must be absolute paths)
| artifact | required_path | actual_path | exists (yes/no) |
|---|---|---|---|
| supervisor_receipt | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_SUPERVISOR_MASTER_RECEIPT.md` | | |
| promotion_parity_receipt | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_PROMOTION_PARITY_RECEIPT.md` | | |
| verify_shadow_report | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_VERIFY_WRAPPER_SHADOW_PARITY_REPORT.md` | | |
| failure_class_report | `/Users/ronnyworks/code/agentic-spine/docs/planning/W61_FAILURE_CLASS_BASELINE_REPORT.md` | | |
| concern_map | `/Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml` | | |

## Known Exceptions Register
| id | scope | exception_rule | approval_reference | expiry | status |
|---|---|---|---|---|---|
| W61-X1 | | | | | |

## Final Decision Block
| field | value |
|---|---|
| final_decision | |
| blocker_count | |
| blockers_open | |
| promoted_to_main | |
| promotion_sha | |
| attestation_no_protected_lane_mutation | |
| attestation_no_vm_infra_runtime_mutation | |
| attestation_no_secret_value_printing | |

## Signoff
- supervisor_terminal: `SPINE-CONTROL-01`
- completion_utc: 
- reviewer_1: 
- reviewer_2: 
- reviewer_3: 
