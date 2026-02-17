---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: mint-job-estimator-step1
parent_loop: LOOP-MINT-JOB-ESTIMATOR-IMPLEMENT-V1-20260217
---

# Mint Job Estimator Implementation Step 1

- loop: LOOP-MINT-JOB-ESTIMATOR-IMPLEMENT-V1-20260217
- gap: GAP-OP-630
- result: implemented + certified

## Runtime slice delivered

- deterministic estimate pipeline for `screen_print`, `embroidery`, `engraving`, `transfers`
- canonical request/response schema for estimator endpoint
- pricing precedence enforcement: contract tables > approved overrides > defaults
- idempotent estimate generation via deterministic key material
- structured failure classification and error payloads
- deterministic replay and multi-method pricing path tests

## Run keys

- `CAP-20260217-142505__verify.core.run__Ru7pp5487`
- `CAP-20260217-142505__verify.domain.run__Rqq0m5496` (mint)
- `CAP-20260217-142505__verify.domain.run__R619c5498` (aof)

## Invariants

- GAP-OP-590 unchanged
- GAP-OP-627 unchanged
