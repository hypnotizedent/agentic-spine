---
status: superseded
owner: "@ronny"
last_verified: 2026-03-03
scope: inventory-intake-readme-legacy
superseded_by:
  - ops/bindings/intake.lifecycle.contract.yaml
  - ops/bindings/intake.envelope.schema.yaml
canonical_pointer_index: ops/bindings/master.inventory.registry.yaml
---

# Inventory Intake Envelopes (Legacy Scope)

This file is retained as a tombstoned inventory-only legacy reference.
Universal intake/master/projection governance now lives in:

- `ops/bindings/intake.lifecycle.contract.yaml`
- `ops/bindings/intake.envelope.schema.yaml`
- `ops/bindings/master.inventory.registry.yaml`
- `ops/bindings/domain.projection.contract.yaml`
- `ops/bindings/state.storage.policy.yaml`

Legacy reference (inventory-only):

- Naming convention:
  - `ITK-<YYYYMMDD>-<class>-<id>.yaml`
  - Class must be `part` or `material`.
- Lifecycle:
  - `draft -> proposed -> approved -> recorded -> active -> depleted|retired|rma`
- Required homes:
  - `owner_agent`
  - `site`
  - `location_id`
  - `evidence_refs`
  - `runbook_path`
- Conditional runtime homes (when `touches_runtime=true`):
  - `infisical_namespace`
  - `vaultwarden_item`
  - `gitea_repo`
  - `observability_probe`
- Legacy control linkage:
  - D183 validates schema and naming.
  - D184 validates location parity.
  - D185 validates required homes and runtime-home union requirements.
