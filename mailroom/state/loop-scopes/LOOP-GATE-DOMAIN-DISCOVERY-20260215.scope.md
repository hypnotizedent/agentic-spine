---
id: LOOP-GATE-DOMAIN-DISCOVERY-20260215
status: closed
opened: 2026-02-15
closed: 2026-02-15
owner: "@ronny"
gaps:
  - GAP-OP-432
  - GAP-OP-433
  - GAP-OP-434
  - GAP-OP-435
  - GAP-OP-436
---

# LOOP: Domain-Specific Gate Discoverability for Terminals

## Objective

Add a terminal-first gate discovery layer that makes domain-relevant drift gates explicit before mutation work starts.

## Problem Statement

Operators and agents can discover gate inventory, but there is no canonical domain map or session-start routing that tells each terminal which gate pack applies to its active work domain.

## Deliverables

1. Canonical domain mapping binding for gate packs.
2. `verify.drift_gates.certify` support for listing/filtering domain packs and brief output.
3. `ops preflight` gate-domain banner with optional `OPS_GATE_DOMAIN` inline brief rendering.
4. Governance documentation updates for domain-pack usage.
5. Regression tests for certifier domain modes and preflight banner behavior.

## Acceptance Criteria

1. `./bin/ops cap run verify.drift_gates.certify --list-domains` returns configured domains.
2. `./bin/ops cap run verify.drift_gates.certify --domain <name> --brief` returns only mapped gates.
3. `./bin/ops preflight` prints `Gate Domains` section each run.
4. `OPS_GATE_DOMAIN=<name> ./bin/ops preflight` prints selected domain brief summary.
5. `./bin/ops cap run spine.verify` remains green.

## Constraints

1. Discoverability only: no enforcement logic changes to existing gates.
2. Unknown `OPS_GATE_DOMAIN` must not hard-fail preflight.
3. Domain map remains explicit by gate ID (no category inference at runtime).
