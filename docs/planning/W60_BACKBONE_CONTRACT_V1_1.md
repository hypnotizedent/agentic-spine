# W60 BACKBONE CONTRACT V1.1

```yaml
status: draft
version: "1.1"
created: 2026-02-28
author: claude-cowork@desktop + codex-review + codex-patch
owner: ronny
scope: agentic-spine + workbench + mint-modules
supersedes: /Users/ronnyworks/Desktop/W60_BACKBONE_CONTRACT_V1.md
success_bar: parity receipt proving zero fragmented authority surfaces and fix-to-lock closure on all closed P0/P1
```

## V1.1 Patch Delta (from V1)

This revision applies eight required hardening edits:

1. Add truth-first preamble (`CONFIRMED | STALE_ALREADY_FIXED | PARTIAL | MISLOCATED_PATH`) before implementation.
2. Replace grep-only authority test with machine-readable concern map.
3. Reserve gate IDs at apply-time (no hard-coded final IDs in draft).
4. Stage fix-to-lock closure enforcement (`report` soak before `enforce`).
5. Add explicit lifecycle exclusions for protected lanes and legal/compliance holds.
6. Treat gate-count drift as verify-then-patch (no assumed stale claim).
7. Define projection generation command and owner.
8. Add no-new-authoritative-docs rule unless concern map is updated in same commit.

---

## Truth-First Preamble (Mandatory)

No finding may be implemented directly from audit text without live verification.
Each finding must be classified first:

```yaml
truth_classification:
  - CONFIRMED
  - STALE_ALREADY_FIXED
  - PARTIAL
  - MISLOCATED_PATH
```

Execution rule:
- `CONFIRMED`: implement.
- `PARTIAL`: implement only confirmed fragment(s), gap-link remainder.
- `STALE_ALREADY_FIXED`: record evidence, no mutation.
- `MISLOCATED_PATH`: correct path mapping, then reclassify.

---

## Problem Statement

The spine governance layer detects drift but does not reliably resist it. Growth adds maintenance surface faster than runtime intelligence. Fixes often land as local patches without durable prevention.

**Core failure mode:** control-to-outcome disconnect (controls exist, closure does not).

**Design target:** runtime-first agentic system where each closure is self-defending via regression locks and lifecycle automation.

---

## The Four Moves

### Move 1: Single-Authority Constraint

**Rule:** `exactly_one_authoritative_per_concern`.

For any concern surface (services, gates, agents, domains, secrets, compose-targets), exactly one file may be authoritative. Others must be:

- `projection`
- `tombstoned`

#### Concern Map (machine-checkable)

```yaml
# canonical path (proposed)
# /Users/ronnyworks/code/agentic-spine/ops/bindings/authority.concerns.yaml
concerns:
  services:
    authority: docs/governance/SERVICE_REGISTRY.yaml
    projections:
      - ops/bindings/services.health.yaml
      - ops/bindings/media.services.yaml
  gates:
    authority: ops/bindings/gate.registry.yaml
    projections:
      - AGENTS.md
      - CLAUDE.md
  domains:
    authority: ops/bindings/agents.registry.yaml
    projections:
      - docs/governance/domains/
  mcpjungle_config:
    authority: /Users/ronnyworks/code/workbench/infra/compose/mcpjungle/
    projections:
      - /Users/ronnyworks/code/workbench/mcpjungle/
```

#### Enforcement primitive (ID reserved at apply-time)

```yaml
gate_id: D_RESERVE_SINGLE_AUTHORITY
proposed_id_preference: D281
name: single-authority-lock
class: invariant
validates: |
  For each concern in authority.concerns.yaml:
  - exactly one authority path exists
  - all non-authority paths are explicitly projection or tombstoned
failure_mode: hard_fail
```

#### Verify-then-patch requirement (gate count example)

Entry-surface claims (e.g., gate totals in AGENTS/CLAUDE) must be verified against `gate.registry.yaml` before patching. Do not assume stale values.

---

### Move 2: Fix-to-Lock Closure

**Rule:** No P0/P1 closure without prevention artifact.

```yaml
closure:
  root_cause: <one sentence>
  regression_lock_id: <gate/test/check id>
  owner: <owner>
  expiry_check: <date or cadence>
```

