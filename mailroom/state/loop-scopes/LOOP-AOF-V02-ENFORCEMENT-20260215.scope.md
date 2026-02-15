---
loop_id: LOOP-AOF-V02-ENFORCEMENT-20260215
status: open
created: 2026-02-15
owner: "@ronny"
scope: aof-v02-enforcement
---

# AOF v0.2 Enforcement

## Objective
Wire AOF contract enforcement into cap.sh (mutating/destructive blocks without daily ack),
add mint-modules pilot test, and implement tier-scoped gate enforcement in drift-gate.sh.

## Gaps
- GAP-OP-382: Contract acknowledgment enforcement in cap.sh
- GAP-OP-383: Mint-modules pilot end-to-end test
- GAP-OP-384: Scoped gate enforcement via drift-gates.scoped.yaml

## Deliverables
1. cap.sh blocks mutating/destructive caps when .environment.yaml present but not acknowledged
2. aof.contract.acknowledge capability registered
3. Mint-modules pilot test validates full contract flow
4. drift-gate.sh respects tier-based gate categories from drift-gates.scoped.yaml
5. Tests for all three items
