# W52 Control to Finding Mapping

Date anchor: 2026-02-27  
Loop: `LOOP-SPINE-W52-CONTAINMENT-AUTOMATION-20260227-20260301`  
Contract: `docs/CANONICAL/W52_FOUNDATIONAL_CONTAINMENT_CONTRACT_V1.yaml`

## Mapping Table

| W51 Finding | Canonical Gap | Gate | Mode (W52A) | Promotion Target | Promotion Criteria Summary |
|---|---|---|---|---|---|
| Container OOM exit containment gap | GAP-OP-1018 | D252 | report | W52B | OOM state classification + escalation routing + 2 clean enforce runs |
| Health probe state-aware policy gap | GAP-OP-1019 | D253 | report | W52B | expected-stopped semantics + zero false degraded alerts + pack pass |
| Image age drift gap (minio stale image policy) | GAP-OP-1020 | D254 | report | W52B | explicit image age thresholds + incident rule + minio below critical budget |
| MD1400 capacity monitoring + guard gap | GAP-OP-1021 | D255 | report | W53 | baseline + threshold policy + scheduled guard execution |
| Credential single-point-of-failure gap | GAP-OP-1022 | D256 | report | W53 | multi-operator recovery path + break-glass SOP + no single-owner critical path |

## Governance Notes

- D252-D256 are report-first gates by contract default (`mode.default_policy: report`).
- Enforce promotion is explicitly blocked until each control's `promotion_criteria` is satisfied and receipted.
- This mapping is canonical for W52A and must remain aligned with the loop-linked open gaps above.
