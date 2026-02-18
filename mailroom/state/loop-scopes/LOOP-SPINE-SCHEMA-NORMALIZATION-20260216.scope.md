---
loop_id: LOOP-SPINE-SCHEMA-NORMALIZATION-20260216
opened: 2026-02-16
status: active
owner: "@ronny"
severity: high
scope: spine-schema-normalization
---

# Loop Scope: Spine Schema Normalization

## Vision (Owner Intent)

Eliminate the organic inconsistencies across spine subsystems that force agents to maintain per-subsystem gotchas in memory files. Establish a canonical conventions schema and enforce it with a meta-gate, so new and modified binding files converge on a single vocabulary.

## Problem Statement

The spine has 7+ subsystems (loops, gaps, proposals, capabilities, gates, receipts, SSOTs) that each invented their own conventions for status, dates, IDs, CLI args, error reporting, and YAML structure. This creates ~15 distinct gotchas that agents must memorize or rediscover each session.

## Deliverables

### D1: Conventions Schema

**File:** `ops/bindings/spine.schema.conventions.yaml`

Canonical definitions for:

- **Status vocabulary** — unified enum replacing 5 divergent sets:
  - Loops: `active/draft/open/closed/planned`
  - Gaps: `open/fixed/closed`
  - Proposals: `pending/applied/superseded/archived/read_only`
  - Capabilities: `ready/experimental/deprecated` (field: `lifecycle`, not `status`)
  - Gates: `retired: true/false` (boolean, not `status`)
  - VMs: 6 states; Backups: `enabled: true/false`

- **Date fields** — one name per semantic, one format:
  - `created_at` (not `opened`, `discovered_at`, `created`)
  - `updated_at` (not `updated`, `last_reviewed`, `last_synced`)
  - `closed_at` (not `closed`, `fixed_in` date component)
  - Format: ISO 8601 quoted string `"YYYY-MM-DD"` (add `T` time only when precision matters)

- **ID fields** — `id` everywhere (not `vmid`, `name`, `domain_id`); map-keyed subsystems document the key-as-id convention explicitly

- **Description fields** — `description` everywhere (deprecate `notes`)

- **Entry structure** — arrays of objects with `id` field as default; maps only for small static configs (policy presets, tenant profiles)

- **Severity/priority** — `severity: low|medium|high|critical` everywhere (not `classification`, not `risk_severity`)

- **Boolean style** — YAML native `true/false` only (not string `"yes"/"no"`)

### D2: CLI Argument Normalization

Canonical patterns for all `ops` commands and capabilities:

- **Gap commands** — normalize to consistent style:
  - Current: `gaps.file` uses all-named-flags; `gaps.claim`/`gaps.close` use positional-first
  - Target: decide one pattern and apply to all gap ops

- **Error prefixes** — shared library (`ops/lib/output.sh` or similar):
  - `FAIL:` — validation / precondition errors (exit 2)
  - `ERROR:` — system / runtime errors (exit 1)
  - `WARN:` — non-fatal, continues execution (exit 0)
  - Retire ad-hoc `STOP:`, `BLOCKED:` or alias them

- **Approval pattern** — document `approval: manual` stdin convention; consider `--approve` flag alternative

- **Exit codes** — `0`=success, `1`=runtime error, `2`=arg/validation error, `3`=policy block

### D3: Discovery Normalization

Three discovery patterns exist today — consolidate:

| Current | Subsystems | Target |
|---------|-----------|--------|
| `ops <noun> list` | loops, caps | Keep (native commands) |
| `ops cap run <noun>.status` | gaps, proposals | Keep (capability-driven) |
| No CLI | SSOTs, receipts | Add `ops ssot list` or equivalent |

### D4: Mutation Atomicity

- **Loops** — replace `sed -i` close with git-lock pattern (match gaps)
- **Proposals** — add clean-tree assertion before filesystem writes
- Document which subsystems are atomic vs. best-effort

### D5: Meta-Gate Enforcement

New drift gate (e.g., `D121-spine-schema-conventions-lock`) that:
- Validates new/modified files in `ops/bindings/` against conventions schema
- Checks field names (`id` not `vmid`, `description` not `notes`)
- Checks date format (quoted ISO 8601)
- Checks status values against canonical enum
- Allowlists existing files for gradual backfill

### D6: Existing File Migration

