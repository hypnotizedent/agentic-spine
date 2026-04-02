---
status: authoritative
owner: "@ronny"
created: 2026-03-26
last_verified: 2026-03-30
scope: normalization-kernel-governance
depends_on:
  - docs/governance/SPINE.md
  - docs/governance/PLATFORM_LAYER_MODEL.md
  - docs/governance/SPINE_V3_FINALIZATION_PROGRAM_20260330.md
---

# Spine Normalization Kernel

This document defines the normalization kernel: the set of laws that every spine operation must satisfy regardless of which plugin family, folder, or script implements it.

## Why Folder Names Are Not Architecture

A plugin family is a directory grouping. A directory grouping is an implementation detail. The spine's architecture is defined by its laws — what must be true after every governed mutation — not by which folder a script lives in.

When a folder name becomes a proxy for architectural intent, the result is:
- Folder proliferation without corresponding behavioral boundaries.
- Duplicate enforcement spread across families that share the same underlying law.
- Cleanup work that preserves historical folder shapes instead of converging toward laws.

The normalization kernel exists to break this coupling. Waves must converge toward laws, not preserve historical folder shapes.

## Why AOF Dies As A Plugin Family But Survives As Normalization Law

AOF (`ops/plugins/core/kernel/aof/`) was the original bootstrap and policy surface. It seeded the environment contract, identity contract, policy presets, tenant profiles, and contract acknowledgement ceremony.

The capabilities AOF provides are real and must survive:
- Environment and identity validation (`aof.validate`)
- Contract acknowledgement (`aof.contract.acknowledge`, `aof.contract.status`)
- Policy preset resolution (`aof.policy.show`)
- Health summary (`aof.status`)
- Version and schema reporting (`aof.version`)

But "AOF" as a named plugin family is a historical artifact. The word "autonomous operations framework" suggests a separate product. It is not. It is the normalization law surface of the spine itself. The behavior AOF enforces — authority resolution, boundary enforcement, policy application, environment validation — are normalization laws, not a plugin family's private concern.

AOF dies as a family name. Its enforcement intent survives as the normalization kernel's authority law and policy law.

## The Six Normalization Laws

Every governed mutation, every wave, every new surface must satisfy these laws. They are not aspirational. They are the current enforcement reality expressed as convergent requirements.

### 1. Authority Law

Every governed surface must have exactly one declared authority location. If a surface has no authority, it must not exist. If a surface has two authorities, one must be retired. Authority is declared in bindings, not inferred from folder placement.

**Current enforcement:** `aof.validate`, `aof.contract.status`, `aof.contract.acknowledge`, `docs.frontmatter.lint`, `docs.index.verify`.

### 2. Boundary Law

The spine owns substrate and attestation. Downstream runtimes own behavior. No spine surface may own domain behavior. No domain surface may own spine substrate truth. Boundary violations are surfaced by audit and corrected by reconcile plans.

**Current enforcement:** `surface.boundary.audit`, `surface.boundary.reconcile.plan`, `surface.readonly.audit`, `lean.budget.check`.

### 3. Promotion Law

Mutable state enters as a read-only snapshot. Promotion from snapshot to tracked binding requires an explicit governed write-path. No implicit promotion. No direct writes to tracked bindings outside the governed promotion surface.

**Current enforcement:** `snapshot.projection.apply`, `snapshot.surface.audit`, `docs.projection.sync`, `docs.projection.verify`.

### 4. Policy Law

Operational policy is resolved through a deterministic preset chain (env var → tenant profile → well-known file → default). Policy knobs are declared in a contract, wired to enforcement points, and auditable at runtime. Policy changes are advisory until human-applied.

**Current enforcement:** `resolve-policy.sh`, `policy.runtime.audit`, `policy.autotune.weekly`, `policy.autotune.propose`, `aof.policy.show`, `aof.policy.autotune`.

### 5. Incident Law

Gate failures trigger deterministic recovery actions with cooldown, attempt limits, and escalation. Recovery does not guess. Recovery matches gate IDs to declared actions. Unmatched failures escalate to alert channels. Evidence is collected daily against SLO contracts.

