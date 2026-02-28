# W78 Freshness Coverage Report

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228

## Coverage Delta

| metric | baseline | final | delta |
|---|---:|---:|---:|
| active_freshness_gates | 69 | 70 | +1 |
| mapped_freshness_gates | 12 | 18 | +6 |
| unmapped_freshness_gates | 57 | 53 | -4 |
| freshness_reconcile_unresolved_count | 1 | 1 | 0 |

Notes:
- Final active freshness count reflects W78-added freshness gates D294/D295.
- Final unresolved gate in reconcile output: D148 (`no_refresh_capability`).

## Critical Mapping Check

Required critical gates mapped: `D188`, `D191`, `D192`, `D193`, `D194`, `D205`, `D208`, `D239`

Result: PASS (all listed critical gates mapped in `freshness.reconcile.contract.yaml`).

## Remaining Backlog Governance

- Governance gap opened: `GAP-OP-1149`
- Scope: staged mapping rollout for remaining unmapped freshness gates with evidence-backed capability bindings.
- Parent loop: `LOOP-W78-TRUTH-FIRST-RELIABILITY-HARDENING-20260228`
