---
loop_id: LOOP-COMMS-ALERT-QUEUE-AUTODISPATCH-20260225
created: 2026-02-25
status: active
owner: "@ronny"
scope: comms
priority: high
objective: Harden communications alert queue to auto-dispatch with scoped preconditions and retry/DLQ for low-friction agent operations
---

# Loop Scope: LOOP-COMMS-ALERT-QUEUE-AUTODISPATCH-20260225

## Objective

Harden communications alert queue to auto-dispatch with scoped preconditions and retry/DLQ for low-friction agent operations

## Phases
- P0: Design+gaps
- P1: Implement worker+retry+dlq
- P2: Wire capabilities+verify

## Success Criteria
- Queue auto-drains without manual flush
- Flush path no longer blocked by unrelated secrets namespace keys
- Failed intents retry with backoff and move to dead-letter after limit

## Definition Of Done
- Receipts for loop, gaps, implementation verify, and queue runtime status
