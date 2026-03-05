---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-04
scope: surveillance-access-governance
---

# SURVEILLANCE ROLES

## Purpose

Define role-based access and action boundaries for surveillance data and controls.

## Role Matrix

1. `owner`
- Full access to Frigate UI, events, retained footage, and automation controls.
- Can approve mutating surveillance operations.

2. `operator`
- View-only access to assigned live views and event feeds.
- No retention, config, or deletion actions.

3. `display`
- Kiosk/live-view only.
- No control actions, no credentials, no historical footage export.

## HA Boundary

- Existing home HA instance is the sole HA automation authority.
- Surveillance automations must be namespaced and documented.
- Shop operations must not create a second unmanaged HA control plane.

## Secrets Boundary

- All secrets live in Infisical paths under `/spine/shop/*` and related service namespaces.
- No credentials in repo documents, loop scopes, or proposal receipts.

## Audit / Evidence Requirements

- Every mutating operation must produce a receipt.
- Capability run receipts are required for any status claims.
- SSOT changes require parity checks against runtime bindings.
