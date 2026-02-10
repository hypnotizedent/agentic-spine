---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-MINTOS-REGISTRY-VS-HEALTH-PARITY-20260210
---

# Loop Scope: LOOP-MINTOS-REGISTRY-VS-HEALTH-PARITY-20260210

> **Status:** CLOSED

## Source
- Certification report: mailroom/outbox/audit-export/2026-02-10-full-certification.md

## Goal
Resolve discrepancy between SERVICE_REGISTRY.yaml and services.health expectations for mint-os-api and minio on docker-host.

## Resolution

**Status:** mint-os-api, mint-os-postgres, and minio are all DEPRECATED.

- `services.health.yaml` already had `enabled: false` with deprecation notes
- `SERVICE_REGISTRY.yaml` was missing the deprecation markers — added `status: deprecated` and notes to all three entries
- Parity achieved: both registry and health binding agree these are deprecated

Full decommission of docker-host legacy stacks is a separate future task.

## Evidence (Receipts)
- docs/governance/SERVICE_REGISTRY.yaml (status: deprecated added)
- ops/bindings/services.health.yaml (enabled: false, already correct)
