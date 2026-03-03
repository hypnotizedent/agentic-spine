# PLAN-TAXLEGAL-W1-ORDER-LOCK-20260303

> Design-only execution lock for Tax-Legal Wave 1.
> Purpose: preserve ordered implementation intent for a future worker.
> Status: deferred planning artifact (no execution in this plan).
> Date: 2026-03-03.

## Intent Lock

This artifact locks Wave 1 sequence and dependencies so a future worker can build the engine without losing scope.

Execution order is fixed:

1. Lifecycle playbooks first.
2. Agent and boundary contracts second.
3. Bindings contract pack third.
4. Domain routing integration fourth.

No runtime plugin/capability/gate implementation is performed in this plan.

## Ordered Work Packets

### Packet 1 — Lifecycle Playbooks

- Loop: `LOOP-TAXLEGAL-W1-BUSINESS-LIFECYCLE-PLAYBOOKS-20260303`
- Objective: codify formation/amend/operate/enforcement/closure playbooks and anonymity/privacy model with primary-source verification rules.
- Child gaps: `GAP-OP-1438`, `GAP-OP-1439`, `GAP-OP-1440`, `GAP-OP-1441`, `GAP-OP-1442`, `GAP-OP-1443`.
- Primary outputs (design artifacts):
  - `docs/governance/domains/tax-legal/BUSINESS_LIFECYCLE_PLAYBOOK.md`
  - `docs/governance/domains/tax-legal/ANONYMITY_PRIVACY_MODEL.md`
  - `docs/governance/domains/tax-legal/CASE_TEMPLATES.md`
  - `ops/bindings/taxlegal.lifecycle.events.contract.yaml`
  - `ops/bindings/taxlegal.enforcement.response.contract.yaml`
  - `ops/bindings/taxlegal.jurisdiction.profile.33441.yaml`
- DoD:
  - Lifecycle stages and evidence requirements are deterministic.
  - AI transcript claims are explicitly `hypothesis-only` until primary-source verification.
  - 33441 profile is encoded as Deerfield Beach + Broward default.

### Packet 2 — Agent and Boundary Contracts

- Loop: `LOOP-TAXLEGAL-W1-AGENT-BOUNDARY-CONTRACTS-20260303`
- Depends on: Packet 1 complete.
- Objective: define non-advisory Tax-Legal agent contract and human-review lock.
- Child gaps: `GAP-OP-1422`, `GAP-OP-1423`, `GAP-OP-1424`, `GAP-OP-1425`.
- Primary outputs:
  - `ops/agents/tax-legal-agent.contract.md`
  - `docs/governance/TAX_LEGAL_AGENT_BOUNDARY.md`
  - `docs/governance/domains/tax-legal/RUNBOOK.md`
- DoD:
  - Definitive legal/tax advice forbidden in contract language.
  - External filing remains human-approved only.
  - Risk escalation and sign-off thresholds are explicit.

### Packet 3 — Bindings Contract Pack

- Loop: `LOOP-TAXLEGAL-W1-BINDINGS-CONTRACT-PACK-20260303`
- Depends on: Packet 2 complete.
- Objective: establish contract-level lifecycle, citation, privacy, retention, and deadline schemas.
- Child gaps: `GAP-OP-1426`, `GAP-OP-1427`, `GAP-OP-1428`, `GAP-OP-1429`, `GAP-OP-1430`, `GAP-OP-1431`.
- Primary outputs:
  - `ops/bindings/taxlegal.case.lifecycle.contract.yaml`
  - `ops/bindings/taxlegal.sources.registry.yaml`
  - `ops/bindings/taxlegal.citation.contract.yaml`
  - `ops/bindings/taxlegal.privacy.contract.yaml`
  - `ops/bindings/taxlegal.retention.contract.yaml`
  - `ops/bindings/taxlegal.deadline.contract.yaml`
- DoD:
  - Source metadata and citation anchors are mandatory.
  - Unknown/conflict states are first-class contract outcomes.
  - Retention and purge mutators are manual-gated.

### Packet 4 — Domain Routing Integration

- Loop: `LOOP-TAXLEGAL-W1-DOMAIN-ROUTING-INTEGRATION-20260303`
- Depends on: Packet 3 complete.
- Objective: wire planned discoverability across registry, terminal roles, taxonomy bridge, and domain route docs.
- Child gaps: `GAP-OP-1432`, `GAP-OP-1433`, `GAP-OP-1434`, `GAP-OP-1435`, `GAP-OP-1436`.
- Primary outputs:
  - Planned tax-legal entries in `ops/bindings/agents.registry.yaml`
  - Planned tax-legal role in `ops/bindings/terminal.role.contract.yaml`
  - Planned tax-legal mapping in `ops/bindings/domain.taxonomy.bridge.contract.yaml`
  - Tax-legal routes in `ops/bindings/domain.docs.routes.yaml`
  - Domain docs stubs under `docs/governance/domains/tax-legal/`
- DoD:
  - Tax-legal is discoverable as `planned` without runtime activation.
  - No role/capability mismatch with runtime role policy.

## Worker Build Rules (Dream Knowledge Consultant)

1. Treat conversational legal/tax narratives as intake context only.
2. Promote claims to guidance only after primary-source verification and citation anchoring.
3. Keep public-record privacy goals separate from legal/federal reporting obligations.
4. Use case-first operations; no freeform advisory outputs without case ID and evidence refs.
5. Keep all Wave 1 outputs design-only until explicit implementation promotion.

## Execution Freeze Statement

This plan intentionally does not start implementation. It preserves sequence, dependencies, and acceptance criteria for a future worker execution wave.

## Activation Outline (Future Worker)

1. Promote Packet 1 loop to `active` and resolve `GAP-OP-1438..1443`.
2. Promote Packet 2 loop only after Packet 1 closeout receipt.
3. Promote Packet 3 loop only after Packet 2 closeout receipt.
4. Promote Packet 4 loop only after Packet 3 closeout receipt.
5. Run `./bin/ops cap run verify.run -- fast` after each packet closeout.
