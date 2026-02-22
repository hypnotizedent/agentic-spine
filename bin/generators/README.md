# Generators Interface (Draft)

## Purpose
Define deterministic generator/validator interfaces for `generated` and `index` artifacts declared in `ops/bindings/registry.ownership.yaml`.

## Contract
- Generators are one-way: SSOT -> derived artifact.
- Derived artifacts are never hand-edited.
- Validators fail if derived output diverges from generator result.

## Interfaces

### 1) Capability Map Generator
- Input:
  - `ops/capabilities.yaml`
- Output:
  - `ops/bindings/capability_map.yaml`
- Validate:
  - every capability key in SSOT exists in map
  - no duplicate keys
  - command/script parity for mapped entries
- Wire:
  - Gate extension: `D67` (`surfaces/verify/d67-capability-map-lock.sh`)
  - Optional pre-commit hook target: `gen.capability_map.verify`

### 2) Capability Domain Catalog Generator
- Input:
  - `ops/capabilities.yaml`
  - `ops/bindings/agents.registry.yaml`
- Output:
  - `ops/bindings/capability.domain.catalog.yaml`
- Validate:
  - domain prefixes resolve to capability keys
  - `last_synced` freshness window
- Wire:
  - Gate extension: domain catalog freshness/coverage checks
  - Optional pre-commit hook target: `gen.domain_catalog.verify`

### 3) VM Lifecycle Derived Generator
- Input:
  - `ops/bindings/vm.lifecycle.yaml`
  - `ops/bindings/vm.lifecycle.contract.yaml`
- Output:
  - `ops/bindings/vm.lifecycle.derived.yaml`
- Validate:
  - active VM set parity
  - required derived fields present
- Wire:
  - Existing tool path: `ops/plugins/vm/bin/vm-lifecycle-derived-check`

### 4) HA Snapshot Generators
- Input:
  - Home Assistant runtime read APIs (via governed snapshot scripts)
  - baseline bindings when applicable
- Output:
  - `ops/bindings/ha.automations.yaml`
  - `ops/bindings/ha.dashboards.yaml`
  - `ops/bindings/ha.device.map.yaml`
  - `ops/bindings/ha.entity.state.baseline.yaml`
  - `ops/bindings/ha.hacs.yaml`
  - `ops/bindings/ha.helpers.yaml`
  - `ops/bindings/ha.integrations.yaml`
  - `ops/bindings/ha.scenes.yaml`
  - `ops/bindings/ha.scripts.yaml`
  - `ops/bindings/ha.ssot.baseline.yaml`
  - `ops/bindings/z2m.devices.yaml`
  - `ops/bindings/zwave.devices.yaml`
- Validate:
  - output parses and required fields exist
  - freshness SLA
  - parity gates (`D92`, `D98`, `D99`, `D101`, `D102`, `D104`, `D117`, `D118`, `D119`, `D120`)
- Wire:
  - scheduled capabilities + verify pack checks

### 5) Home DHCP Audit Generator
- Input:
  - `ops/bindings/network.home.baseline.yaml`
  - network audit capability output
- Output:
  - `ops/bindings/home.dhcp.audit.yaml`
- Validate:
  - expected host keys exist
  - audit timestamp freshness
- Wire:
  - include in home/domain verify routing

### 6) Receipt Index Builder (Index Artifact)
- Input:
  - `receipts/sessions/**/receipt.md`
  - `mailroom/state/ledger.csv`
- Output:
  - `ops/plugins/evidence/state/receipt-index.yaml`
- Validate:
  - schema parity with `ops/bindings/receipts.index.schema.yaml`
  - freshness (`D142`)
- Wire:
  - existing `receipts.index.build` capability
  - `D142` freshness gate

### 7) Routing Dispatch Generator (Planned)
- Input:
  - `ops/capabilities.yaml`
  - `ops/bindings/agents.registry.yaml`
  - `ops/plugins/*/MANIFEST.yaml`
- Output:
  - `ops/bindings/routing.dispatch.yaml`
- Validate:
  - every capability has exactly one runtime dispatch target (`plugin` or `agent_route`)
  - safety/approval metadata parity with `ops/capabilities.yaml`
  - no orphan plugin routes and no dangling agent routes
- Wire:
  - new parity gate in verify core/domain routing lane
  - optional pre-commit target: `gen.routing_dispatch.verify`

## Phase 3 Schema Expansion (Concrete)
Prioritize schema definitions for top edited/critical authoritative bindings:
1. `ops/bindings/agents.registry.yaml`
2. `ops/bindings/gate.registry.yaml`
3. `ops/bindings/capability.domain.catalog.yaml` (post-generation schema)
4. `ops/bindings/proposals.lifecycle.yaml`
5. `ops/bindings/gate.execution.topology.yaml`
6. `ops/bindings/gate.domain.profiles.yaml`
7. `ops/bindings/gate.agent.profiles.yaml`
8. `ops/bindings/mailroom.runtime.contract.yaml`
9. `ops/bindings/secrets.namespace.policy.yaml`
10. `ops/bindings/terminal.role.contract.yaml`

## Gate/Hook Wiring Pattern
- Add `gen.<name>.verify` capability for each generator.
- Gate layer runs verify capabilities in read-only mode.
- Pre-commit runs only lightweight parity checks (no external network/runtime fetch).
- CI/release lane runs full regeneration + diff check.

## Migration Order
1. Lock ownership contract (`registry.ownership.yaml`).
2. Implement generator commands.
3. Add parity validators to gates.
4. Flip generated files to hard-fail on manual drift.
