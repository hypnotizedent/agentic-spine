---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: mint-aof-acceptance-v1
parent_loop: LOOP-MINT-AOF-BASELINE-V1-20260217
---

# Mint AOF Acceptance v1

## Measurable Acceptance Criteria

1. Mint baseline contract docs are present and authoritative.
2. Enforcement policy is documented with changed-files ratchet and exception expiry.
3. Canonical Mint template docs exist in `mint-modules` with ADR references.
4. Verify core and verify domain `aof` pass after each phase.
5. Workbench docs AOF check passes after template phase.
6. `GAP-OP-590` remains open and linked to `LOOP-WORKBENCH-AOF-HARDENING-V2-20260217`.

## Phase Exit Checks

### Phase 1 Exit

1. `MINT_AOF_CONTRACT_V1.md` published.
2. `MINT_AOF_ENFORCEMENT_V1.md` published.
3. `MINT_AOF_ACCEPTANCE_V1.md` published.
4. `verify.core.run` pass and `verify.domain.run aof --force` pass.

### Phase 2 Exit

1. Six canonical template docs created in `mint-modules/docs/CANONICAL/`.
2. Each template includes frontmatter, no-runtime-mutation note, ADR references.
3. `verify.core.run` pass, `verify.domain.run aof --force` pass.
4. `workbench-aof-check --mode docs` pass.

### Phase 3 Exit

1. Execution runway audit artifact created.
2. Loop scope file updated with evidence run keys.
3. No proposal queue mutation occurred in this run.
4. Final verify and status checks pass.

## Required Receipts/Evidence per Feature Lane

For each lane (starting with supplier sync and job estimator):

1. Preflight run keys (`stability`, `core`, routed domain checks).
2. Proposal ID and apply commit SHA.
3. Contract compliance note referencing baseline sections used.
4. Rollback/remediation note for any exception.
