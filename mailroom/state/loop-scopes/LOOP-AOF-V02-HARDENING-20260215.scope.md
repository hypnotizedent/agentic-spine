---
loop_id: LOOP-AOF-V02-HARDENING-20260215
status: open
created: 2026-02-15
owner: "@ronny"
scope: aof-v02-hardening
---

# AOF v0.2 Hardening

## Objective
Fix three post-audit issues from the AOF v0.2 enforcement implementation:
plugin manifest exposure drift, fail_action tier semantics, and cap runner integration test.

## Gaps
- GAP-OP-386: MANIFEST.yaml missing aof.contract.acknowledge capability
- GAP-OP-387: fail_action from drift-gates.scoped.yaml not consumed by runtime
- GAP-OP-388: No cap runner integration test for contract ack enforcement

## Deliverables
1. MANIFEST.yaml aof plugin lists all 4 capabilities
2. drift-gate.sh reads fail_action per tier; warn tiers downgrade all failures
3. Integration test exercises actual cap runner path with .environment.yaml present
4. Tests for all items
