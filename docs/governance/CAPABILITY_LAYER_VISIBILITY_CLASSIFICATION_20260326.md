---
status: draft
owner: "@ronny"
last_verified: 2026-03-26
scope: capability-layer-visibility-classification
source_registry: ops/capabilities.yaml
runtime_artifact: /Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/classification-20260326/classification.csv
---

# Capability Layer And Visibility Classification 2026-03-26

This document defines the destination lens for the current registry. It does not mutate the registry. It does not approve deletions. It defines where authority belongs and what agents should be allowed to discover.

## Decision

Every live capability is classified on two independent axes:

| Axis | Purpose | Allowed Values |
| --- | --- | --- |
| Authority model | Decide where truth and execution authority belong. | `Layer1_framework`, `Layer2_spine`, `Layer3_domain` |
| Visibility model | Decide what an agent should be allowed to discover by default. | `exposed_core`, `internal_plumbing`, `latent_break_glass`, `obsolete` |

The authority model answers "where does this belong."

The visibility model answers "should an agent see this at all."

## Authority Model

| Layer | Owns | Does Not Own |
| --- | --- | --- |
| `Layer1_framework` | Reusable session, receipt, verification, routing, orchestration, adapter, and projection mechanism. | Ronny-specific estate truth, provider inventory, domain behavior. |
| `Layer2_spine` | Ronny-specific infrastructure truth for identity and access, network stability, configuration management, golden images, and operator surfaces. | Reusable mechanism, business logic, home behavior, media logic, finance logic. |
| `Layer3_domain` | Domain and provider behavior behind dedicated runtimes. | Shared infrastructure authority and shared framework machinery. |

## Visibility Model

| State | Meaning |
| --- | --- |
| `exposed_core` | Intentionally discoverable surface for the runtime that owns it. |
| `internal_plumbing` | Real capability, not agent-facing by default. Preconditions, probes, sync loops, projections, lifecycle internals. |
| `latent_break_glass` | Real capability kept for recovery, migration, restore, or controlled maintenance. Rare by design. |
| `obsolete` | Capability should not survive the lean target state. |

`exposed_core` is runtime-local. It is not a promise that every agent sees every exposed capability.

## Planning Disposition

| Disposition | Meaning |
| --- | --- |
| `keep` | Survives in the owning layer. |
| `collapse` | Behavior survives only after being hidden behind a smaller authority surface. |
| `extract` | Leaves the spine and moves behind a domain or provider runtime boundary. |
| `retire` | Temporary or ceremony-heavy surface that should not remain in the lean target state. |

## Decision Rules

1. If a capability can be cloned with zero knowledge of Ronny's estate, classify it as `Layer1_framework`.
2. If a capability owns declared truth, routing, reachability, credentials, host state, backup state, or operator surface state for Ronny's estate, classify it as `Layer2_spine`.
3. If a capability expresses application, business, provider, or house behavior, classify it as `Layer3_domain`.
4. Recent usage is a prioritization signal. Recent usage is not a retention rule.

## Mixed Family Splits

| Family | Rule |
| --- | --- |
| `secrets.*` | Generic auth and execution adapters are `Layer1_framework`. Binding, inventory, namespace, RBAC, bundle routing, and runway authority are `Layer2_spine`. Phase migration surfaces are `retire` candidates. |
| `ha.*` vs `home.*` | Device identity and network-facing inventory surfaces such as `ha.z2m.*`, `ha.zwave.devices.snapshot`, and `ha.device.map.build` stay in `Layer2_spine`. House behavior and HA application actions move to `Layer3_domain`. All `home.*` surfaces remain `Layer2_spine`. |
| `cloudflare.*` | DNS, tunnel, registrar, zone, and publish authority stay in `Layer2_spine`. Workers, R2, and Pages move to `Layer3_domain`. |
| `n8n.*` | `n8n.infra.*` stays in `Layer2_spine`. `n8n.workflows.*` moves to `Layer3_domain`. |
| `operator.*` | Operator workstation and storage surfaces are Ronny-specific estate configuration, so they stay in `Layer2_spine`. |
| `mailroom.*` | `mailroom.task.*` is framework routing machinery. `mailroom.bridge.*` is deployed estate infrastructure and stays in `Layer2_spine`. |
| `verify.*` | Verification engine surfaces stay in `Layer1_framework`. Domain-specific parity helpers such as `verify.vertical_integration.parity_status` move to `Layer3_domain` or collapse behind the owning runtime. |

## 2026-03-26 Snapshot

| Measure | Count |
| --- | ---: |
| Live capabilities classified | 807 |
| `Layer1_framework` | 316 |
| `Layer2_spine` | 227 |
| `Layer3_domain` | 264 |
| `exposed_core` | 131 |
| `internal_plumbing` | 514 |
| `latent_break_glass` | 82 |
| `obsolete` | 80 |
| `keep` | 204 |
| `collapse` | 259 |
| `extract` | 264 |
| `retire` | 80 |

These counts are a planning snapshot from the live registry on 2026-03-26. They are not a mutation plan by themselves.

## Artifacts

- Runtime summary: [/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/classification-20260326/summary.md](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/classification-20260326/summary.md)
- Full classification: [/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/classification-20260326/classification.csv](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/classification-20260326/classification.csv)

Use this document to define the destination, persist the classification, and sequence later deprecation work. Do not use it as permission to delete by usage count alone.
