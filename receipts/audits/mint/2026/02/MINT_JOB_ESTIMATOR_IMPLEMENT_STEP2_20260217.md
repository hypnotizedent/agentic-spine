---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: mint-job-estimator-step2
parent_loop: LOOP-MINT-JOB-ESTIMATOR-IMPLEMENT-V2-20260217
---

# Mint Job Estimator Implementation Step 2 (2026-02-17)

- loop: LOOP-MINT-JOB-ESTIMATOR-IMPLEMENT-V2-20260217
- gap: GAP-OP-632
- result: implemented + certified

## Runtime slice delivered

- canonical run evidence fields in estimate responses (`correlation_id`, `requested_at_utc`, normalized snapshot)
- deterministic precedence evidence payload (`contract_table > override > default_policy`, selected source)
- deterministic idempotency/dedupe output preserved for replay parity
- canonical failure-policy classifications implemented:
  - `missing_supplier_price`
  - `stale_inventory`
  - `ambiguous_artwork_specs`
  - `conflicting_overrides`
- remediation metadata surfaced in failure responses

## Validation summary

- `npm --prefix pricing run test` PASS
- `npm --prefix pricing run build` PASS
- `mintctl aof-check --mode api --format text` PASS
- `mintctl aof-check --mode all --format text` PASS
- `mintctl doctor` PASS

## Run keys

- `CAP-20260217-144042__gaps.file__R3joe71671` (register GAP-OP-632)

## Invariants

- GAP-OP-590 unchanged
- GAP-OP-627 unchanged
- proposal queue was read-only in this lane
