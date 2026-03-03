---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-03
scope: cli-flag-convention
---

# CLI Flag Convention

> Canonical reference for flag naming, binding semantics, and compatibility alias
> policy across all spine lifecycle capabilities.

## 1. General Flag Rules

| Rule | Convention |
|------|-----------|
| Flag prefix | Always `--` (no single-dash short flags) |
| Word separator | Hyphen (`--loop-id`, not `--loopId` or `--loop_id`) |
| Value passing | Space-separated (`--flag value`) and `=` form (`--flag=value`) both accepted |
| Boolean flags | Bare flag for true (`--no-commit`, `--json`, `--strict`) |
| Double-dash separator | Every script must include `--) shift ;;` in its case block |
| Help flag | `-h` and `--help` both supported |

## 2. Canonical Binding Flags

These flags carry loop/gap/plan identity across lifecycle boundaries.
All new capabilities must use the canonical form. Compatibility aliases
are accepted with a deprecation warning on stderr.

| Canonical Flag | Purpose | Compatibility Aliases | Used By |
|----------------|---------|----------------------|---------|
| `--loop-id` | Bind to parent loop | `--parent-loop`, `--loop` | gaps.file, gaps.quick, proposals.submit, planning.plans.create |
| `--plan-id` | Identify a plan | (none) | planning.plans.{promote,retire,cancel} |
| `--id` | Identify a gap | (none) | gaps.file, gaps.close, gaps.claim |
| `--name` | Name a new loop | (none) | loops.create |

### Alias Behavior

When a compatibility alias is used, the capability must:

1. Accept the alias silently (no error).
2. Emit a `WARN:` line to stderr noting the canonical form.
3. Process the value identically to the canonical flag.

Example warning:
```
WARN: --parent-loop is a compatibility alias; prefer canonical --loop-id.
```

## 3. Common Flag Vocabulary

These flags appear across multiple capabilities and must use consistent naming.

| Flag | Type | Meaning |
|------|------|---------|
| `--description` | string | Human-readable text body |
| `--description-file` | path | File containing description (avoids shell quoting) |
| `--type` | enum | Gap/entity type |
| `--severity` | enum | Gap severity (`low`, `medium`, `high`, `critical`) |
| `--status` | enum | Filter or set status |
| `--reason` | string | Justification for lifecycle transition |
| `--json` | boolean | Emit machine-readable JSON output |
| `--no-commit` | boolean | Stage changes without committing |
| `--commit` | boolean | Override no-commit default |
| `--doc` | path | Associated document path |
| `--wait-seconds` | integer | Lock acquisition timeout |
| `--horizon` | enum | Planning horizon (`now`, `later`, `future`) |
| `--readiness` | enum | Execution readiness (`runnable`, `blocked`) |
| `--execution-mode` | enum | Execution topology (`single_worker`, `orchestrator_subagents`) |
| `--owner` | string | Owner identifier (e.g., `@ronny`) |
| `--review-date` | date | Review date in `YYYY-MM-DD` format |

## 4. Flag Ordering Convention

Recommended ordering in help text and documentation:

1. Identity flags (`--id`, `--name`, `--plan-id`)
2. Required content flags (`--description`, `--type`, `--severity`)
3. Binding flags (`--loop-id`, `--doc`)
4. Optional modifier flags (`--horizon`, `--readiness`, `--reason`)
5. Output/mode flags (`--json`, `--no-commit`, `--commit`)
6. Operational flags (`--wait-seconds`, `--batch`)

## 5. Env Var Fallback Convention

Some flags have environment variable fallbacks for ergonomic shell sessions:

| Flag | Env Var Fallback | Precedence |
|------|-----------------|------------|
| `--loop-id` | `SPINE_LOOP_ID` | Flag wins over env |
| `--no-commit` | `GAPS_FILE_NO_COMMIT_DEFAULT=1` | Flag wins over env |
| (terminal role) | `OPS_TERMINAL_ROLE` / `SPINE_TERMINAL_ROLE` | Resolution chain in `terminal.role.contract.yaml` |

## 6. Anti-Patterns

| Anti-Pattern | Why | Correct Pattern |
|--------------|-----|-----------------|
| Positional args for IDs | Fragile, breaks with `--` separator | Use `--id VALUE` |
| Single-char flags | Ambiguous, hard to grep | Use full `--flag-name` |
| Mixed `_` and `-` | Inconsistent parsing | Always use `-` in flags |
| Flag without `=` form | Breaks script composition | Accept both `--flag value` and `--flag=value` |
| Quoting `$cmd` in cap.sh | Breaks subcommand args | Never quote `$cmd` |

## 7. Migration Status

| Capability | Canonical `--loop-id` | Alias Warning | Status |
|------------|----------------------|---------------|--------|
| gaps.file | Yes | Yes | Complete |
| gaps.quick | Yes | Yes | Complete |
| proposals.submit | Yes | Yes | Complete |
| planning.plans.create | Yes | N/A (was `--source-loop-id`) | Complete |
| loops.create | N/A (uses `--name`) | N/A | Complete |
| gaps.close | N/A | N/A | No loop binding |
| planning.plans.retire | N/A | N/A | No loop binding |
| planning.plans.cancel | N/A | N/A | No loop binding |
