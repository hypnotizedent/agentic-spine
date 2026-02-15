---
loop_id: LOOP-AOF-PLUGIN-CAPABILITY-SURFACE-20260215
created: 2026-02-15
status: active
owner: "@ronny"
scope: agentic-spine
objective: Expose AOF kernel-level capabilities through a dedicated plugin and contract bindings.
---

## Problem Statement

AOF product foundation documents and tenant-level capabilities exist, but the AOF kernel abstraction surface (`aof.bootstrap`, `aof.validate`, `aof.contract.status`) is missing from runtime. This leaves environment/identity contract setup as a manual gap.

## Deliverables

1. Add `ops/plugins/aof/bin/*` scripts for bootstrap, validation, and contract-read status.
2. Add AOF contract bindings (`environment.contract.schema`, `identity.contract.schema`, `drift-gates.scoped`).
3. Add AOF profile templates in `ops/profiles/`.
4. Register `aof.*` capabilities in `ops/capabilities.yaml`.
5. Register plugin + capability map wiring in `ops/plugins/MANIFEST.yaml` and `ops/bindings/capability_map.yaml`.
6. Add plugin tests under `ops/plugins/aof/tests/`.

## Acceptance Criteria

1. `aof.bootstrap`, `aof.validate`, and `aof.contract.status` are present in `ops/capabilities.yaml`.
2. `ops/plugins/aof` is present in `ops/plugins/MANIFEST.yaml` with scripts and capabilities.
3. `ops/plugins/aof/tests/*.sh` exists to satisfy plugin-test coverage requirements.
4. `ops/bindings/capability_map.yaml` includes `aof.*` capability keys.
5. Proposal payload is complete for every `create`/`modify` action.

## Constraints

1. Use proposal flow only; do not apply directly while multi-agent/dirty-tree conditions exist.
2. Preserve existing AOF v0.1 product docs and avoid creating competing product truth.
3. Keep scripts deterministic and safe for local/operator execution.
