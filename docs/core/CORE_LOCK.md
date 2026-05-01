---
status: reference_pointer
owner: "@human-steward"
last_verified: 2026-05-01
scope: core-lock-pointer
---

# CORE_LOCK

This file is not the source of live gate truth.

It used to enumerate D-gates directly. That became stale as the live registry
and verify topology were subtracted. Fresh agents must not treat this document
as a gate list, closure checklist, or authority surface.

## Current Authority

Use these live surfaces instead:

| Question | Authority |
|---|---|
| Is the engine alive? | `./bin/ops cap run verify.engine.run` |
| Is the spine/control-plane coherent? | `./bin/ops cap run spine.verify` |
| Which gates exist now? | `ops/bindings/gate.registry.yaml` |
| Which gates are in spine scope? | `ops/bindings/gate.execution.topology.yaml` |
| What is public status? | `./bin/ops status` |
| Where does runtime state live? | `ops/bindings/root.authority.contract.yaml` |

## Stable Core Shape

- Authored control-plane source lives in the repo.
- Runtime state lives under `/Users/ronnyworks/code/.runtime/spine/`.
- Evidence lives under `/Users/ronnyworks/code/.evidence/spine/`.
- Gitea `origin` is canonical repo truth.
- GitHub is publication/distribution only.

If this file disagrees with the live registry, topology, root authority, or
verify output, this file loses.
