# Spine Conventions Canonical Audit

**Audit Date:** 2026-02-16
**Auditor:** Terminal D (Canonical Normalization Auditor)
**Scope:** Full AOF conventions audit across all spine surfaces
**Mode:** Read-only audit lane (no runtime behavior changes)

---

## Executive Summary

This audit identifies root-cause normalization debt across ALL spine surfaces, not just gates. The analysis reveals six primary drift clusters requiring systematic remediation across 116 binding files, 1072 error/output lines, and 174 CLI usage signatures.

**Key Finding:** The schema conventions defined in `ops/bindings/spine.schema.conventions.yaml` are not being enforced at gate-time, allowing legacy field aliases (`vmid`, `notes`, `discovered_at`) and non-canonical status values to proliferate unchecked.

---

## Findings (Ordered by Severity)

### [P0] Field Alias Fragmentation — `notes` vs `description`

**Issue:** 743 occurrences of legacy `notes:` field across 10 high-impact files. The canonical field is `description:`.

**Root Cause:** No gate enforcement of `spine.schema.conventions.yaml` field_rules.disallowed_alias_keys. Legacy exemptions exist but are not being validated.

**Evidence:**
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/operational.gaps.yaml`: 540 occurrences (line 88-1402)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/services.health.yaml`: 52 occurrences
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/home.device.registry.yaml`: 37 occurrences
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml`: 24 occurrences
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml`: 19 occurrences

**Impact:** High. Agents and scripts reading these files may expect `description:` and fail or return incomplete data.

**Fix Approach:** Touch-and-fix with reader fallback. Add `description:` as alias reader, then migrate entries incrementally.

---

### [P0] Field Alias Fragmentation — `vmid` vs `id`

**Issue:** 49 occurrences of legacy `vmid:` field across 5 files. The canonical field is `id:`.

**Root Cause:** VM lifecycle bindings predate schema conventions. Downstream capabilities/scripts depend on `vmid:` key.

**Evidence:**
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml`: 19 occurrences (lines 30, 73, 105, etc.)
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.operating.profile.yaml`: 13 occurrences
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.derived.yaml`: 13 occurrences
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/tenants/media-stack.yaml`: 2 occurrences
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/home.device.registry.yaml`: 2 occurrences

**Impact:** High. VM-related capabilities may fail if they only look for `id:`.

**Fix Approach:** Explicitly exempted in `spine.schema.conventions.yaml` legacy_exceptions. Requires downstream capability updates before migration.

---

### [P1] Non-Canonical Status Values

**Issue:** 39 occurrences of status values not in the canonical enum (lines 19-46 of `spine.schema.conventions.yaml`).

**Non-Canonical Values Found:**
- `stopped` (4): `ops/bindings/vm.lifecycle.yaml` lines 494, 556, 584
- `installed` (1): `ops/bindings/network.home.baseline.yaml` line 37
- `connected` (1): `ops/bindings/network.home.baseline.yaml` line 43
- `migrated` (29): `ops/bindings/infra.relocation.plan.yaml` lines 91-316
- `temporary` (1): `ops/bindings/spine.verify.runtime.yaml` line 2
- `accepted` (3): `ops/bindings/operational.gaps.yaml` lines 640, 989, 1402
- `template` (1): `ops/bindings/vm.lifecycle.yaml` line 615

**Impact:** Medium. Status-based filtering/queries may miss these entries.

**Fix Approach:** Either add to canonical enum (with rationale) or migrate to closest canonical value:
- `stopped` → `parked` or `decommissioned`
- `installed` → `active` or `provisioned`
- `connected` → `active`
- `migrated` → `applied` or `closed`
- `temporary` → `experimental`
- `accepted` → `open` (with acceptance note)
- `template` → `provisioned` (with template flag)

---

### [P1] Error/Output Vocabulary Inconsistency

**Issue:** No standardized error/output prefix vocabulary across verify surface and plugins.

**Evidence:** From `error_prefixes.txt` (1072 lines):
- FAIL: 737 occurrences
- PASS: 307 occurrences
- WARN: ~150 occurrences
- ERROR: ~80 occurrences
- STOP: ~25 occurrences
- BLOCKED: ~5 occurrences

