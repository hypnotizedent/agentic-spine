---
loop_id: LOOP-EXECUTION-LIFECYCLE-VAULTWARDEN-HYGIENE-CANONICALIZATION-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: execution
priority: high
horizon: now
execution_readiness: runnable
objective: Enforce canonical Vaultwarden lifecycle transaction for evidence retention, stale URL reconciliation, duplicate-truth governance, alias hygiene, and deterministic closeout proof.
---

# Loop Scope: LOOP-EXECUTION-LIFECYCLE-VAULTWARDEN-HYGIENE-CANONICALIZATION-20260302

## Objective

Enforce canonical Vaultwarden lifecycle transaction for evidence retention, stale URL reconciliation, duplicate-truth governance, alias hygiene, and deterministic closeout proof.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-EXECUTION-LIFECYCLE-VAULTWARDEN-HYGIENE-CANONICALIZATION-20260302`

## Phases
- W1:  formalize lifecycle evidence retention contract
- W2:  normalize stale URL and alias surfaces to canonical hosts
- W3:  execute duplicate-truth remediation with no-loss proof

## Success Criteria
- Vaultwarden lifecycle closes only with canonical evidence + hygiene thresholds
- New vault mutations follow a consistent end-to-end formula

## Definition Of Done
- No manual reminder required for Vaultwarden lifecycle hygiene
