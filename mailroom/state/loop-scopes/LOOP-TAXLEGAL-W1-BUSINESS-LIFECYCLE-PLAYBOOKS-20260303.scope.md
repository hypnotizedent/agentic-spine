---
loop_id: LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Define Wave 1 business lifecycle and anonymity/privacy playbooks for tax-legal operations (formation through closure) with primary-source verification policy.
---

# Loop Scope: TaxLegal W1 Business Lifecycle Playbooks

## Problem Statement

The current tax-legal plan defines general contracts but does not yet capture explicit lifecycle playbooks (start, amend, operate, enforce, close) or a first-class policy for ingesting external AI legal/tax narratives as non-authoritative hypotheses.

## Deliverables

1. Draft lifecycle playbook doc under `docs/governance/domains/tax-legal/` covering:
   - formation
   - amendment/address correction
   - local compliance (home occupation + BTR)
   - enforcement remediation (zoning/code enforcement)
   - dissolution/closure
2. Draft anonymity/privacy model doc distinguishing public-record privacy from legal reporting obligations.
3. Draft case templates doc for repeatable packet generation by lifecycle stage.
4. Draft lifecycle events binding contract and enforcement response binding contract.
5. Draft 33441 jurisdiction profile binding for Deerfield Beach/Broward baseline.
6. Child gaps filed and linked for all missing artifacts.

## Acceptance Criteria

1. Lifecycle stages and required evidence are explicit and deterministic.
2. External AI transcript ingestion is policy-bound to primary-source verification.
3. Anonymity guidance is framed as public-surface minimization, not concealment from legal/federal reporting.
4. Every missing Wave 1 lifecycle artifact is represented by child gaps.

## Constraints

1. Design-only; no runtime capability, plugin, or drift-gate implementation.
2. No legal/tax advice generation beyond governance boundary statements.
3. No municipality-specific assertions without primary-source verification paths in the source registry.

## Gaps

1. `GAP-OP-1438` — missing business lifecycle playbook artifact.
2. `GAP-OP-1439` — missing anonymity/privacy model artifact.
3. `GAP-OP-1440` — missing lifecycle case templates artifact.
4. `GAP-OP-1441` — missing lifecycle events contract artifact.
5. `GAP-OP-1442` — missing enforcement response contract artifact.
6. `GAP-OP-1443` — missing 33441 jurisdiction profile binding artifact.