**Inconsistent Patterns:**
- `D115 FAIL:` vs `FAIL:` vs `echo "FAIL:"` 
- `err()` function in some files, inline `echo "FAIL"` in others
- `ERROR:` vs `Error:` casing inconsistency
- `STOP:` block format vs inline `echo "STOP:"`

**Impact:** Medium. Log parsing, monitoring, and error aggregation tools cannot rely on consistent patterns.

**Fix Approach:** Standardize on:
- `PASS:` / `FAIL:` for gate results
- `WARN:` for non-blocking issues
- `STOP:` for blocking preconditions
- `ERROR:` for unexpected failures
- Gate prefix format: `D## PASS` / `D## FAIL`

---

### [P2] CLI Argument Style Inconsistency

**Issue:** Mixed positional and named flag styles across CLI commands.

**Evidence:** From `cli_usage_signatures.txt` (174 Usage: blocks):
- Named flags (`--id`, `--status`, `--profile`): ~60
- Positional args: ~40
- Mixed style: ~74

**Examples:**
- `gaps-claim --id <GAP_ID>` (named) — line 46
- `gaps-close --id <GAP_ID> --status <fixed|closed>` (named) — line 85
- `session-start <lane>` (positional) — line 71
- `agent-route <domain-or-keyword>` (positional) — line 35

**Impact:** Low-Medium. User experience inconsistency, harder to script.

**Fix Approach:** Per `spine.schema.conventions.yaml` cli_conventions.preferred_argument_style: named_flags. Add positional as compatibility alias only.

---

### [P2] Mutation Atomicity Inconsistency

**Issue:** Not all mutating operations use git-lock serialization.

**Evidence:** From `mutating_writes.txt` (57 yq/sed writes) and `mutation_locking.txt` (23 lock usages):
- Git-lock used: `gaps-file`, `gaps-close`, `start.sh`, `close.sh`, `pr.sh`
- Git-lock NOT used: orchestration plugins, proposals plugins, infra plugins

**Examples without git-lock:**
- `ops/plugins/orchestration/bin/orchestration-loop-open`: 11 yq e -i calls
- `ops/plugins/proposals/bin/proposals-supersede`: 4 sed -i calls
- `ops/plugins/infra/bin/infra-relocation-service-transition`: 2 yq e -i calls

**Impact:** Low. Single-agent sessions are safe, but multi-agent sessions could race.

**Fix Approach:** Add git-lock to all binding-mutating capabilities.

---

### [P3] Date Field Format Inconsistency

**Issue:** Mixed ISO-8601 formats and date field names across bindings.

**Evidence:** From `date_field_variants.txt` (745 occurrences):
- `updated: "2026-02-15"` (date only)
- `updated: "2026-02-07T23:06:19Z"` (full ISO-8601)
- `last_reviewed: '2026-02-16'` (single quotes)

**Impact:** Low. Parsing tools may need to handle both formats.

**Fix Approach:** Standardize on ISO-8601 with optional time component per `spine.schema.conventions.yaml` iso_8601_regex.

---

## Root-Cause Clusters

### 1. Status Vocabulary Fragmentation
- **Cause:** No gate enforcement of status enum
- **Files:** 15 files with non-canonical values
- **Entries:** 39 non-canonical status values

### 2. Field Alias Fragmentation (id/description/date)
- **Cause:** Legacy exemptions without migration timeline
- **Files:** 10+ files
- **Entries:** 743 notes, 49 vmid, 22 discovered_at, 1 opened

### 3. CLI Argument Inconsistency
- **Cause:** No linting of Usage: blocks
- **Files:** 174 Usage: blocks across ops/plugins, ops/commands
- **Entries:** ~40% positional, ~35% named, ~25% mixed

### 4. Mutation Atomicity Inconsistency
- **Cause:** git-lock not universally required for binding mutations
- **Files:** 34 mutating scripts
- **Entries:** 23 use git-lock, 11 do not

### 5. Discovery-Pattern Inconsistency
- **Cause:** No single source of truth for capability discovery UX
- **Files:** AGENTS.md, CLAUDE.md, docs/
- **Entries:** 475 discovery pattern references

### 6. Error/Output Vocabulary Inconsistency
- **Cause:** No gate or lint for output prefix standardization
- **Files:** surfaces/verify/, ops/plugins/, ops/commands/
- **Entries:** 1072 lines with error prefixes

