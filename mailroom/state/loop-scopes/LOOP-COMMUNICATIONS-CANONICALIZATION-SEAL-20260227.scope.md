---
loop_id: LOOP-COMMUNICATIONS-CANONICALIZATION-SEAL-20260227
created: 2026-02-27
status: closed
owner: "@ronny"
scope: communications
priority: high
objective: Canonicalize communications governance surfaces (docs impact routing, capability projection parity, account linkage contract truth, import status semantics, backup parity, and migration-source tombstones) in one governed sequence.
---

# Loop Scope: LOOP-COMMUNICATIONS-CANONICALIZATION-SEAL-20260227

## Objective

Canonicalize communications governance surfaces (docs impact routing, capability projection parity, account linkage contract truth, import status semantics, backup parity, and migration-source tombstones) in one governed sequence.

## Phases
- Step 1:  Fix docs impact routing parity for communications (DONE)
- Step 2:  Normalize communications capability projections across registries (DONE)
- Step 3:  Normalize mail account linkage contract states (DONE)
- Step 4:  Harden import status state machine (DONE)
- Step 5:  Add stalwart app-level backup inventory + schedule parity (DONE)
- Step 6:  Tombstone migration-source residues (DONE)

## Success Criteria
- All six communications canonicalization gaps filed and fixed with receipts
- verify.pack.run communications remains PASS
- gaps.status shows no orphaned gaps

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.

## Gap Linkage
- GAP-OP-1003: fixed
- GAP-OP-1004: fixed
- GAP-OP-1005: fixed
- GAP-OP-1006: fixed
- GAP-OP-1007: fixed
- GAP-OP-1008: fixed
