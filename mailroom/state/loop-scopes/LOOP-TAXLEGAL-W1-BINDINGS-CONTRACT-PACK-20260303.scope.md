---
loop_id: LOOP-TAXLEGAL-W1-BINDINGS-CONTRACT-PACK-20260303
created: 2026-03-03
status: planned
owner: "@ronny"
scope: agentic-spine
objective: Define the Wave 1 Tax-Legal binding contract pack for case lifecycle, source registry, citation policy, privacy, retention, and deadlines.
---

# Loop Scope: TaxLegal W1 Bindings Contract Pack

## Problem Statement

Tax-Legal workflows require structured contracts to avoid ambiguous case state, source drift, and privacy leakage. The current bindings set has no tax/legal-specific lifecycle or citation/privacy contracts.

## Deliverables

1. Draft `ops/bindings/taxlegal.case.lifecycle.contract.yaml`.
2. Draft `ops/bindings/taxlegal.sources.registry.yaml` skeleton with required metadata keys.
3. Draft `ops/bindings/taxlegal.citation.contract.yaml` with unknown-state enforcement.
4. Draft `ops/bindings/taxlegal.privacy.contract.yaml` and `taxlegal.retention.contract.yaml`.
5. Draft `ops/bindings/taxlegal.deadline.contract.yaml` with escalation windows.
6. Child gaps filed and linked for each missing contract artifact.

## Acceptance Criteria

1. Each contract includes status/owner/updated scope metadata.
2. Case lifecycle states and transition requirements are explicitly defined.
3. Source registry schema includes hash/effective-date/citation anchors.
4. Privacy and retention contracts map to manual approval for purge/redaction mutators.
5. All missing contract artifacts are represented by child gaps before implementation.

## Constraints

1. Design-only; no new capabilities or plugin scripts.
2. No live source ingestion in this loop.
3. No secret values stored in contracts; path references only.

## Gaps

1. `GAP-OP-1426` — missing case lifecycle contract.
2. `GAP-OP-1427` — missing source registry contract.
3. `GAP-OP-1428` — missing citation strictness contract.
4. `GAP-OP-1429` — missing privacy contract.
5. `GAP-OP-1430` — missing retention contract.
6. `GAP-OP-1431` — missing deadline contract.