---

## Quantified Debt

| Metric | Count |
|--------|-------|
| **Field alias violations** | 815 (743 notes + 49 vmid + 22 discovered_at + 1 opened) |
| **Non-canonical status values** | 39 |
| **Mutation scripts without git-lock** | 11 |
| **CLI usage inconsistencies** | ~70 |
| **Error prefix inconsistencies** | ~200 (estimated from manual review) |
| **Total binding files** | 116 |
| **Total verify scripts** | ~30 |

### Highest Blast-Radius Surfaces
1. `ops/bindings/operational.gaps.yaml` — 540 notes, 560 status, 3 accepted
2. `ops/bindings/vm.lifecycle.yaml` — 19 vmid, 19 notes, 5 non-canonical status
3. `ops/bindings/infra.relocation.plan.yaml` — 29 migrated status
4. `surfaces/verify/` directory — 1072 error/output lines

---

## Canonical Fix Strategy

### Phase 2B: Safe Field Renames with Reader Fallback
**Scope:** notes → description migration in non-exempted files

**Approach:**
1. Add `description:` reader fallback in all consumer scripts
2. Add `description:` field alongside `notes:` in bindings
3. Verify core + domain(aof) passes
4. Remove `notes:` field from bindings
5. Verify core + domain(aof) passes

**Estimated Entries:** 183 (non-exempted notes occurrences)

### Phase 2C: Status Enum Alignment
**Scope:** Add non-canonical values to enum OR migrate to canonical

**Approach:**
1. Audit each non-canonical status for semantic match
2. Either:
   - Add to canonical enum with rationale (e.g., `template`, `migrated`)
   - Migrate to closest canonical value (e.g., `stopped` → `parked`)
3. Update consumers accordingly
4. Add gate to enforce status enum

**Estimated Entries:** 39

### Phase 2D: Mutation Atomicity + Output Vocabulary
**Scope:** Add git-lock to all mutating operations; standardize error prefixes

**Approach:**
1. Audit all yq e -i / sed -i calls for git-lock presence
2. Add git-lock to missing scripts
3. Standardize error prefix format across verify surface
4. Add lint rule for output vocabulary

**Estimated Scripts:** 11 mutation scripts, ~200 error prefix fixes

### Phase 2E: Discovery UX Normalization
**Scope:** Standardize capability discovery patterns in agent entry surfaces

**Approach:**
1. Consolidate discovery patterns into single source
2. Ensure AGENTS.md, CLAUDE.md reference same patterns
3. Add lint for discovery pattern consistency

**Estimated Files:** 3 agent entry surfaces

---

## Evidence Index

All evidence artifacts located at:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/_artifacts/SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216/`

| Artifact | Lines | Purpose |
|----------|-------|---------|
| `legacy_alias_keys.txt` | 1437 | All vmid/notes/opened/discovered_at/last_synced/last_reviewed/updated occurrences |
| `status_fields.txt` | 656 | All status: field occurrences |
| `status_outside_canonical.txt` | 39 | Non-canonical status values |
| `date_field_variants.txt` | 745 | All date field variants |
| `cli_usage_signatures.txt` | 174 | All Usage: blocks |
| `error_prefixes.txt` | 1072 | All FAIL/ERROR/WARN/STOP/BLOCKED prefixes |
| `mutating_writes.txt` | 57 | All yq e -i / sed -i calls |
| `mutation_locking.txt` | 23 | All git-lock usages |
| `discovery_patterns.txt` | 475 | All ops cap run / ops [cmd] list references |
| `lifecycle_fields.txt` | 9 | All lifecycle: field occurrences |
| `summary_counts.txt` | 80 | Aggregated counts and analysis |

---

## Certification

**Audit Lane:** Read-only (no gate changes, no binding mutations)
**Verify Status:** Core-8 PASS, AOF Domain PASS (pre-audit)
**Post-Audit Verify:** Required (run `./bin/ops cap run verify.core.run` and `./bin/ops cap run verify.domain.run aof`)

---

*Audit completed: 2026-02-16*
*Next action: Review backlog at `SPINE_CONVENTIONS_PHASE2B_BACKLOG_20260216.md`*
