---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION-20260210
---

# Loop Scope: LOOP-HOME-SERVICE-REGISTRY-SCOPE-DECISION-20260210

> **Status:** CLOSED

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Decide and enforce whether home services belong in SERVICE_REGISTRY.yaml, then bring parity with bindings and health checks.

## Decision

**Home services are OUT OF SCOPE for SERVICE_REGISTRY.yaml.**

Rationale:
- Home-site services (proxmox-home, pihole-home, download-home, hass) are secondary/personal
- Reachable only via Tailscale, not on shop LAN
- No health bindings, no docker compose targets, no SLA expectations
- Already tracked in `ssh.targets.yaml` for connectivity checks (with `optional: true`)

Scope policy added to SERVICE_REGISTRY.yaml header comment block, referencing this loop.

## Evidence (Receipts)
- docs/governance/SERVICE_REGISTRY.yaml (scope policy added)
- ops/bindings/ssh.targets.yaml (home hosts present with optional flag)
