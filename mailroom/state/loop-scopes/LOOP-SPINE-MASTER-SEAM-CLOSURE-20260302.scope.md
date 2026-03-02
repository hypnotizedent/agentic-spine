---
loop_id: LOOP-SPINE-MASTER-SEAM-CLOSURE-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: agentic-spine
priority: high
horizon: later
execution_readiness: blocked
next_review: "2026-03-09"
objective: Close remaining execution seams across terminal UX wiring, receipt format bridge, execution drift-gate backstop, and mailroom ergonomics.
blocked_by: "Overnight intake. Requires operator approval and scoped wave scheduling before promotion."
---

# Loop Scope: Master Spine Seam Closure

## Problem Statement

Recent hardening waves stabilized the core runtime (role enforcement, wave state machine, mailroom boundaries), but high-friction seams remain:

1. Terminal UX still exposes raw IDs and lacks role-aware title propagation.
2. Receipt generation path still emits markdown-first artifacts while execution contracts expect structured evidence-rich JSON.
3. Independent execution drift-gate backstops are missing for wave packet integrity and DoD closeout invariants.
4. Cross-repo and CLI ergonomics still carry naming/path/flag inconsistencies that create repeated operator friction.

This loop is a planning and orchestration container for execution-ready closure of those seams.

## Deliverables

1. Canonical terminal label/title propagation plan with explicit Hammerspoon + shell entry wiring.
2. Receipt bridge plan aligning generated artifacts with `orchestration.exec_receipt.schema.json`.
3. Execution contract drift-gate pack plan (6 gates) with ring placement and performance constraints.
4. Cross-repo normalization plan for path style, entry symmetry, legacy alias handling, and wrapper boundaries.
5. Mailroom lifecycle ergonomics plan for plans retire/cancel and loop/gap/proposal flag contract normalization.

## Execution Waves

### W0: Baseline & Claim Matrix
- Build source-of-truth claim matrix for all seam findings.
- Confirm overlaps with existing open gaps and avoid duplication.

### W1: Terminal UX Wiring
- Bind terminal launcher labels to hotkey picker and alert surfaces.
- Set terminal title contract at session entry (`{label} [{runtime_role}]`).
- Define compatibility behavior for terminals without title support.

### W2: Receipt Bridge
- Design/implement JSON receipt output path with `evidence_refs`.
- Align run-key namespace contract (CAP/S prefixes) without breaking existing receipts.
- Add migration notes and validation contract.

### W3: Drift-Gate Backstop
- Add execution contract verification gates:
  - wave packet integrity
  - DoD closeout block integrity
  - evidence refs schema parity
  - traffic index freshness
  - path-claim overlap
  - role-handoff boundary
- Register gate ring placement outside saturated core profile.

### W4: Cross-Repo & Mailroom Ergonomics
- Normalize path/entry conventions and alias contract documentation.
- Define plans retire/cancel lifecycle behavior and operator workflow.
- Normalize loop/gap/proposal binding flags and help text discoverability.

### W5: Verify & Closeout
- Run fast + touched-gate verifies.
- Produce blocker classification and rollback notes.
- Close loop or keep planned with explicit blockers.

## Acceptance Criteria

- Terminal title + label propagation is contract-defined and implemented.
- Receipt generation path produces schema-compatible evidence-carrying artifacts.
- Execution seam gates exist and are wired into gate registry/topology.
- Plans lifecycle includes explicit retire/cancel semantics.
- CLI flag contract for loop binding is normalized and documented.
- No orphan gaps; all seam work is linked to active/planned loops.

## Linked Gaps

- GAP-OP-1342: Terminal launcher label/title propagation seam
- GAP-OP-1343: Receipt generation format mismatch (markdown vs schema JSON)
- GAP-OP-1344: Run-key namespace mismatch and contract drift
- GAP-OP-1345: Missing execution contract drift-gate backstop pack
- GAP-OP-1346: Cross-repo path/entry/wrapper consistency drift
- GAP-OP-1347: Legacy terminal role alias ambiguity
- GAP-OP-1348: Missing plans retire/cancel lifecycle
- GAP-OP-1349: Loop/gap/proposal binding flag and submit ergonomics inconsistency

## Receipts

- (populate during execution waves)

