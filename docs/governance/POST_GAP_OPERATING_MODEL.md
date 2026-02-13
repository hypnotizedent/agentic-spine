---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: post-gap-stabilization
---

# Post-Gap Operating Model

> Purpose: lock in a predictable, governance-first operating model after major gap closure.
>
> Canonical direction: `/Users/ronnyworks/code` is SSOT, `origin` (Gitea) is canonical remote, and all mutations are receipt-backed.

---

## 1) Stability Contract

"Hardened" means all of the following are true at the same time.

| Control | Pass Criteria | Fail Criteria |
|---|---|---|
| Drift gates | `./bin/ops cap run spine.verify` exits 0 | Any failing gate |
| Open-work hygiene | `./bin/ops status` shows 0 unlinked gaps and no unmanaged anomalies | Any unlinked gap, orphan loop, or unresolved anomaly |
| Authority chain | `SESSION_PROTOCOL` -> `GOVERNANCE_INDEX` -> `SSOT_REGISTRY` remains consistent | Any conflicting authority statement |
| Runtime path contract | Active governed runtime only in `agentic-spine`; workbench remains tooling-only | Runtime state/processes/sinks appear in non-canonical surfaces |
| Remote authority | `origin` is canonical and no GitHub/share split-brain for canonical flow | Canonical work merges outside Gitea flow |
| Receipt traceability | Every governed mutation has capability/proposal receipt evidence | Mutating action lacks receipt or proposal trace |

Stability state levels:
- `green`: all controls pass for 14 consecutive days.
- `yellow`: 1 control failed but restored within 24h.
- `red`: 2+ controls failed or any failure older than 24h.

---

## 2) Build-Mode Guardrails

### Allowed
- Read-only discovery via `./bin/ops cap run <read-only-cap>`.
- Single-surface governed mutation via `./bin/ops cap run <mutating-cap>` when no multi-agent collision risk exists.
- Evidence notes via `./bin/ops run --inline "..."` for read/discovery or rationale capture.
- Multi-step or cross-surface change through proposal flow (`proposals.submit` -> payload -> `proposals.apply`).

### Forbidden
- Direct manual edits to governed registries that have capability lock contracts (example: `operational.gaps.yaml`).
- Runtime operations from workbench.
- Ungoverned home-root runtime sinks (`~/*.log`, `~/*.out`, ad-hoc state roots).
- Cross-terminal write contention without proposal boundaries.
- Canonical merge flow outside Gitea authority.

Hard stop gates before mutating:
1. `./bin/ops status`
2. `./bin/ops cap run spine.verify`
3. `./bin/ops cap run gaps.status`

---

## 3) Standard Lifecycle Templates

### A. New VM Lifecycle
1. Plan: open loop scope and reserve lifecycle entry.
2. Provision: `infra.vm.provision` dry-run then execute.
3. Register: update VM/service/identity/bindings.
4. Validate: `vm.governance.audit`, `services.health.status`, `spine.verify`.
5. Operate: periodic health/backup/drift checks.
6. Decommission: dependency check, final backup policy, registry cleanup, verify.

### B. New Agent Lifecycle
1. Register governance: `ops/agents/<id>.contract.md` + `agents.registry.yaml`.
2. Implement behavior in workbench/mint-modules path declared in registry.
3. Wire routing rules.
4. Verify with D49 (`spine.verify`).
5. Close with receipt and loop linkage.

### C. New Capability Lifecycle
1. Define plugin script(s) and capability entry in `ops/capabilities.yaml`.
2. Add MANIFEST + capability map parity.
3. Add/refresh tests or exemption per D81 policy.
4. Validate read-only/dry-run safety semantics.
5. Verify (`spine.verify`) and receipt closeout.

### D. New Tooling/Plugin Lifecycle
1. Decide surface: spine plugin vs workbench tool config.
2. Register inventory/binding (`cli.tools.inventory.yaml`, plugin manifest, or both).
3. Define usage boundary and secrets preconditions.
4. Add gate coverage (new or existing) and tests/exemptions.
5. Verify + receipt + closeout.

