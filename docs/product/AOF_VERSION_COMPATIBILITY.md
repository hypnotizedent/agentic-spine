---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: aof-version-compatibility
---

# AOF Version Compatibility

> Declares compatibility between AOF runtime components.

## Compatibility Matrix

The version compatibility matrix (`ops/bindings/version.compat.matrix.yaml`) tracks:
- Component versions (runtime, binding, library types)
- Source file locations
- Dependency graph between components

## Core Components

| Component | Type | Version | Source |
|-----------|------|---------|--------|
| drift-gate-runtime | runtime | 2.8 | `surfaces/verify/drift-gate.sh` |
| gate-registry | binding | 1 | `ops/bindings/gate.registry.yaml` |
| policy-presets | binding | 1 | `ops/bindings/policy.presets.yaml` |
| resolve-policy | library | 1 | `ops/lib/resolve-policy.sh` |
| cap-runner | runtime | 1 | `ops/commands/cap.sh` |
| capabilities-registry | binding | 1 | `ops/capabilities.yaml` |
| capability-map | binding | 1 | `ops/bindings/capability_map.yaml` |
| tenant-profile-schema | binding | 1 | `ops/bindings/tenant.profile.schema.yaml` |
| plugin-manifest | binding | 1 | `ops/plugins/MANIFEST.yaml` |

## Dependency Rules

- Every component must reference a valid source file
- Dependencies must reference declared components (no dangling references)
- No circular dependencies allowed
- Version bumps require matrix update

## Enforcement

- **Binding**: `ops/bindings/version.compat.matrix.yaml`
- **Gate**: D95 (version-compat-matrix-lock)
- **Capability**: `version.compat.verify` (read-only consistency check)
