# AOF Standards Pack v1 — Proposal Input

**Generated:** 2026-02-16
**Auditor:** Terminal D
**Source Audit:** `SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216.md`

---

## Purpose

This document provides the evidence base and analysis for the AOF Standards Pack v1 proposal. It identifies the root-cause drift patterns that the standards pack will address.

---

## Evidence Anchors Analyzed

| File | Purpose | Key Finding |
|------|---------|-------------|
| `README.md` | Control-plane boundary definition | Clear ownership split (spine vs workbench) but no enforcement gate |
| `ops/bindings/mailroom.runtime.contract.yaml` | Runtime path externalization | Authoritative but not validated by boundary audit |
| `ops/bindings/spine.boundary.baseline.yaml` | Boundary rules | Glob-based only, no tracked_exceptions enforcement |
| `ops/plugins/surface/bin/surface-boundary-audit` | Boundary audit impl | Scans globs, ignores tracked_exceptions whitelist |
| `ops/plugins/verify/bin/surface-audit-full` | Full surface audit | 10-section audit, but missing catalog freshness check |
| `ops/plugins/proposals/bin/proposals-submit` | Proposal creation | Creates manifest but no schema validation |
| `ops/plugins/release/bin/spine-release-zip` | Release packaging | No git-lock required (read-only archive) |
| `surfaces/verify/d74-billing-provider-lane-lock.sh` | Provider lane enforcement | Strong pattern: validates defaults + blocks silent fallbacks |
| `ops/bindings/capability.domain.catalog.yaml` | Domain capability registry | `last_synced` field exists but not validated for freshness |
| `ops/bindings/gate.execution.topology.yaml` | Gate topology metadata | `path_triggers` defined but not validated for file existence |

---

## Root-Cause Drift Patterns

### 1. Boundary Authority Fragmentation

**Current State:**
- `README.md` defines spine ownership (lines 14-19)
- `spine.boundary.baseline.yaml` defines authoritative surfaces (lines 13-21)
- `mailroom.runtime.contract.yaml` defines runtime path (line 9)
- **No gate enforces boundary consistency across these three sources**

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/README.md:14-19
  Spine owns:
  - governed entrypoints (`bin/`, `ops/`, `surfaces/`)
  - governance/contracts (`docs/core`, `docs/governance`, `docs/product`)
  - capability registry + verify runtime
  - receipts + mailroom contract surfaces

/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.boundary.baseline.yaml:13-21
  authoritative_surfaces:
    - bin/**
    - ops/**
    - surfaces/**
    - docs/core/**
    - docs/governance/**
    - docs/product/**
    - receipts/**
    - mailroom/**
```

**Drift Risk:** New surfaces can be added to one file without updating others.

---

### 2. Runtime Path Resolution Not Canonical

**Current State:**
- `mailroom.runtime.contract.yaml` defines `runtime_root: "/Users/ronnyworks/code/.runtime/spine-mailroom"` (line 9)
- `spine.boundary.baseline.yaml` hardcodes runtime paths in rules (lines 65-71)
- **Scripts may reference hardcoded paths instead of contract**

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.boundary.baseline.yaml:65-71
  runtime_only:
    - id: mailroom_test_artifacts
      globs:
        - mailroom/inbox/**/test-*.md
      destination: /Users/ronnyworks/code/.runtime/spine-mailroom/inbox/
```

**Drift Risk:** If `runtime_root` changes in contract, boundary baseline is out of sync.

---

### 3. Boundary Audit Ignores tracked_exceptions

**Current State:**
- `mailroom.runtime.contract.yaml` defines `tracked_exceptions` (lines 11-23)
- `surface-boundary-audit` scans `move_workbench`, `runtime_only`, `archive_then_delete` rules
- **Audit does NOT validate that tracked_exceptions files are actually committed**

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.runtime.contract.yaml:11-23
  tracked_exceptions:
    - mailroom/.keep
    - mailroom/README.md
    - mailroom/inbox/.keep
    - ...

/Users/ronnyworks/code/agentic-spine/ops/plugins/surface/bin/surface-boundary-audit:58-60
  scan_group "move_workbench"
  scan_group "runtime_only"
  scan_group "archive_then_delete"
  # NO scan of tracked_exceptions
```

**Drift Risk:** `tracked_exceptions` list can become stale without detection.

---

### 4. Catalog Freshness Not Enforced

**Current State:**
- `capability.domain.catalog.yaml` has `last_synced` field per domain (lines 31, 44, 54, etc.)
- `binding.freshness.exemptions.yaml` exempts catalog from freshness checks
- **No gate validates catalog stays in sync with capability registry**

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/ops/bindings/capability.domain.catalog.yaml:10-24
  schema:
    required_fields:
      - domain_id
      - prefixes
      - owner_repo
      - owner_path
      - capabilities
      - last_synced
```

**Drift Risk:** New capabilities added to `ops/capabilities.yaml` may not appear in domain catalog.

---

### 5. Mutation Atomicity Inconsistent

**Current State:**
- `git-lock.sh` exists and works (verified in audit)
- Only used by: `gaps-file`, `gaps-close`, `start.sh`, `close.sh`, `pr.sh`
- **Not used by: orchestration plugins, infra plugins, proposals plugins**

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/ops/lib/git-lock.sh:12-48
  acquire_git_lock() - creates lock directory with PID file
  release_git_lock() - removes lock directory

From SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216/summary_counts.txt:
  yq e -i mutating writes: 57 occurrences
  git-lock serialization: 23 occurrences
  Mutation scripts without git-lock: 11
```