**Current enforcement:** `recovery.dispatch`, `recovery.docker.restart`, `recovery.launchd.restart`, `recovery.capability.retry`, `recovery.capability.commit`, `alerting.probe`, `alerting.dispatch`, `slo.evidence.daily`.

### 6. Continuity Law

Every governed mutation produces a receipt. Receipts survive model choice, session boundaries, and operator turnover. Version compatibility is verified. Evidence is exportable and auditable. Budget thresholds prevent unchecked surface growth.

**Current enforcement:** `version.compat.verify`, `budget.check`, `lean.budget.check`, `audit.export.governance_iac`, `aof.version`.

## Plugin Family Classification

### First-Class Operating Subsystems (Keep As-Is)

These families own distinct behavioral loops that cannot be reduced to normalization law enforcement without losing their operational identity.

| Family | Reason |
| --- | --- |
| `alerting` | Owns probe → dispatch → cooldown loop. Behavioral, not normalization. |
| `briefing` | Owns the scheduled daily spine briefing assembly loop and its modular section runners. This is an operator-facing workload, not a normalization helper. |
| `proposals` | Owns the governed change packet lifecycle (`submit` / `list` / `apply`) and remains the mailroom-gated write path for multi-surface mutations. |
| `recovery` | Owns failure → match → action → escalation loop. Behavioral, not normalization. |
| `work-index` | Owns unified work visibility aggregation. Operational surface, not normalization. |
| `ops/plugins/infra/observability/bin` | Owns live infrastructure probing across 15+ endpoints. Behavioral, not normalization. |

Subloop 4 keep-set lock as of `2026-04-02`:
`alerting`, `briefing`, `proposals`, and `work-index` are removed from the
active fold queue. They remain live first-string operating subsystems while the
bindings reduction continues.

### Folded Into The Normalization Kernel

These families enforce normalization laws but do not own independent behavioral loops. Their capabilities survive. Their family identity does not.

| Family | Target Law | Migration Note |
| --- | --- | --- |
| `aof` | Authority + Policy | Bootstrap, validation, contract ack, policy show, status, version. Capabilities survive under kernel identity. |
| `surface` | Boundary | Boundary audit, reconcile plan, readonly audit. |
| `snapshot` | Promotion | Snapshot promotion, surface audit. |
| `policy` | Policy | Runtime audit, autotune weekly, autotune propose. Merges with AOF policy capabilities. |
| `version` | Continuity | Version compatibility verification. |
| `budget` | Continuity + Boundary | Token budget, lean budget, gate budget. |
| `slo` | Incident + Continuity | Daily SLO evidence, SLO reporting. |
| `docs` | Authority + Promotion | Docs lint, freshness, projection sync, sprawl detect. Large family but all capabilities are normalization enforcement. |

### Folded Into Evidence/Continuity (Not Core Brain)

| Family | Reason |
| --- | --- |
| `audit` | Governance export and triage are evidence/continuity concerns, not core control-plane. Capabilities survive under evidence identity. |

### Held For Explicit Human Decision

| Family | Reason For Hold |
| --- | --- |
| `tenant` | Tenant provisioning may be a first-class subsystem or may fold into authority law. Depends on whether multi-tenant becomes a durable operating concern or remains single-operator. |

### Category Error — Rehome Out Of Core

| Family | Target |
| --- | --- |
| `share` | `PlatformProvider` runtime. One-way publication to external share channels is provider adapter behavior, not spine normalization. |
| `release` | `CI/CD` or publication runtime. Mirror sync, sanitization audit, and zip packaging are release/publication concerns, not core normalization. |

### Delete-Later Candidates

| Family | Condition |
| --- | --- |
| `conflicts` | Governance placeholder with no scripts, no capabilities, no live bindings, no live doc references. Safe to delete when confirmed unreferenced. |

## Convergence Requirement

Waves must converge toward the six normalization laws. A wave that preserves a historical folder shape without advancing law enforcement is not valid. A wave that moves files without declaring which law the move serves is not valid.

This does not mean every wave must touch all six laws. It means every wave must name which law it advances and must not create new surfaces that no law governs.

