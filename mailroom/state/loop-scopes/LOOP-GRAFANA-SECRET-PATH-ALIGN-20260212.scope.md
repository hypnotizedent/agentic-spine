---
id: LOOP-GRAFANA-SECRET-PATH-ALIGN-20260212
status: closed
created: 2026-02-12
closed: 2026-02-12
owner: "@ronny"
gap: GAP-OP-059
---

# LOOP: Grafana Secret Path Alignment

## Objective

Make Grafana admin secret path explicit and governed. Move GAP-OP-059
(accepted) to fixed by creating the Infisical folder + secret at the
canonical path and updating all namespace bindings.

## Before State

- GAP-OP-059 status: **accepted** (low severity, standalone)
- Grafana compose uses `${GRAFANA_ADMIN_PASSWORD:-changeme}` fallback
- No Infisical folder at `/spine/vm-infra/grafana/`
- `GRAFANA_` prefix forbidden at root (namespace policy enforced)
- `GRAFANA_ADMIN_PASSWORD` absent from both `required_key_paths` and `key_path_overrides`

## Changes Applied

| File | Change |
|------|--------|
| Infisical (live) | Created folder `/spine/vm-infra/grafana` (id: 5f879bc7) |
| Infisical (live) | Created secret `GRAFANA_ADMIN_PASSWORD` at `/spine/vm-infra/grafana` |
| ops/bindings/secrets.namespace.policy.yaml | Added `GRAFANA_ADMIN_PASSWORD` to `required_key_paths` |
| ops/bindings/secrets.namespace.policy.yaml | Added `GRAFANA_ADMIN_PASSWORD` to `key_path_overrides` |
| ops/bindings/operational.gaps.yaml | GAP-OP-059: accepted → fixed |

## After State

- Secret exists at canonical path: `/spine/vm-infra/grafana/GRAFANA_ADMIN_PASSWORD`
- infisical-agent.sh resolves path correctly via `key_path_overrides`
- `secrets.namespace.status` enforces presence via `required_key_paths`
- GAP-OP-059 status: **fixed**

## Verification

- `secrets.projects.status`: PASS
- `secrets.namespace.status`: PASS
- `spine.verify`: PASS
