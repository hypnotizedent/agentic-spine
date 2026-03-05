# Endpoint Fleet SSOT

Status: authoritative  
Owner: @ronny  
Scope: endpoint fleet governance and execution blueprint

## Objective

Define the canonical endpoint fleet model for Mint Prints so procurement, provisioning, runtime operations, and retirement are deterministic across locations.

## Hardware Tiers

### Tier 1 (T1) — Staff Workstations
- Class: Intel N100 mini PC
- Use: press floor terminals, production desk, front office workstation
- Requirements: wired ethernet preferred, browser hardening baseline, remote support enrollment

### Tier 2 (T2) — Kiosk/Display Nodes
- Class: Raspberry Pi 5
- Use: static dashboards, queue/status displays, shared floor signage
- Requirements: readonly/kiosk profile, auto-recover on reboot, watchdog enabled

### Tier 3 (T3) — Local Compute Nodes
- Class: Ryzen desktop-class endpoint
- Use: heavier local compute tasks, media/admin tooling, failover workstation role
- Requirements: expanded storage profile, stronger backup cadence, thermal/health telemetry

### Tier 4 (T4) — Mobile Executive Endpoint
- Class: iPad Pro
- Use: management dashboard and mobile operator command center
- Requirements: MDM policy baseline, restricted app surface, secure notification path

## Identity and Role Model

Every endpoint is governed by:
- Asset ID: `EP-<TIER>-<LOCATION>-<SEQ>`
- Owner role: operator, supervisor, admin, or executive
- Runtime role mapping: dashboard-only, workstation, compute, or mobile-control
- Enrollment state: proposed, provisioned, production, retired

## MintOS Terminal Architecture

- Identity is contract-first: each endpoint has canonical asset metadata and role binding.
- Dashboard routing is role-scoped (press, production, office, executive).
- Notification plane routes through governed channels and respects role-level severity.
- Reconciliation is periodic and fail-closed on missing identity or drifted assignment.

## Lifecycle

1. `PROCURE`
- Approve hardware against tier contract.
- Assign asset ID and location.

2. `PROVISION`
- Enroll identity, apply baseline image/profile, register monitoring.

3. `PRODUCTION`
- Enable role-based routing and operator surfaces.

4. `MAINTAIN`
- Run patch cadence, health checks, drift reconciliation, and replacement planning.

5. `RETIRE`
- Decommission identity, wipe endpoint, archive lifecycle receipts.

## Provisioning by Device Class

- T1: workstation profile + productivity/runtime integrations.
- T2: kiosk profile + immutable dashboard target + reboot self-heal.
- T3: compute profile + heavier observability and backup policies.
- T4: mobile-control profile + constrained command surface.

## Monitoring and Governance Constraints

- Endpoint health must report into canonical status surfaces.
- Network placement follows least privilege and site topology contracts.
- Governance checks must fail on identity drift, orphaned assets, and untracked lifecycle transitions.

## Multi-Location Replication Procedure

- Duplicate tier mix per location using the same SSOT contract.
- Allocate location-scoped asset IDs.
- Apply provisioning templates by tier.
- Validate runtime routing, monitoring, and notification parity before go-live.

## Planned Capability/Agent Boundaries

- Endpoint inventory and lifecycle state remain authoritative in spine bindings.
- Operational automation can execute provisioning and maintenance actions.
- Domain agents consume endpoint state but do not mutate identity authority directly.

## Integration Dependencies

- Runtime identity contract and endpoint registry
- Monitoring/observability surfaces
- Notification plane
- Role-based dashboard routing
- Site network topology contracts
