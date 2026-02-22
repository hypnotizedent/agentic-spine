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

### 7) Terminal Worker Catalog Generator
- Input:
  - `ops/bindings/agents.registry.yaml`
  - `ops/bindings/terminal.role.contract.yaml`
  - `ops/bindings/gate.domain.profiles.yaml`
  - `ops/bindings/gate.agent.profiles.yaml`
  - `ops/capabilities.yaml`
- Output:
  - `ops/bindings/terminal.worker.catalog.yaml`
- Command:
  - `./bin/generators/gen-worker-catalog.sh`
- Validate:
  - every terminal role is represented exactly once
  - domain-runtime workers resolve scoped capabilities and gate packs
  - non-domain terminals pin verify target to `core`

### 8) Routing Dispatch Generator
- Input:
  - `ops/capabilities.yaml`
  - `ops/bindings/agents.registry.yaml`
  - `ops/bindings/terminal.worker.catalog.yaml`
- Output:
  - `ops/bindings/routing.dispatch.yaml`
- Command:
  - `./bin/generators/gen-routing-dispatch.sh`
- Validate:
  - every capability has exactly one runtime dispatch target (`plugin`, `agent`, or `builtin`)
  - safety/approval metadata parity with `ops/capabilities.yaml`
  - deterministic terminal affinity derived from worker catalog

### 9) Terminal Launcher View Generator
- Input:
  - `ops/bindings/terminal.worker.catalog.yaml`
  - `ops/bindings/terminal.role.contract.yaml`
- Output:
  - `ops/bindings/terminal.launcher.view.yaml`
- Command:
  - `./bin/generators/gen-launcher-view.sh`
- Validate:
  - picker ordering is deterministic
  - capability/gate counts match worker catalog
  - usage-doc references exist for each terminal entry

### 10) Worker Usage Docs Generator
- Input:
  - `ops/bindings/terminal.worker.catalog.yaml`
- Output:
  - `docs/governance/generated/worker-usage/*.md`
- Command:
  - `./bin/generators/gen-worker-usage-docs.sh`
- Validate:
  - one usage surface doc per terminal
  - stale generated docs are removed
  - generated docs retain deterministic metadata headers

### 11) Unified Runtime v2 Generator
- Command:
  - `./bin/generators/gen-terminal-worker-runtime-v2.py`
- Notes:
  - Generates all v2 runtime surfaces in one pass.
  - Supports `--check` for drift-only validation.

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
