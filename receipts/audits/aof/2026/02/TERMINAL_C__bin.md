---
status: audit-report
owner: "@ronny"
date: 2026-02-16
scope: aof-alignment-audit
target: bin/
---

# AOF Alignment Audit: `/Users/ronnyworks/code/agentic-spine/bin`

> **Audit Type:** AOF Alignment (Spine Runtime vs Workbench Tooling)
> **Auditor:** Sisyphus Agent (TERMINAL_C)
> **Date:** 2026-02-16T16:39:00-05:00

---

## Executive Summary

The `bin/` folder contains **6 items** (3 scripts, 1 documentation file, 2 subdirectories). Analysis against AOF alignment criteria shows:

| Category | Count | Assessment |
|----------|-------|------------|
| KEEP_SPINE | 4 | Core runtime entrypoints |
| RUNTIME_ONLY | 2 | Developer/scaffolding tools |
| MOVE_WORKBENCH | 0 | None identified |
| UNKNOWN | 0 | None identified |

**Overall Assessment:** The `bin/` folder is well-aligned with AOF principles. All items are appropriate for spine runtime with minor considerations for `generate-scaffold.sh` and deprecated `cli/` shim.

---

## AOF Alignment Criteria Reference

Per governance documentation (HOST_DRIFT_POLICY.md, SESSION_PROTOCOL.md, WORKBENCH_TOOLING_INDEX.md):

| Surface | Purpose | Writes | Example |
|---------|---------|--------|---------|
| **Spine (agentic-spine)** | Canonical governance + runtime | Writable | All governed operations execute here |
| **Workbench (~/code/workbench)** | Tooling + infrastructure docs | Writable | Compose stacks, scripts, MCP configs |

**Key Principles:**
1. Spine must be self-contained at runtime (LEGACY_DEPRECATION.md)
2. No external runtime dependencies
3. `bin/` should contain entrypoints, not development tooling
4. Workbench is tooling-only, not runtime authority

---

## Detailed Analysis

### KEEP_SPINE (4 items)

Core runtime components that MUST remain in spine:

| Path | Type | Purpose | Justification |
|------|------|---------|---------------|
| `/Users/ronnyworks/code/agentic-spine/bin/ops` | script | Main governance dispatcher | **Core entrypoint** - Single source of truth for all governance operations. Referenced by CORE_LOCK.md, AGENTS.md, all governance docs. MD5: `7135cc10df6d7d2991ca69f1ab2ec757` |
| `/Users/ronnyworks/code/agentic-spine/bin/ops-verify` | script | Shortcut for `ops verify` | **Runtime convenience** - Wrapper that exports `OPS_SKIP_IMMICH=1` and delegates to `ops verify`. 6 lines, essential for day-to-day verification. MD5: `f9324c36bca9dd778f2da8a524021df0` |
| `/Users/ronnyworks/code/agentic-spine/bin/commands/agent.sh` | script | Agent session management | **Core runtime** - Dispatches agent workflow commands (enqueue, latest, park, status, summary, watchdog, launch, close). 42 lines, integrates with `ops/runtime/inbox/`. |
| `/Users/ronnyworks/code/agentic-spine/bin/cli/README.md` | doc | Documents deprecated CLI | **Governance documentation** - Clarifies that `bin/cli/bin/spine` is deprecated and `bin/ops` is canonical. 12 lines. |

### RUNTIME_ONLY (2 items)

Developer/scaffolding tools that are acceptable in spine but are NOT core runtime:

| Path | Type | Purpose | Assessment |
|------|------|---------|------------|
| `/Users/ronnyworks/code/agentic-spine/bin/generate-scaffold.sh` | script | Auto-generates SPINE_SCAFFOLD.md from live contracts | **Scaffolding tool** - 368 lines. Generates context bundle for AI agents. Could move to `ops/tools/` but acceptable here as it produces spine-native output. MD5: `9ef577d60ffee8760ffe3d3607ccda5e` |
| `/Users/ronnyworks/code/agentic-spine/bin/cli/bin/spine` | script | Deprecated CLI shim | **Deprecation shim** - 15 lines. Prints deprecation notice and exits 64. Acts as migration aid, not authoritative. Can be removed once deprecated path is fully sunset. |

### MOVE_WORKBENCH (0 items)

No items identified for move to workbench.

### UNKNOWN (0 items)

No items with unclear alignment.

---

## High-Risk Mismatches (Top 10)

**Risk Level: LOW** - No high-risk mismatches identified.

| Rank | Path | Risk | Reason |
|------|------|------|--------|
| 1 | `bin/generate-scaffold.sh` | Low | Could live in `ops/tools/` but produces spine output |
| 2 | `bin/cli/bin/spine` | Low | Deprecation shim, consider removal timeline |

---

## Counts Summary

| Metric | Value |
|--------|-------|
| Total items | 6 |
| Scripts | 4 |
| Documentation | 1 |
| Subdirectories | 2 |
| KEEP_SPINE | 4 |
| RUNTIME_ONLY | 2 |
| MOVE_WORKBENCH | 0 |
| UNKNOWN | 0 |
| High-risk mismatches | 0 |

---

## Recommendations

1. **No immediate action required** - The `bin/` folder is well-aligned with AOF principles.

2. **Optional cleanup** - Consider:
   - Moving `generate-scaffold.sh` to `ops/tools/` for consistency with other scaffolding utilities
   - Adding deprecation timeline to `bin/cli/bin/spine` and `bin/cli/README.md`
   - Adding a symlink from `bin/generate-scaffold.sh` to `ops/tools/generate-scaffold.sh` if moved

3. **Documentation** - The `bin/cli/` subdirectory structure (README + deprecated spine script) is a good pattern for deprecation shims. Consider documenting this pattern in REPO_STRUCTURE_AUTHORITY.md.

---

## Evidence

- Read: `bin/ops`, `bin/ops-verify`, `bin/generate-scaffold.sh`, `bin/commands/agent.sh`, `bin/cli/bin/spine`, `bin/cli/README.md`
- Referenced: `docs/governance/HOST_DRIFT_POLICY.md`, `docs/governance/SESSION_PROTOCOL.md`, `docs/governance/WORKBENCH_TOOLING_INDEX.md`, `docs/governance/SCRIPTS_AUTHORITY.md`, `docs/governance/REPO_STRUCTURE_AUTHORITY.md`, `docs/core/CORE_LOCK.md`
- MD5 checksums computed for all executable scripts

---

## Sign-off

| Field | Value |
|-------|-------|
| Audit completed | 2026-02-16T16:39:00-05:00 |
| Terminal | TERMINAL_C |
| Agent | Sisyphus |
| Target folder | `/Users/ronnyworks/code/agentic-spine/bin` |
| Overall status | **PASS** - AOF aligned |
