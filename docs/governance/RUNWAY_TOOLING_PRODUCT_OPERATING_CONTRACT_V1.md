---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
scope: runway-tooling-product-operating-contract
---

# Runway/Tooling/Product Operating Contract v1

Purpose: keep `agentic-spine` (runway), `workbench` (tooling), and
`mint-modules` (product) in sync while allowing parallel terminal execution.

## 1. Authority Split

| Repo | Role | Owns | Does Not Own |
|------|------|------|--------------|
| `agentic-spine` | Runway/governance | loops, gaps, capabilities, receipts, SSOT bindings, drift gates | product source code |
| `workbench` | Tooling surface | compose/script/tooling assets used by operators | governance truth, runtime receipts |
| `mint-modules` | Product surface | module code, tests, API/schema specs, release artifacts | cross-repo governance bindings |

If sources disagree on governance facts, spine is authoritative.

## 2. Parallel Session Model

Parallel terminals are allowed. Uncoordinated writes are not.

Required model per repo:

1. Declare one active write owner per repo at a time.
2. All non-owners in that repo run read-only or produce proposals/handoffs.
3. Change write owner only at explicit handoff boundaries.

This is how parallelism stays predictable without hidden branch collisions.

## 3. Branch and Worktree Discipline

- Worktrees are optional. Isolation is mandatory when multiple writers exist.
- Never let two active terminals write to the same branch.
- If worktrees are used, one lane maps to one worktree and one branch.
- After merge, retire lane worktrees promptly (`ops close loop <LOOP_ID>` or equivalent).
- If you encounter a dirty tree you did not create, stop and coordinate first.

## 4. Cross-Repo Change Contract

A single logical change may touch runway, tooling, and product. Treat it as one
governed unit:

1. Anchor the work in a spine loop/gap.
2. Declare primary repo plus related repos.
3. Execute writes in a deterministic order (no "simultaneous commit" assumption).
4. Record proof per repo (commit SHA/receipt linkage).
5. Close the loop only after all declared repos are reconciled.

Git cannot provide atomic commits across repos. Ordered integration + proof is
the safety mechanism.

## 5. Sync Checkpoints (Anti-Drift)

At intake:
- Confirm authority split before coding.
- Confirm who is write owner per repo.

During execution:
- Keep runtime/governance changes in spine.
- Keep tooling edits in workbench.
- Keep product code/spec changes in mint-modules.

Before closeout:
- Reconcile related SSOT updates in spine when product/tooling facts changed.
- Verify loop and receipts reflect all repos touched.

## 6. Documentation and Indexing Requirements

Any new governance contract must be registered in all three surfaces:

1. `docs/governance/_index.yaml` (machine index)
2. `docs/README.md` (human landing index)
3. `docs/governance/GOVERNANCE_INDEX.md` (governance narrative index)

When RAG indexing is active, run the governed indexing path after doc merge so
retrieval reflects the updated contract.

## 7. Non-Negotiables

- No dual truth for governance bindings outside spine.
- No concurrent multi-writer work on the same repo branch.
- No loop closeout without cross-repo proof when related repos were declared.
- No "quick fix" outside the declared authority boundary.

v1 intent: maximize consistency, stability, and predictability while preserving
parallel execution speed.