## L1 Surviving Set Reduction (2026-03-30)

This reduction pass applies the `PLATFORM_LAYER_MODEL.md` L1 test directly to
the live control-plane surfaces. The question is binary:

> Is this surface part of the core governed execution framework even if no
> product runtime is active?

### Binary L1 Sieve

| Surface Candidate | L1 Core Framework | Why |
| --- | --- | --- |
| `spine.control.*` | `yes` | Operator-facing control loop for observe, plan, route, and execute on the spine itself. |
| `wave.*` | `yes` | Governs wave execution, finish, and closeout of the control plane. |
| `loops.*` | `yes` | Canonical loop control and continuity surface. |
| `gaps.*` | `yes` | Governed closure register tied directly to loop control and defect retirement. |
| `friction.*` | `yes` | Control-plane self-observation and governed intake for controller/runtime failure evidence. |
| `mailroom.*` | `no` | Transport/runtime implementation detail. Survives only folded under route and continuity surfaces; the family name is not durable architecture. |
| receipt / attestation surfaces (`receipts.*`, broker attestation reads) | `yes` | Core continuity and attestation primitive. |
| session bootstrap / execution-lane surfaces (`session.v3.attach`, `session.execution.lane.*`) | `yes` | Governed entry, authority resolution, and bounded execution-lane control. |
| control-plane verification / recovery / observability surfaces (`verify.*`, `recovery.*`, control-plane observability status) | `yes` | Verify, incident response, and self-observation primitives of the spine engine. |

### Surviving L1 Set Matrix

| Law | Primitive Function | Surviving Governed Surface | Top-of-Stack Consumer | What Folds Under |
| --- | --- | --- | --- | --- |
| Authority | `govern` | `session.v3.attach`, `session.execution.lane.*` | controller session entry | entry packets, terminal identity resolution, lane bootstrap, role and write-scope enforcement |
| Boundary | `execute + route` | `spine.control.*` | controller/operator control loop | broker reads, route hints, delegated task transport, control-plane latest artifact plumbing |
| Promotion | `loop and wave control` | `wave.*`, `loops.*` | wave/controller owner | orchestration manifests, lane tickets, closeout glue, internal lifecycle helpers |
| Policy | `verify` | `verify.*` | verifier/controller | gate topology, verify packs, ring policy, core/domain dispatch plumbing |
| Incident | `self-observation + recovery` | `gaps.*`, `friction.*`, `recovery.*`, control-plane observability status surfaces | controller / incident operator | scheduler-health sampling, friction queue internals, recovery adapters, degraded-state probes |
| Continuity | `receipt / attestation + continuity` | `receipts.*`, `spine.broker.get_request_attestation`, `loops.continuity.update` | operator handoff / broker consumer | mailroom runtime roots, receipt indexes, evidence exports, control-plane latest projections |

The surviving set is intentionally surface-first. Folder names, plugin-family
labels, and transport roots do not survive as architecture unless they remain
the operator-facing governed surface.

## Explicit Non-Goals

- **Not a broad plugin rewrite.** Capability IDs, routing dispatch entries, and startup read surfaces are unchanged in this pass.
- **Not a startup-surface rewrite.** `session.v3.attach` and the session entry hook are not modified.
- **Not a capability-id rewrite.** Existing capability identifiers (`aof.status`, `surface.boundary.audit`, etc.) are stable. Renaming happens later if at all.
- **Not a folder-move pass.** This document defines the target architecture. Folder moves happen in governed execution packets with exact blocker chains.

## Execution Matrix

The per-family execution details, blocker chains, and migration actions are in:
- `/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/execution-packets-20260326/NORMALIZATION_KERNEL_FAMILY_MATRIX_20260326.md`

## Execution Packets

Governed execution packets for each classification category:
- `NORMALIZATION_KERNEL_FOLD_PACKET_20260326.md` — families folding into the kernel
- `EVIDENCE_CONTINUITY_FOLD_PACKET_20260326.md` — families folding into evidence/continuity
- `CORE_REHOME_PACKET_20260326.md` — families rehoming out of core
- `DELETE_CANDIDATES_PACKET_20260326.md` — families pending deletion
