---
loop_id: LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: mailroom
priority: medium
horizon: later
execution_readiness: blocked
blocked_by: "operator_hardware_decision + self_hosted_inference_contract_authoring"
objective: Define and lock the canonical self-hosted watcher inference contract, procurement profile, and migration/rollback policy for autonomous low-recurring-cost execution.
---

# Loop Scope: LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303

## Objective

Define and lock the canonical self-hosted watcher inference contract, procurement profile, and migration/rollback policy for autonomous low-recurring-cost execution.

## Guard Commands

- **Verify**: `./bin/ops cap run verify.run -- domain infra`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "self-hosted watcher contract checkpoint" --loops LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303`

## Phases
- W0: define contract schema for local provider identity, health checks, and fallback semantics
- W1: define hardware profile tiers + procurement acceptance criteria for 24/7 watcher workloads
- W2: define migration/rollback transaction from paid-provider lane to local-first lane
- W3: add regression locks for contract freshness and drift-proof rollout controls

## Success Criteria
- Canonical self-hosted watcher provider contract is committed and referenced by watcher runtime surfaces.
- Procurement profile tiers and acceptance thresholds are codified in governance bindings.
- Migration/rollback policy is executable and linked to verify evidence surfaces.

## Definition Of Done
- `GAP-OP-1376` fixed with concrete `fixed_in` evidence.
- Domain verify passes for touched surfaces with receipts recorded.
