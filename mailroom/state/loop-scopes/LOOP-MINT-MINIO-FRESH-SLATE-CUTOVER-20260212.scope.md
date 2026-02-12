---
loop_id: LOOP-MINT-MINIO-FRESH-SLATE-CUTOVER-20260212
status: open
opened: 2026-02-12
owner: "@ronny"
scope: minio-storage-canonical-cutover
---

# LOOP: MinIO Fresh-Slate Cutover

## Objective
Establish a single canonical MinIO runtime source (storage stack), remove all
conflicting authority statements across spine/workbench, and decouple mint-modules
runtime from the legacy mint-os application stack.

## Decision Lock
- mint-modules must have ZERO runtime dependency on legacy mint-os app stack.
- MinIO must be canonical from storage stack, not mint-os stack.

## Phases
- P0: Baseline receipts (ops status, verify, compose status, health)
- P1: Repo authority fixes (spine SSOT + workbench compose cleanup)
- P2: Fresh-slate runtime boundary (mint-modules decoupling)
- P3: Secrets alignment (namespace + canonical keys)
- P4: Live recertification
- P5: Closeout with receipt

## Done Definition
1. Single canonical MinIO runtime source (storage stack)
2. No conflicting MinIO authority statements across spine/workbench
3. mint-modules runtime path no longer tied to legacy mint-os app stack
4. D1-D71 pass
5. 0 open gaps or explicitly parented if any blocker appears

## Files Expected to Touch
- ops/bindings/docker.compose.targets.yaml
- docs/governance/SERVICE_REGISTRY.yaml
- workbench: infra/compose/storage/docker-compose.yml
- workbench: infra/compose/mint-os/docker-compose.yml
- mint-modules: deploy/docker-compose.prod.yml (comments/docs only)
- ops/bindings/secrets.namespace.policy.yaml (if needed)
