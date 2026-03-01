# W43 Inventory Intake Union Lock (2026-02-23)

## Objective
Standardize physical and business inventory onboarding with one governed path:
- intake envelope
- SSOT row
- enforcement gates

## Canonical Files
- `ops/bindings/hardware.parts.inventory.yaml`
- `ops/bindings/business.inventory.catalog.yaml`
- `ops/bindings/inventory.locations.yaml`
- `mailroom/outbox/intake/ITK-<YYYYMMDD>-<class>-<id>.yaml`

## One-Command Intake Flow
1. Scaffold (dry-run):
```bash
./bin/ops cap run platform.inventory.intake -- scaffold --class part --id sas-cable-0gyk61 --owner-agent mint-agent --site shop --location-id shop-rack-bin-a1 --runbook-path docs/governance/generated/W43_INVENTORY_INTAKE_UNION_LOCK_20260223.md --dry-run
```
2. Validate envelope:
```bash
./bin/ops cap run platform.inventory.intake -- validate --file mailroom/outbox/intake/ITK-<YYYYMMDD>-part-<id>.yaml
```
3. Record row in SSOT inventory binding (`hardware.parts.inventory.yaml` or `business.inventory.catalog.yaml`).

## SSOT Row Insertion Rules
- Required homes per row:
  - `owner_agent`
  - `site`
  - `location_id`
  - `evidence_refs`
  - `runbook_path`
- Conditional runtime homes required when `touches_runtime=true`:
  - `infisical_namespace`
  - `vaultwarden_item`
  - `gitea_repo`
  - `observability_probe`
- Lifecycle enum:
  - `draft|proposed|approved|recorded|active|depleted|retired|rma`

## Gate Semantics
- `D183` inventory intake schema lock:
  - validates intake envelope naming + required keys + lifecycle enum.
- `D184` inventory location parity lock:
  - validates `location_id` exists in `inventory.locations.yaml` and site parity matches.
- `D185` inventory home union lock:
  - validates required homes, owner-agent parity, runbook existence, and conditional runtime homes.

## Remediation Guide
- D183 fail:
  - fix envelope filename and required schema keys.
- D184 fail:
  - correct `location_id` or add location SSOT row with matching `site`.
- D185 fail:
  - fill missing homes, ensure owner agent exists in `agents.registry.yaml`, and populate runtime homes when `touches_runtime=true`.
