---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-27
scope: w45e-secrets-promotion-cert
---

# W45E Secrets Promotion Cert (D245-D250)

## Promotion Rule
- Report mode requires `3` clean runs before `report -> enforce`.
- A clean run means `D245..D250` each report `PASS` with `findings=0`.

## Report Runs
- report_run_1: PASS
- report_run_2: PASS
- report_run_3: PASS

## Run Keys
- report_run_1_keys:
  - secrets: `CAP-20260227-042004__verify.pack.run__Rh2va99656`
  - mint: `CAP-20260227-042018__verify.pack.run__Ruj5r7120`
- report_run_2_keys:
  - secrets: `CAP-20260227-042044__verify.pack.run__Rrp6b16955`
  - mint: `CAP-20260227-042058__verify.pack.run__Rlfjk24488`
- report_run_3_keys:
  - secrets: `CAP-20260227-042115__verify.pack.run__Recut30290`
  - mint: `CAP-20260227-042130__verify.pack.run__Raohg16948`

## Summary
- findings_total: 0
- promotion_decision: ENFORCE_APPROVED

## Baseline Exception Note
- Mint pack `D205` remains unchanged baseline-only noise in clean worktrees; this cert gates `D245..D250` promotion readiness only.
