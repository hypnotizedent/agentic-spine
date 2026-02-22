# Spine Conventions Phase 2B Backlog

**Generated:** 2026-02-16
**Source Audit:** `SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216.md`
**Scope:** Safe field renames + reader fallback + status alignment

---

## Sequencing Rules

1. **Touch-and-fix only** — Never bulk-rename without reader fallback
2. **Reader fallback first, field rename second** — Consumers must accept both keys
3. **Verify core + domain(aof) after each batch** — Gate regression = rollback
4. **One file per commit** — Atomic, reversible changes
5. **Legacy exemptions respected** — Do NOT touch exempted files without downstream updates

---

## P0 Batch (Highest Leverage)

### P0-01: operational.gaps.yaml — notes → description migration

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/operational.gaps.yaml` |
| **Drift Type** | `notes:` → `description:` (540 occurrences) |
| **Required Change** | Add `description:` field alongside `notes:` for each gap entry |
| **Reader Updates** | `ops/plugins/loops/bin/gaps-*`, `ops/commands/loops.sh` |
| **Risk** | Medium — 540 entries, but exempted in schema conventions |
| **Approach** | Incremental touch-and-fix over multiple sessions |

**Prerequisite:** None (exempted file, but migration beneficial)

**Execution Steps:**
1. Update gap readers to check both `description` and `notes`
2. Run verify.core.run + verify.domain.run aof
3. Add `description:` to 10 gaps as pilot
4. Run verify.core.run + verify.domain.run aof
5. Continue in batches of 50
6. Final: Remove `notes:` field (future phase)

---

### P0-02: vm.lifecycle.yaml — vmid → id migration planning

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/vm.lifecycle.yaml` |
| **Drift Type** | `vmid:` → `id:` (19 occurrences) |
| **Required Change** | Add `id:` field alongside `vmid:` |
| **Reader Updates** | All VM-related capabilities, `ops/plugins/*/bin/*vm*`, stability.control.snapshot |
| **Risk** | HIGH — Downstream dependencies unknown without full capability audit |
| **Approach** | Reader audit first, then incremental migration |

**Prerequisite:** Full audit of vmid consumers

**Execution Steps:**
1. Grep all vmid consumers: `rg -n '\bvmid\b' ops/`
2. Update each consumer to check both `id` and `vmid`
3. Run verify.core.run + verify.domain.run aof
4. Add `id:` field alongside `vmid:` in vm.lifecycle.yaml
5. Run verify.core.run + verify.domain.run aof
6. Future phase: Remove `vmid:` after all consumers migrated

**DO NOT START** until downstream audit complete.

---

### P0-03: ssh.targets.yaml — notes → description migration

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/ssh.targets.yaml` |
| **Drift Type** | `notes:` → `description:` (24 occurrences) |
| **Required Change** | Add `description:` field alongside `notes:` |
| **Reader Updates** | SSH-related capabilities, connection scripts |
| **Risk** | Low — Few consumers, exempted file |

**Prerequisite:** Audit ssh.targets consumers

**Execution Steps:**
1. Grep consumers: `rg -n 'ssh.targets' ops/`
2. Update consumers to check both `description` and `notes`
3. Run verify.core.run + verify.domain.run aof
4. Add `description:` to each entry
5. Run verify.core.run + verify.domain.run aof
6. Future phase: Remove `notes:` field

---

## P1 Batch

### P1-01: infra.relocation.plan.yaml — status: migrated normalization

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/infra.relocation.plan.yaml` |
| **Drift Type** | `status: migrated` not in canonical enum (29 occurrences) |
| **Required Change** | Either add `migrated` to enum or change to `closed`/`applied` |
| **Reader Updates** | `ops/plugins/infra/bin/infra-relocation-*` |
| **Risk** | Medium — Active relocation protocol |

**Decision Required:** Should `migrated` be added to canonical status enum?

**If YES:**
1. Add `migrated` to `spine.schema.conventions.yaml` status_rules.allowed_values
2. Run verify.core.run + verify.domain.run aof

**If NO:**
1. Change all `status: migrated` to `status: applied`
2. Update infra-relocation consumers accordingly
3. Run verify.core.run + verify.domain.run aof

---

### P1-02: vm.lifecycle.yaml — status: stopped/template normalization

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/vm.lifecycle.yaml` |
| **Drift Type** | `status: stopped` (4), `status: template` (1) not in canonical enum |
| **Required Change** | Map to canonical values or add to enum |
| **Reader Updates** | VM lifecycle capabilities |
| **Risk** | Medium — VM state tracking |

**Decision Required:** 
- `stopped` → `parked` or `decommissioned`? (Add `stopped` to enum?)
- `template` → `provisioned` with `is_template: true`? (Add `template` to enum?)

---

### P1-03: network.home.baseline.yaml — status: installed/connected normalization

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/network.home.baseline.yaml` |
| **Drift Type** | `status: installed` (1), `status: connected` (1) |
| **Required Change** | Map to canonical values |
| **Reader Updates** | Network audit scripts |
| **Risk** | Low — Only 2 occurrences |

**Recommendation:** 
- `installed` → `provisioned`
- `connected` → `active`

---

