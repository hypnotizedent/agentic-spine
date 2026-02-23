# Inventory Intake Envelopes

Purpose:
- Canonical intake envelope for new physical parts and business materials before they are recorded in SSOT inventory bindings.

Naming convention:
- `ITK-<YYYYMMDD>-<class>-<id>.yaml`
- Class must be `part` or `material`.

Lifecycle:
- `draft -> proposed -> approved -> recorded -> active -> depleted|retired|rma`

Required homes:
- `owner_agent`
- `site`
- `location_id`
- `evidence_refs`
- `runbook_path`

Conditional runtime homes (when `touches_runtime=true`):
- `infisical_namespace`
- `vaultwarden_item`
- `gitea_repo`
- `observability_probe`

Control linkage:
- Intake envelopes can be linked to extension transactions and proposals for end-to-end traceability.
- D183 validates schema and naming.
- D184 validates location parity.
- D185 validates required homes and runtime-home union requirements.