### E. New Folder/Surface Lifecycle
1. Classify surface: canonical, supporting, runtime, or archive.
2. Update structure authority/index/binding before use.
3. Register verification expectations (allowlist/lock script if needed).
4. Validate no path-policy conflict (`~/code` case, legacy refs, runtime sink drift).
5. Close with receipt.

---

## 4) Required Artifacts Per Lifecycle

| Lifecycle | SSOT/Doc Entry | Binding Entry | Capability/Gate | Receipt Path | Closeout |
|---|---|---|---|---|---|
| VM | `VM_CREATION_CONTRACT.md`, relevant infra SSOTs | `vm.lifecycle.yaml`, target bindings | `infra.vm.*`, D35/D37/D45/D54/D69 | `receipts/sessions/RCAP-...` | loop scope + session closeout |
| Agent | `AGENTS_GOVERNANCE.md`, `AGENTS_LOCATION.md` | `agents.registry.yaml` | D49 | `receipts/sessions/RCAP-...` | loop + contract/version note |
| Capability | governance doc if new domain | `ops/capabilities.yaml`, `capability_map.yaml` | D63/D67 + plugin gate | `receipts/sessions/RCAP-...` | loop + release note |
| Tool/Plugin | relevant governance policy/runbook | tool inventory or plugin binding | D44 and/or D81 + domain gate | `receipts/sessions/RCAP-...` | loop + operator handoff |
| Folder/Surface | structure/governance index updates | allowlist/policy binding | D17/D42/D76-D80 | `receipts/sessions/RCAP-...` | loop + archive decision |

Definition: if any column is missing, lifecycle is incomplete.

---

## 5) Decision Matrix: `cap run` vs `run --inline` vs Proposal

| Change Shape | Use | Why |
|---|---|---|
| Single read-only status/query | `./bin/ops cap run <read-only>` | Governed command + receipt, lowest overhead |
| Single mutating action already implemented as capability | `./bin/ops cap run <mutating>` | Controlled execution path + policy preconditions |
| Evidence/narrative note, no file mutation | `./bin/ops run --inline "..."` | Lightweight receipt for discovery context |
| Multi-file, cross-surface, or multi-terminal change | Proposal flow (`proposals.submit` -> payload -> `proposals.apply`) | Prevents collision and preserves commit boundary |
| Any ambiguous write path | Proposal flow by default | Predictability over speed |

Escalation rule: when uncertain, treat as proposal work.

---

## 6) "No Tombstone /ronnyworks" Policy

Goal: avoid unmanaged decay in home and tooling surfaces.

Retention:
- Canonical sources remain under `~/code/*`.
- Runtime state remains in `agentic-spine/mailroom/*` and `receipts/sessions/*`.
- Historical artifacts move to `.archive/` with context.

Archive rules:
- Archive, do not silently delete, unless explicitly approved and receipted.
- Archived content is non-authoritative by default.
- Archive entries must include source path + reason + date in receipt narrative.

Suppression rules:
- Suppressions must be explicit, time-bounded, owner-assigned, and receipted.
- No perpetual suppressions for `critical` risk classes.
- Expired suppressions are immediate failures.

Cleanup cadence:
- Weekly: light hygiene sweep of new unmanaged surfaces.
- Monthly: suppression expiration review + stale artifact review.
- Quarterly: archive consolidation and policy refresh.

---

## 7) Drift Prevention Operating Cadence

Daily (Terminal C):
1. `./bin/ops status`
2. `./bin/ops cap run spine.verify`
3. `./bin/ops cap run gaps.status`
4. `./bin/ops cap run orchestration.status`

Weekly (Terminal C + delegated workers):
1. `./bin/ops cap run verify.drift_gates.certify`
2. `./bin/ops cap run vm.governance.audit`
3. `./bin/ops cap run host.drift.audit`
4. review suppression inventory and expirations

Monthly (Terminal C authority review):
1. SSOT freshness and index parity review
2. onboarding checklist review and update
3. KPI/SLA review + drift incident budget review
4. controlled backlog triage for stale open gaps

---

## 8) Ownership Model

### Terminal C Authority
- Owns control plane decisions and final apply authority.
- Owns policy exceptions/suppressions approval.
- Owns closeout quality and cadence enforcement.

