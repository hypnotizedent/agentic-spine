---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ha-identity-mutation-contract-v1-plan
parent_loop: LOOP-HA-IDENTITY-MUTATION-CONTRACT-V1-20260217
---

# HA Identity + Mutation Path Contract V1 (Plan)

## Purpose

Define a single canonical mutation path for Home Assistant that is:

- agent-driven,
- YAML/SSOT-first,
- capability-only for execution,
- and explicitly forbids manual UI or ad-hoc mutation channels.

This is a design and registration artifact only. No runtime HA mutations are executed in this lane.

## Canonical Mutation Path

### Allowed mutation surfaces

- `ha.device.rename`
- `ha.service.call`
- `ha.automation.create`
- `ha.script.run`
- `ha.automation.trigger` (controlled execution)
- `ha.scene.activate` / `ha.light.toggle` / `ha.lock.control` only when routed through governed capability contracts and loop-scoped intent

### Forbidden mutation surfaces

- Direct Home Assistant UI/manual configuration changes as authoritative source.
- Raw WebSocket/manual endpoint mutation outside governed capabilities.
- Ad-hoc SSH mutation of HA runtime/state as a mutation pathway.
- Any unmanaged script path that bypasses capability policy, receipts, and loop/gap linkage.

## Identity Model

### Naming convention contract

- Device names follow deterministic room/function naming rules.
- Conflicts resolve via canonical alias rules tracked in SSOT bindings.
- Renames must preserve traceability to existing entity/device IDs.

### Area assignment rules

- Every mutable device must resolve to exactly one canonical area unless explicitly marked shared.
- Area fallbacks and exceptions are documented as policy entries, not ad-hoc operator decisions.
- Unassigned devices are treated as contract violations (triage-required).

### Entity/device identity reconciliation

- Registry identity (`home.device.registry.yaml`) is source-of-truth for intended identity.
- HA mapping bindings reconcile runtime identifiers to registry intent.
- Divergence generates a governed gap or policy exception note before further mutation.

## Required Post-Mutation Refresh Sequence

Run in order after approved mutation batches:

1. `./bin/ops cap run ha.device.map.build`
2. `./bin/ops cap run ha.refresh`
3. `./bin/ops cap run ha.ssot.baseline.build`

Expected effect: refreshed map, synchronized snapshots, and baseline parity update for subsequent verify lanes.

## Required SSOT Surfaces

- `ops/bindings/ha.areas.yaml`
- `ops/bindings/ha.orphan.classification.yaml`
- `ops/bindings/home.device.registry.yaml`
- `ops/bindings/ha.ssot.baseline.yaml`

## Acceptance Criteria

1. A documented allow/deny mutation path exists and is referenced by HA executor loops.
2. Identity rules cover naming, area assignment, and reconciliation conflicts.
3. Post-mutation refresh sequence is explicit and executable via capabilities.
4. SSOT update/check surfaces are enumerated and tied to mutation lifecycle.
5. Future enforcement hooks are defined for gate/capability checks.

## Enforcement Hooks (Future Gate Targets)

- Add a home-domain verification hook that fails on forbidden mutation channel usage evidence.
- Add a capability metadata/contract lint check for HA mutation surfaces (allowed list + required refresh linkage).
- Add SSOT parity checks for the four required surfaces as precondition/postcondition controls.

## Implementation Evidence (GAP-OP-655)

### Artifacts Created/Updated

| Artifact | Action | Purpose |
|----------|--------|---------|
| `ops/bindings/ha.identity.mutation.contract.yaml` | Created | Canonical mutation contract V1 |
| `ops/agents/home-assistant-agent.contract.md` | Updated | Added mutation contract reference + section |
| `ops/bindings/agents.registry.yaml` | Updated | Added `mutation_contract` field to home-assistant-agent |
| `ops/plugins/home/bin/ha-identity-mutation-contract-status` | Created | Read-only status checker capability |
| `ops/capabilities.yaml` | Updated | Registered `ha.identity.mutation.contract.status` |
| `ops/bindings/capability_map.yaml` | Updated | Mapped capability to plugin/script |

### Acceptance Criteria Met

1. Allow/deny mutation path documented in `ha.identity.mutation.contract.yaml`
2. Identity rules cover naming (`{area}_{function}_{qualifier}`), area assignment, and reconciliation
3. Post-mutation refresh sequence explicit: ha.device.map.build -> ha.refresh -> ha.ssot.baseline.build
4. SSOT surfaces enumerated: ha.areas.yaml, ha.orphan.classification.yaml, home.device.registry.yaml, ha.ssot.baseline.yaml
5. Status checker capability validates contract integrity at runtime
