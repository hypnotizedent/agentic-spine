---
loop_id: LOOP-TAX-LEGAL-OPS-WORKER-SPEC-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: agentic-spine
objective: Capture a governed, executable specification for a citation-strict Tax and Legal Ops worker that accelerates compliance execution without giving legal or tax advice.
---

# Loop Scope: Tax and Legal Ops Worker Spec

## Problem Statement

The spine has strong finance, communications, and governance surfaces, but there is no dedicated contract bundle for tax/legal operations that can:

1. Ingest and version primary legal/tax sources (IRS/state/local).
2. Answer with citation-linked outputs only.
3. Track compliance deadlines and filing packets as case operations.
4. Enforce legal/tax advice boundaries and privacy controls by default.

Without this, tax/legal work remains ad-hoc chat effort, high-friction manual coordination, and weak traceability between evidence, drafts, and professional review.

## Deliverables

1. End-to-end execution plan artifact under `mailroom/state/plans/` covering architecture, contracts, governance, mailroom lifecycle, connectors, and phased rollout.
2. Contract pack specification including:
   - Agent boundary contract (allowed vs forbidden behavior)
   - Legal source registry contract (version/hash/effective-date metadata)
   - Case lifecycle contract (intake, research, draft, review, closeout)
   - Citation strictness and unknown-state policy
   - PII, retention, and secrets handling policy
3. Governance pack specification including:
   - Planned capability surface
   - Planned drift gates
   - Verify route and evidence expectations
   - Cross-domain ownership boundaries (finance/comms/microsoft/n8n/observability)
4. Connector matrix and data contracts for finance stack and related high-value agent surfaces.
5. Activation runbook with go/no-go checks, risk classes, and human review checkpoints.

## Acceptance Criteria

1. The plan is executable as written: each phase has entry conditions, commands/surfaces, outputs, and promotion gates.
2. Legal/tax safety boundary is explicit: no definitive legal/tax positions; mandatory citation or explicit unknown.
3. Finance-stack integration is concrete and mapped to current canonical surfaces (`finance-agent`, `finance.stack.status`, action queue, Paperless/Firefly/Ghostfolio context).
4. Mailroom operating model is explicit: case artifact paths, lifecycle states, and receipt/evidence expectations.
5. Governance deltas are listed with target files and status labels (`proposed`, `planned`, `active` transition path).

## Constraints

1. No runtime implementation in this loop (no new plugin binaries, capabilities, drift scripts, or production schedulers).
2. No legal or tax advice generation policy changes beyond proposed boundary contracts.
3. No destructive data operations; design only.
4. Spec must align with existing spine governance: capability-first execution, receipts, loop/plan lifecycle, and role/runtime controls.

## Phases

1. P0 Discovery and topology alignment (completed in-session).
2. P1 Spec capture in loop + plan artifacts (this loop).
3. P2 Deferred promotion to implementation loop(s) after operator approval.

## Evidence Paths

1. `mailroom/state/loop-scopes/LOOP-TAX-LEGAL-OPS-WORKER-SPEC-20260303.scope.md`
2. `mailroom/state/plans/PLAN-TAX-LEGAL-OPS-WORKER-20260303.md`
3. `mailroom/state/plans/index.yaml` (plan registration entry)