### Worker Boundaries
- Execute scoped work only.
- No direct integration to canonical branch in multi-agent mode.
- Propose changes with explicit loop/gap trace.

### Escalation Path
1. Worker raises unresolved conflict in proposal receipt.
2. Terminal C decides: accept/rollback/re-scope.
3. If authority conflict persists, escalate to owner (`@ronny`) with evidence receipts.

---

## 9) Success Metrics and SLAs

Predictability KPIs:
- `spine.verify` pass rate: >= 98% weekly.
- Unlinked open gaps: 0 target.
- Proposal-to-apply lead time (non-emergency): <= 24h p50.
- Rework due to collision/revert: <= 1 incident/month.
- Missing receipt rate for mutations: 0.

Gap intake/closure SLAs:
- Critical: intake <= 4h, closure plan <= 24h.
- High: intake <= 24h, closure plan <= 3 days.
- Medium/Low: intake <= 3 days, closure plan <= 14 days.

Drift incident budget:
- Target budget: <= 2 yellow incidents/month, 0 red incidents/month.
- Budget breach triggers mandatory monthly rollback/stability review.

---

## 10) 30/60/90 Execution Roadmap

### Phase 1 (0-30 days): Stabilize and Freeze Baseline
Owner: Terminal C

Tasks:
1. Apply this operating model and checklist package.
2. Freeze new ungoverned surfaces (home/workbench/runtime).
3. Normalize change intake to decision matrix.
4. Establish suppression ledger with expirations.

Required gates/tests:
- `spine.verify`
- `verify.drift_gates.certify`
- `host.drift.audit`

Expected receipts:
- proposal apply receipt
- daily verify receipts
- suppression review receipt

Acceptance criteria:
- 14 consecutive days with no red incidents.
- 0 unlinked gaps.
- no unapproved suppressions.

Risk and rollback:
- Risk: over-constraining operators during urgent changes.
- Rollback: temporary exception via time-bounded suppression policy entry + Terminal C approval.

### Phase 2 (31-60 days): Standardize Onboarding
Owner: Terminal C (governance), Workers (implementation)

Tasks:
1. Enforce lifecycle templates for VM/agent/capability/tool/surface onboarding.
2. Require checklist completion + DoD evidence per onboarding type.
3. Eliminate ad-hoc onboarding paths.

Required gates/tests:
- D49/D63/D67/D69/D81 baseline pass
- targeted onboarding validation commands from `ONBOARDING_PLAYBOOK.md`

Expected receipts:
- per-onboarding capability receipts
- loop closeout receipts with artifact matrix evidence

Acceptance criteria:
- 100% of new onboarding work references lifecycle artifacts table.
- 0 onboarding actions bypassing proposal or governed capability path.

Risk and rollback:
- Risk: onboarding friction.
- Rollback: reduce mandatory fields only if risk-class remains unchanged and gates still enforceable.

### Phase 3 (61-90 days): Automate Enforcement
Owner: Terminal C + automation worker lane

Tasks:
1. Add automation checks for new bindings (`lifecycle`, `intake`, `suppressions`) into verify surfaces.
2. Auto-report KPI/SLA trends via scheduled read-only capability receipts.
3. Harden suppression expiry alerting.

Required gates/tests:
- extended `spine.verify` with new policy checks
- regression pass on D76-D82 and onboarding gates

Expected receipts:
- gate extension certification receipt
- monthly KPI receipt
- suppression expiry report receipt

Acceptance criteria:
- manual policy policing reduced to exception handling only.
- policy drift detected by gates before operator notices.

Risk and rollback:
- Risk: false positives in new automation.
- Rollback: disable new gate in warn-mode for one cycle, fix rule quality, re-enable enforce-mode.

---

## Related Documents

- `docs/governance/BUILD_MODE_CHECKLIST.md`
- `docs/governance/ONBOARDING_PLAYBOOK.md`
- `ops/bindings/lifecycle.standards.yaml`
- `ops/bindings/change.intake.policy.yaml`
- `ops/bindings/audit.suppressions.policy.yaml`
- `docs/governance/TERMINAL_C_DAILY_RUNBOOK.md`
- `docs/governance/GIT_REMOTE_AUTHORITY.md`