Gradual touch-and-fix as files are modified (not big-bang):
- `operational.gaps.yaml` — rename `discovered_at` → `created_at` (coordinate with gap commands)
- `vm.lifecycle.yaml` — rename `vmid` → `id`, `notes` → `description`
- `ssh.targets.yaml` — rename `notes` → `description`
- `backup.inventory.yaml` — rename `name` → `id`, add `status` field
- `capability.domain.catalog.yaml` — rename `domain_id` → `id`, `last_synced` → `updated_at`
- Loop scope frontmatter — quote dates, add `updated_at`
- Gate registry — normalize `retired` boolean to `status: retired`

## Related Loops

- `LOOP-YAML-QUERY-STANDARDIZATION-20260216` — yq→jq migration (complementary; that loop fixes *how* we read YAML, this loop fixes *what's in* the YAML)

## Out of Scope

- Rewriting all 262 yq call sites (covered by LOOP-YAML-QUERY-STANDARDIZATION)
- Changing the capability execution engine (cap.sh internals)
- Modifying receipt format (append-only, immutable by design)
- Renaming subsystem commands (e.g., `ops loops` stays `ops loops`)

## Known Risks

- **Field renames break consumers** — every rename in a binding file must update all scripts that read that field (drift gates, caps, commands). Coordinate via the meta-gate allowlist.
- **Gap command arg changes** — `gaps.claim`/`gaps.close` positional arg is baked into MEMORY.md and agent muscle memory. Migration needs a deprecation period or aliases.
- **D85 interaction** — gate registry parity gate must be updated if gate entries gain new required fields.

## Success Criteria

- `spine.schema.conventions.yaml` exists and is referenced by at least one enforcing gate
- All new binding files pass the conventions gate
- Gap CLI uses a single consistent argument pattern
- Agent MEMORY.md gotchas section shrinks (fewer per-subsystem workarounds needed)

## Phasing

1. **Phase 1:** Land conventions schema + meta-gate (enforcement on new files only) — **COMPLETE 2026-02-18**
   - `ops/bindings/spine.schema.conventions.yaml` landed (v1)
   - D129 gate enforcing in `aof` domain (gate mode: PASS, 0 violations)
   - Full audit baseline: 131 files checked, 8 violations (disallowed `notes` in 8 files), 100+ discouraged warnings
   - Touch-and-fix enforcement active: new/modified binding files validated on commit
   - Certification: `CAP-20260217-214411__schema.conventions.audit__Rp5xp54656`
2. **Phase 2:** Migrate high-value files (gaps, gates, VMs, loops frontmatter)
   - 2026-02-18 audit refresh: no blocking `notes` violations in the prior 8-file set; remaining work shifted to discouraged-key alias normalization.
3. **Phase 3:** CLI normalization (gap commands, error prefixes, exit codes)
4. **Phase 4:** Backfill remaining binding files organically

## 2026-02-18 SA2 Execution Pack (Active, Not Closeable Yet)

### Completed Slice In This Lane

- Re-ran full conventions audit: `CAP-20260217-233438__schema.conventions.audit__Rlyru43197`.
- Result: `violations: 0`, `warnings: 123` (gate-enforced baseline stable).
- Extracted exact warning-key counts from audit output:
  - `updated`: 84
  - `name`: 25
  - `gate_id`: 5
  - `domain_id`: 2
  - `last_synced`: 2
  - `agent_id`: 1
  - `last_reviewed`: 1

### Remaining Deltas (Exact)

1. Alias-key normalization backlog: 123 warning instances across `ops/bindings/*.yaml` (non-blocking today, required for convergence).
2. Legacy-key exceptions still present and explicitly allowlisted:
   - `ops/bindings/operational.gaps.yaml`: `notes`, `discovered_at`
   - `ops/bindings/ssh.targets.yaml`: `notes`
3. CLI normalization still open by strict objective (positional compatibility still exists for `gaps-claim` and `gaps-close`; final retirement policy not yet codified).
4. Discovery normalization still open (`ops ssot list` or equivalent canonical discovery surface not yet landed).
5. Mutation atomicity normalization still open for loops/proposals (loop close path still `sed`-based in `ops/commands/loops.sh`).

### Stop Condition For Closure

Loop remains `active` until D2/D3/D4 convergence work above is implemented and success criteria are fully evidenced.