#### Enforcement primitive (ID reserved at apply-time)

```yaml
gate_id: D_RESERVE_FIX_TO_LOCK
proposed_id_preference: D282
name: fix-to-lock-closure-gate
class: invariant
validates: |
  Every closed P0/P1 gap has all closure fields present.
failure_mode: hard_fail
```

#### Rollout policy

```yaml
rollout:
  mode: staged
  report_window: 48h
  enforce_after: report_window_clean
```

Retroactive rule:
- Closed P0/P1 gaps in lookback window missing `regression_lock_id` become `reopened_no_lock` after report soak.

---

### Move 3: Freshness from Runtime

**Rule:** freshness reconciles from observed runtime state by default.

Gate taxonomy:
- `invariant` (hard fail)
- `freshness` (hold/warn based on staleness window)
- `advisory` (report-only)

Freshness schema:

```yaml
gate_id: D-RESERVE-ANY
class: freshness
max_staleness: 24h
reconcile_from: runtime
observed_state_source: <command/api>
desired_state_source: <contract/registry>
fallback: manual_snapshot
last_reconciled: <ISO8601 set by automation>
```

Policy:
- Manual snapshots are fallback, not primary success path.
- Freshness automation failure is a distinct operational state, not silent drift.

---

### Move 4: Subtraction as Policy

**Rule:** stale artifacts must transition by lifecycle state machine.

```text
created -> active -> stale -> archived -> deleted(token_required)
```

#### Enforcement primitive (ID reserved at apply-time)

```yaml
gate_id: D_RESERVE_LIFECYCLE_AUTOMATION
proposed_id_preference: D283
name: lifecycle-automation-lock
class: freshness
max_staleness: 7d
validates: |
  Artifacts matching archival policy do not remain indefinitely in active paths.
reconcile_from: runtime
```

#### Exclusions (explicit)

```yaml
exclusions:
  protected_loops:
    - LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
  protected_gaps:
    - GAP-OP-973
  legal_hold_patterns:
    - receipts/sessions/**/LEGAL_HOLD*
  compliance_retention_patterns:
    - receipts/sessions/**/COMPLIANCE_RETENTION*
```

---

## Projection Generation Contract

Derived entry surfaces must be generated, not manually drifted.

```yaml
projection_generation:
  owner: SPINE-CONTROL-01
  source_of_truth:
    - ops/bindings/gate.registry.yaml
    - ops/bindings/authority.concerns.yaml
  outputs:
    - AGENTS.md
    - CLAUDE.md
  command_contract: ./bin/ops cap run docs.projection.sync
  verify_contract: ./bin/ops cap run docs.projection.verify
```

If generator capability does not exist, it must be added before marking this contract authoritative.

---

## No-New-Authority Rule

No commit may introduce a new `authoritative` or `status: authoritative` file unless the same commit updates the concern map and parity lock expectations.

```yaml
rule: no_new_authority_without_map_update
failure_mode: hard_fail
```

---

## Execution Sequence

### Phase 1: Authority collapse
- Build/commit concern map.
- Resolve duplicate authority claims.
- Register and run single-authority lock.

### Phase 2: Fix-to-lock retrofit
- Audit closed P0/P1 gaps.
- Reopen missing-lock closures in report mode.
- Promote to enforce after 48h clean window.

### Phase 3: Gate class normalization
- Classify active gates into invariant/freshness/advisory.
- Wire top freshness gates to runtime reconcilers.

### Phase 4: Subtraction sweep
- Apply receipts/proposals archival policy.
- Execute report->archive lifecycle.
- Delete only with explicit token window.

---

## Success Bar (W60 Exit Criteria)

1. Concern map exists and passes parity checks.
2. No duplicate authority claims per concern.
3. No closed P0/P1 gap missing `regression_lock_id` (after staged rollout).
4. Freshness failures are runtime-drift or automation failures, not “human forgot snapshot.”
5. Lifecycle policy transitions stale artifacts out of active surfaces.
6. Final parity receipt proves no fragmented authority surfaces remain.

---

## Provenance

- Input draft: `/Users/ronnyworks/Desktop/W60_BACKBONE_CONTRACT_V1.md`
- Patch basis: operator request + Codex review hardening points
- Intended consumer: W60 supervisor terminal (single-writer orchestration)
