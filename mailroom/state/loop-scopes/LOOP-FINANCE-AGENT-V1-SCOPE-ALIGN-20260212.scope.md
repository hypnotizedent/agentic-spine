---
loop_id: LOOP-FINANCE-AGENT-V1-SCOPE-ALIGN-20260212
status: open
owner: "@ronny"
apply_owner: claude
opened: 2026-02-12
scope: Clear finance agent path overlap, register V1, unblock worker
---

# LOOP-FINANCE-AGENT-V1-SCOPE-ALIGN-20260212

## Goal

Lock the canonical finance agent path, apply the V1 registration proposal,
mark firefly-agent + paperless-agent as superseded, and unblock worker.

## Decisions

1. **Canonical path:** `agents/finance` (in workbench repo)
2. **Non-canonical:** `agents/finance-agent` — MUST NOT be implemented
3. **Agent ID:** `finance-agent` (matches existing proposal and registry convention)
4. **Implementation path:** `~/code/workbench/agents/finance/`
5. **CONTEXT_LOCK:** BLOCK → PROCEED (this loop is the scope reference)

## Proposal Applied

CP-20260212-123234__finance-agent-v1-registration--unified-contract---registry-entry---superseded-markers-for-firefly-agent-and-paperless-agent

## Deliverables

1. Apply proposal: contract + registry + superseded markers
2. Remove `firefly` keyword from mint-agent routing (per proposal)
3. Loop scope with decisions
4. Recert + push

## P0 Receipts

- spine.verify: CAP-20260212-133642__spine.verify__Rvplo23900
- gaps.status: CAP-20260212-133712__gaps.status__R1fno33884