### P1-04: spine.verify.runtime.yaml — status: temporary normalization

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/spine.verify.runtime.yaml` |
| **Drift Type** | `status: temporary` (1) |
| **Required Change** | Map to canonical value |
| **Reader Updates** | Verify surface |
| **Risk** | Low |

**Recommendation:** `temporary` → `experimental`

---

### P1-05: operational.gaps.yaml — status: accepted normalization

| Attribute | Value |
|-----------|-------|
| **File** | `ops/bindings/operational.gaps.yaml` |
| **Drift Type** | `status: accepted` (3 occurrences) |
| **Required Change** | Map to canonical value |
| **Reader Updates** | Gap lifecycle scripts |
| **Risk** | Low — Only 3 occurrences |

**Decision Required:** `accepted` → `open` (with acceptance note) or add to enum?

---

## P2 Batch

### P2-01: Error/Output Vocabulary Standardization — drift-gate.sh

| Attribute | Value |
|-----------|-------|
| **File** | `surfaces/verify/drift-gate.sh` |
| **Drift Type** | Inconsistent error prefixes (24 occurrences) |
| **Required Change** | Standardize to `D## PASS` / `D## FAIL` format |
| **Reader Updates** | None (output only) |
| **Risk** | Low — Cosmetic change |

---

### P2-02: Error/Output Vocabulary Standardization — Top 5 verify scripts

| Files | Lines |
|-------|-------|
| `surfaces/verify/d52-udr6-gateway-assertion.sh` | 22 |
| `surfaces/verify/d90-rag-reindex-runtime-quality-gate.sh` | 20 |
| `surfaces/verify/verify-identity.sh` | 18 |
| `surfaces/verify/monitoring_verify.sh` | 16 |
| `surfaces/verify/backup_verify.sh` | 14 |

**Approach:** Batch standardize in single commit per file.

---

### P2-03: CLI Argument Style — gaps-* commands

| File | Current Style | Target Style |
|------|---------------|--------------|
| `ops/plugins/loops/bin/gaps-claim` | `--id <GAP_ID>` | ✓ Already named |
| `ops/plugins/loops/bin/gaps-unclaim` | `--id <GAP_ID>` | ✓ Already named |
| `ops/plugins/loops/bin/gaps-close` | `--id <GAP_ID> --status <status>` | ✓ Already named |
| `ops/plugins/loops/bin/gaps-file` | `--id <GAP_ID> --type <type>` | ✓ Already named |

**Status:** Already compliant with named_flags preference.

---

### P2-04: CLI Argument Style — Positional commands

| File | Current | Target |
|------|---------|--------|
| `ops/plugins/session/bin/session-start` | `<lane>` positional | `--lane <lane>` or keep as positional alias |
| `ops/plugins/agent/bin/agent-route` | `<domain-or-keyword>` positional | `--domain <domain>` or keep as positional alias |

**Recommendation:** Keep as positional alias, add named flag as primary.

---

### P2-05: Mutation Atomicity — Add git-lock to orchestration scripts

| File | yq e -i Calls | Has git-lock |
|------|---------------|--------------|
| `ops/plugins/orchestration/bin/orchestration-loop-open` | 11 | NO |
| `ops/plugins/orchestration/bin/orchestration-handoff-validate` | 4 | NO |
| `ops/plugins/orchestration/bin/orchestration-ticket-issue` | 4 | NO |
| `ops/plugins/orchestration/bin/orchestration-terminal-entry` | 4 | NO |
| `ops/plugins/orchestration/bin/orchestration-integrate` | 3 | NO |
| `ops/plugins/orchestration/bin/orchestration-loop-close` | 2 | NO |

**Approach:** Add `source "$ROOT/ops/lib/git-lock.sh"` and wrap mutations with acquire/release.

---

### P2-06: Mutation Atomicity — Add git-lock to infra/proposals scripts

| File | yq e -i/sed -i Calls | Has git-lock |
|------|----------------------|--------------|
| `ops/plugins/infra/bin/infra-relocation-service-transition` | 2 | NO |
| `ops/plugins/infra/bin/infra-relocation-state-transition` | 4 | NO |
| `ops/plugins/proposals/bin/proposals-supersede` | 4 | NO |

---

## P3 Batch (Future)

### P3-01: Date format standardization

**Scope:** Ensure all date fields match ISO-8601 regex from schema conventions.

**Approach:** Lint + auto-fix with verification.

---

### P3-02: Discovery pattern consolidation

**Scope:** Consolidate AGENTS.md, CLAUDE.md, docs/ capability discovery patterns.

**Approach:** Single source of truth in `docs/governance/AGENT_GOVERNANCE_BRIEF.md`, mirror to entry surfaces.

---

## Backlog Summary

| Priority | Items | Estimated Effort |
|----------|-------|------------------|
| P0 | 3 | High (P0-02 blocked on audit) |
| P1 | 5 | Medium |
| P2 | 6 | Medium |
| P3 | 2 | Low |
| **Total** | **16** | **~8-12 hours over multiple sessions** |

---

## Execution Checklist

Before starting any batch:

- [ ] Run `./bin/ops cap run stability.control.snapshot`
- [ ] Run `./bin/ops cap run verify.core.run`
- [ ] Run `./bin/ops cap run verify.domain.run aof`
- [ ] Confirm audit artifacts exist in `_artifacts/` directory

After completing each batch:

- [ ] Run `./bin/ops cap run verify.core.run`
- [ ] Run `./bin/ops cap run verify.domain.run aof`
- [ ] Commit with message: `gov(GAP-OP-XXX): conventions normalization batch P#-##`
- [ ] Update this backlog with completion status

---

*Backlog generated: 2026-02-16*
*Next action: Start with P0-01 (operational.gaps.yaml notes migration)*
