---
loop_id: LOOP-MINT-SHIPPING-PAYMENT-MONEY-TRACE-HARDENING-20260308
created: 2026-03-08
status: active
owner: "@ronny"
scope: mint
priority: high
horizon: now
execution_readiness: runnable
execution_mode: orchestrator_subagents
objective: Harden live shipping/payment money trace so provider actions, module persistence, and finance evidence agree
---

# Loop Scope: LOOP-MINT-SHIPPING-PAYMENT-MONEY-TRACE-HARDENING-20260308

## Objective

Harden live shipping/payment money trace so provider actions, module persistence, and finance evidence agree

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-MINT-SHIPPING-PAYMENT-MONEY-TRACE-HARDENING-20260308`

## Phases
- Restore finance ledger path for shipping money events
- Fix provider-origin Stripe webhook boundary
- Close refund/payment forensic gaps with live canaries

## Success Criteria
- A purchased shipping label writes both shipping state and finance ledger evidence
- A provider-origin Stripe webhook reaches live payment without internal module auth
- Live money canaries leave deterministic receipts and reconciliation evidence

## Definition Of Done
- shipping finance events persist beyond module-local state
- finance-adapter schema exists and is migrated live
- Stripe webhook route is provider-deliverable
