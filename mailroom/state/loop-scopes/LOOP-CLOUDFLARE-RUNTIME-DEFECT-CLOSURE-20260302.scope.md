---
loop_id: LOOP-CLOUDFLARE-RUNTIME-DEFECT-CLOSURE-20260302
created: 2026-03-02
status: active
owner: "@ronny"
scope: cloudflare
priority: high
horizon: now
execution_readiness: runnable
objective: Fix Cloudflare runtime defects (service.publish/inventory.sync/domains.portfolio.status/registrar.status) and add deterministic smoke coverage
---

# Loop Scope: LOOP-CLOUDFLARE-RUNTIME-DEFECT-CLOSURE-20260302

## Objective

Fix Cloudflare runtime defects (service.publish/inventory.sync/domains.portfolio.status/registrar.status) and add deterministic smoke coverage

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-CLOUDFLARE-RUNTIME-DEFECT-CLOSURE-20260302`

## Phases
- W0:  reproduce+classify defects with run keys
- W1:  parser/runtime defect fixes
- W2:  smoke gate and verify coverage
- W3:  gap and loop closure receipts

## Success Criteria
- All four runtime defects reproduce before fix and pass after fix
- No introduced fast verify failures
- Cloudflare read-path and smoke checks pass in one run

## Definition Of Done
- Each fix has run-key evidence before and after
- Any residual issue is filed as an open gap linked to loop