**Drift Risk:** Multi-agent sessions can race on binding mutations.

---

### 6. CLI Shape Not Standardized

**Current State:**
- `spine.schema.conventions.yaml` defines `preferred_argument_style: named_flags` (line 98)
- No gate enforces this preference
- ~40% of CLI commands use positional args as primary

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/ops/bindings/spine.schema.conventions.yaml:97-99
  cli_conventions:
    preferred_argument_style: named_flags
    rule: "Mutating operational surfaces should accept explicit --id style args..."

From SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216/summary_counts.txt:
  Named flags: ~60
  Positional args: ~40
  Mixed style: ~74
```

**Drift Risk:** New commands may use positional style without named alias.

---

### 7. Output Vocabulary Fragmented

**Current State:**
- No standard output prefix vocabulary
- Multiple patterns: `FAIL`, `D## FAIL`, `echo "FAIL:"`, `err()` function
- Case inconsistency: `ERROR` vs `Error`

**Evidence:**
```
From SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216/error_prefixes.txt:
  PASS outputs: 307
  FAIL outputs: 737
  ERROR outputs: ~80
  WARN outputs: ~150
  STOP outputs: ~25

Examples:
  surfaces/verify/d115-ha-ssot-baseline-freshness.sh:7-8
    ERRORS=0
    err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
    
  surfaces/verify/d93-tenant-storage-boundary-lock.sh:10
    err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
```

**Drift Risk:** Log parsing, monitoring tools cannot rely on consistent patterns.

---

### 8. Topology Quality Not Validated

**Current State:**
- `gate.execution.topology.yaml` defines `path_triggers` per domain (lines 25, 33, 41, etc.)
- `domain_metadata` includes `capability_prefixes` and `depends_on`
- **No gate validates that path_triggers files exist or prefixes match capabilities**

**Evidence:**
```
/Users/ronnyworks/code/agentic-spine/ops/bindings/gate.execution.topology.yaml:19-35
  domain_metadata:
    - domain_id: core
      capability_prefixes: ["spine.", "verify.", "stability.", "docs."]
      path_triggers: ["surfaces/verify/", "docs/governance/", "ops/capabilities.yaml"]
    - domain_id: aof
      capability_prefixes: ["aof.", "tenant.", "policy.", "surface."]
      path_triggers: ["ops/bindings/fabric.boundary.contract.yaml", ...]
```

**Drift Risk:** Stale path_triggers reference deleted files; missing triggers miss domain changes.

---

## Standards Required

Based on the drift patterns above, the following standards are required:

| ID | Standard | Root-Cause Addressed |
|----|----------|---------------------|
| STD-001 | Boundary Authority | Fragmentation across README, baseline, contract |
| STD-002 | Runtime Path Resolution | Hardcoded paths vs contract reference |
| STD-003 | Boundary Audit Strictness | tracked_exceptions not validated |
| STD-004 | Catalog Freshness | last_synced not enforced |
| STD-005 | Mutation Atomicity | git-lock not universal |
| STD-006 | CLI Shape | named_flags not enforced |
| STD-007 | Output Vocabulary | Prefix fragmentation |
| STD-008 | Topology Quality | path_triggers/prefixes not validated |

---

## Reference: D74 Pattern (Exemplary)

The `d74-billing-provider-lane-lock.sh` provides a strong pattern for standard enforcement:

```bash
# Pattern 1: Validate defaults
rg -q 'provider="\$\{SPINE_ENGINE_PROVIDER:-zai\}"' "$ENGINE_RUN" \
  || fail "ops/engine/run.sh must default SPINE_ENGINE_PROVIDER to zai"

# Pattern 2: Block silent fallbacks
if rg -q 'OpenAI provider failed; falling back to Anthropic' "$ENGINE_RUN"; then
  fail "ops/engine/run.sh must not silently fallback openai->anthropic"
fi

# Pattern 3: Validate explicit flag exists
rg -q 'WATCHER_ALLOW_ANTHROPIC="\$\{SPINE_WATCHER_ALLOW_ANTHROPIC:-0\}"' "$WATCHER" \
  || fail "watcher must define SPINE_WATCHER_ALLOW_ANTHROPIC default 0"

# Pattern 4: Block implicit fallbacks
if rg -q 'security find-generic-password -a "\$USER" -s "anthropic-api-key" -w' "$WATCHER"; then
  fail "watcher must not use implicit keychain fallback for ANTHROPIC_API_KEY"
fi
```

This pattern should be replicated for each standard.

---

## Non-Goals for This Sprint

1. **Field alias migration** — Addressed by separate conventions backlog (Phase 2B)
2. **Status enum alignment** — Addressed by separate conventions backlog (Phase 2C)
3. **New gate creation** — Standards define acceptance criteria, not implementation
4. **Breaking CLI changes** — Named flags added as aliases, positional retained
5. **Multi-agent write protocol** — Out of scope for standards pack

---

## Dependencies

- `SPINE_CONVENTIONS_CANONICAL_AUDIT_20260216.md` — Field alias drift evidence
- `SPINE_CONVENTIONS_PHASE2B_BACKLOG_20260216.md` — Migration sequencing

---

*Input analysis complete: 2026-02-16*
