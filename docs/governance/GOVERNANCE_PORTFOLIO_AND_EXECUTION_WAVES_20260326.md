---
status: draft
owner: "@ronny"
last_verified: 2026-03-26
scope: governance-portfolio-and-execution-waves
source_snapshot: /Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/governance-portfolio-20260326/governance-doc-map.csv
transition_note: temporary planning artifact; not part of the steady-state top-level governance set
---

# Governance Portfolio And Execution Waves 2026-03-26

This document defines how the current top-level governance portfolio compresses into a smaller steady-state authority set. It is a planning artifact. It does not move files. It does not archive files. It does not approve extraction or capability deletion by itself.

## Decision

Governance compression comes before gate cleanup and before capability collapse.

The reason is structural:

1. Top-level governance defines the authority vocabulary the bindings are supposed to obey.
2. Live bindings are the largest active control-plane sprawl.
3. Gates are mostly retired registry ballast and should be cleaned only after the surviving governance and binding surfaces are clear.
4. Capability collapse should execute against stable authority docs and stable binding ownership, not against shifting governance language.

## Snapshot Basis

The counts below refer to the managed top-level governance portfolio snapshot taken on 2026-03-26 before this temporary planning document was added.

- The managed governance snapshot contains `47` top-level artifacts under `docs/governance/`.
- No files were moved, archived, or deleted.
- The row-level map lives at [governance-doc-map.csv](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/governance-portfolio-20260326/governance-doc-map.csv).
- The runtime summary lives at [summary.md](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/governance-portfolio-20260326/summary.md).

## Verified Current State

| Measure | Verified Count | Notes |
| --- | ---: | --- |
| Managed top-level governance artifacts | 47 | Snapshot under active review. |
| Bindings total | 847 | Includes archived bindings. |
| Bindings live | 422 | Excludes any file under `ops/bindings/**/archive/`. |
| Bindings archived | 425 | Historical ballast, not the live fold target. |
| Gate registry rows | 414 | From `ops/bindings/gate.registry.yaml`. |
| Gate registry header | `114` active / `300` retired | Use the file header as the planning count. |
| Gate row mismatch | 5 rows missing explicit `retired` flag | Normalize later; do not let this block governance compression. |
| Capability registry | 807 | Current live registry size. |

The gate registry confirms the prioritization. Gates are not the main live bureaucracy. Live bindings are.

## Portfolio Disposition Model

Every top-level governance artifact gets one of five dispositions.

| Disposition | Count | Meaning |
| --- | ---: | --- |
| `retain_top_level_governance` | 16 | Survives as a steady-state top-level authority artifact. |
| `archive_or_tombstone` | 8 | Historical, superseded, receipt-like, or backlog material that should leave the active governance surface. |
| `fold_into_surviving_governance` | 6 | Duplicative top-level surfaces that should be absorbed into stronger authority docs. |
| `rehome_to_spine_product_docs` | 9 | Real spine-owned material that should survive under a product-family home, not at top level. |
| `move_to_downstream_runtime` | 8 | Domain or provider material that belongs with downstream runtime authority. |

## Steady-State Top-Level Governance Set

The top-level governance surface should converge on these `16` artifacts:

- `CAPABILITY_LAYER_VISIBILITY_CLASSIFICATION_20260326.md`
- `DEVICE_IDENTITY_SSOT.md`
- `DOCKER_CONTROL_PLANE_DECISION.md`
- `GOVERNED_TASK_ENVELOPE_SPEC.md`
- `HOME_SERVER_SSOT.md`
- `LOCAL_CONTROL_PLANE_CONTRACT.md`
- `MACBOOK_SSOT.md`
- `MINILAB_SSOT.md`
- `PROXMOX_VM_SAFETY_DOCTRINE_V1.md`
- `SERVICE_REGISTRY.yaml`
- `SESSION_PROTOCOL.md`
- `SHOP_SERVER_SSOT.md`
- `SPINE.md`
- `SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md`
- `STACK_REGISTRY.yaml`
- `TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`

This list is the steady-state target. This temporary execution-wave document is not part of that steady-state set.

## Portfolio Map By Disposition

### Archive Or Tombstone

- `AGENT_EXECUTION_LANE_AUDIT_RECEIPT_20260319.md`
- `CONTROL_NODE_REQUIREMENTS.md`
- `DREAM_SYSTEM.md`
- `DREAM_SYSTEM_EXECUTION_BOARD.yaml`
- `SPINE_V3_BOOTSTRAP.md`
- `SPINE_V3_CONTINUOUS_SOURCEBOOK.md`
- `STORAGE_ARCHIVE_NODE_SPEC.md`
- `V3_AUTONOMY_DECISIONS.md`

### Fold Into Surviving Governance

- `AGENT_GOVERNANCE_BRIEF.md` into `SPINE.md` and `SESSION_PROTOCOL.md`
- `CLAUDE_ENTRYPOINT_SHIM.md` into `LOCAL_CONTROL_PLANE_CONTRACT.md` and `SESSION_PROTOCOL.md`
- `DOCKER_RUNTIME_BORINGNESS_CONTRACT.md` into `DOCKER_CONTROL_PLANE_DECISION.md` and `SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md`
- `EXECUTION_NODE_SPEC.md` to `ops/archive/pre-2026-04-01-spine/docs/governance/`; live node authority now lives in `ops/bindings/node.role.contract.yaml` and `LOCAL_CONTROL_PLANE_CONTRACT.md`
- `MACHINE_FILESYSTEM_CONTRACT.md` into `LOCAL_CONTROL_PLANE_CONTRACT.md`
- `MODEL_ADAPTER_LAYER_SPEC.md` into `TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`

