---
loop_id: LOOP-TAXLEGAL-W1-AGENT-BOUNDARY-CONTRACTS-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Produce Wave 1 Tax-Legal agent and boundary contract artifacts that lock non-advisory behavior and human review requirements.
---

# Loop Scope: TaxLegal W1 Agent and Boundary Contracts

## Problem Statement

Wave 1 requires a formal Tax-Legal domain contract baseline, but no dedicated `tax-legal-agent` contract or boundary lock exists in governance. Without these artifacts, future implementation can drift into legal/tax-advice behavior and unclear human sign-off rules.

## Deliverables

1. Draft `ops/agents/tax-legal-agent.contract.md` with ownership/deferral boundaries.
2. Draft `docs/governance/TAX_LEGAL_AGENT_BOUNDARY.md` with explicit allowed/forbidden actions.
3. Draft risk-review policy section (green/yellow/red classes + human sign-off triggers) linked from the boundary contract.
4. Cross-reference updates in Wave 1 plan artifact to new contract paths.
5. Child gaps filed and linked for all missing/unclear governance items in this scope.

## Acceptance Criteria

1. Tax-legal role is defined as compliance coordinator and citation-strict researcher, not decision authority.
2. Forbidden actions include definitive legal/tax advice and autonomous filing submission.
3. Human-review gating is explicit for high-risk and conflict states.
4. All missing artifacts are represented by open child gaps before implementation work starts.

## Constraints

1. Design-only work; no runtime plugin/capability/gate implementation.
2. No production-side API calls or filing automation.
3. No changes outside governance/contract surfaces required for this loop.

## Gaps

1. `GAP-OP-1422` — missing agent contract artifact.
2. `GAP-OP-1423` — missing boundary contract artifact.
3. `GAP-OP-1424` — unclear human-review escalation/sign-off thresholds.
4. `GAP-OP-1425` — missing domain runbook stub.
