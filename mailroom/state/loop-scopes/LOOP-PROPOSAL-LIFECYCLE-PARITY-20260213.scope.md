---
loop_id: LOOP-PROPOSAL-LIFECYCLE-PARITY-20260213
status: active
severity: medium
owner: "@ronny"
created: 2026-02-13
---

# Loop Scope: Proposal Lifecycle Parity

## Goal
Close residual lifecycle and control-plane gaps discovered after LOOP-PROPOSAL-LIFECYCLE-HARDENING-20260213 (commit 7c0e255).

## Scope
- Fix proposals-apply ISO timestamp truncation
- Enforce D83 required-field parity with proposals.lifecycle.yaml
- Add proposal queue visibility to ops status, session-entry-hook, and Terminal C runbook
- Surface planned loops in ops status

## Gaps
- GAP-OP-259: proposals.apply timestamp truncation
- GAP-OP-260: D83 lifecycle parity mismatch
- GAP-OP-261: control-plane proposal queue observability
- GAP-OP-262: planned loop visibility in ops status

## Acceptance
- spine.verify PASS (84+ gates)
- All 4 gaps closed with evidence
- ops status shows proposal queue + planned loops
- D83 enforces created field + independent superseded fields