### Rehome To Spine Product Docs

- `INFISICAL_BACKUP_RESTORE.md`
- `INFISICAL_RESTORE_DRILL.md`
- `MAILROOM_BRIDGE.md`
- `PROXMOX_VM_OPERATOR_CHECKLIST.md`
- `SURVEILLANCE_ROLES.md`
- `SYNOLOGY_918_STORAGE_MANIFEST_V1.md`
- `VAULTWARDEN_BACKUP_RESTORE.md`
- `VAULTWARDEN_CANONICAL_HYGIENE.md`
- `VAULTWARDEN_INFISICAL_CONTRACT.md`

These survive as spine-owned material under product-family homes such as `IdentityAndAccess`, `ComputeAndRuntimePlacement`, `StorageAndBackupPosture`, and `ControlPlaneViewsAndPlans`.

### Move To Downstream Runtime

- `CUSTOMER_PORTAL_CANONICAL_PLAN_V1.md` to Mint runtime docs
- `FINANCE_STACK_BACKUP_RESTORE.md` to Finance runtime docs
- `FINANCE_STACK_DOCTRINE_V1.md` to Finance runtime docs
- `FINANCE_STACK_OPERATOR_CHECKLIST.md` to Finance runtime docs
- `GITEA_BACKUP_RESTORE.md` to PlatformProvider runtime docs
- `MEDIA_STORAGE_CONTRACT.md` to ContentArchive runtime docs
- `MEDIA_STORAGE_LIFECYCLE.md` to ContentArchive runtime docs
- `STALWART_BACKUP_RESTORE.md` to Communications runtime docs

## Execution Waves

| Wave | Scope | Primary Output | Exit Condition |
| --- | --- | --- | --- |
| `baseline` | Freeze the surviving authority set and the destination docs. | Stable top-level governance target and row-level portfolio map. | The 16-artifact top-level target is accepted as the reference authority set. |
| `wave1_archive` | Remove historical and superseded artifacts from the active top-level surface. | Tombstone or archive plan for 8 artifacts. | Historical material is de-indexed from active governance without losing reference access. |
| `wave2_fold` | Absorb duplicate governance into stronger surviving docs. | Merge map and authority deltas for 6 artifacts. | No duplicate top-level contract survives where a stronger authority doc already exists. |
| `wave2_spine_rehome` | Move spine-owned operational material under product-family homes. | Spine product doc structure and rehome map for 9 artifacts. | Spine-owned runbooks stop competing with top-level governance. |
| `wave3_runtime_rehome` | Move downstream material under named runtime destinations. | Runtime-doc landing zones and rehome map for 8 artifacts. | Domain and provider docs live with the runtimes that own their behavior. |

## Dependency Order

The waves execute in this order:

1. `baseline`
2. `wave1_archive`
3. `wave2_fold`
4. `wave2_spine_rehome`
5. `wave3_runtime_rehome`
6. Binding fold and ownership normalization
7. Gate registry cleanup
8. Capability collapse and retirement execution

This ordering is intentional. Do not clean gates first. Do not collapse capabilities first.

## Coordination With Binding Work

Claude is tracing the live binding fold map. That work is upstream of execution.

This governance plan should only advance from planning to implementation once the live binding fold map answers, for every live binding:

- which surviving authority doc owns it
- which spine product family or downstream runtime owns it
- whether it is `keep`, `fold`, or `archive`

Bindings are the live control-plane sprawl. Governance compression without binding alignment just moves ambiguity around.

## Runtime Rehome Dependencies

`wave3_runtime_rehome` depends on the downstream runtime taxonomy already defined in [SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md](/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md).

The taxonomy calls that previously blocked landing-zone work are now locked:

- `Calendar` stays a standalone runtime.
- `PlatformProvider` owns forge, publication, and curated `share.publish.*` adapter behavior.
- `maker.*` moves to `Mint`.
- `OperatorOutput` does not survive as a destination runtime.

Binding and doc rehome work should target those destinations directly.

## Gate And Capability Follow-On

Gate cleanup is a later hygiene wave.

- Use the `gate_count` header in `gate.registry.yaml` as the planning count.
- Normalize the 5 rows missing explicit `retired` flags before registry cleanup.
- Remove retired gate ballast only after governance and bindings are stable enough that nothing still depends on historical gate names.

Capability work is later still.

- Use [CAPABILITY_LAYER_VISIBILITY_CLASSIFICATION_20260326.md](/Users/ronnyworks/code/agentic-spine/docs/governance/CAPABILITY_LAYER_VISIBILITY_CLASSIFICATION_20260326.md) as the baseline.
- Collapse and retire only against settled governance and binding ownership.
- Do not use recent usage counts as a standalone deletion rule.

## Artifacts

- Runtime portfolio map: [governance-doc-map.csv](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/governance-portfolio-20260326/governance-doc-map.csv)
- Runtime portfolio summary: [summary.md](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/governance-portfolio-20260326/summary.md)
- Runtime portfolio README: [README.md](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/governance-portfolio-20260326/README.md)

Use this document to keep the next phase bounded: define, persist, and sequence. Do not use it as permission to start moving files until the binding fold map and the destination confirmations are in hand.
