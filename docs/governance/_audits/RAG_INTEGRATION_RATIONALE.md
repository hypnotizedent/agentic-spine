# RAG Integration Rationale for Hot-Folder Watcher

> **⚠️ Historical Capture (2026-01-26)**
>
> This document is a point-in-time audit snapshot. Paths reference the legacy
> `ronny-ops` repository layout (`scripts/agents/hot-folder-watcher.sh`).
>
> **Do not execute commands or act on paths in this document.**
>
> **Current authority:** See [SESSION_PROTOCOL.md](../SESSION_PROTOCOL.md) and
> [GOVERNANCE_INDEX.md](../GOVERNANCE_INDEX.md) for live governance.

> **Audit Date:** 2026-01-26
> **Auditor:** Terminal Operator (Parallel Track)
> **Subject:** scripts/agents/hot-folder-watcher.sh
> **Status: historical** — Read-only reference; no code changes made

---

## Executive Summary

**Key Finding:** RAG-lite is already implemented in the watcher (lines 236-291). The current implementation is deterministic, bounded, and traceable. Full RAG (vector-based retrieval) is NOT a simple drop-in and would introduce significant risk without substantial infrastructure investment.

**Recommendation:** Keep current Tier 1 RAG-lite. Do not escalate to Tier 2+ until traceability infrastructure stabilizes.

---

## 1. What is "RAG" in Our Specific System?

### Current Behavior (Baseline)

The hot-folder-watcher currently injects:

| Source | Lines | Purpose |
|--------|-------|---------|
| `.brain/rules.md` | 182-187 | 5 operating rules, RAG query reminder |
| Governance reference | 177-179 | Pointer to governance checklist (SUPERVISOR_CHECKLIST.md superseded) |
| User prompt | 328-329 | Raw content from inbox file |
| **RAG-lite context** | 320-325 | **Opt-in retrieval if `RAG:ON` + `QUERY:` present** |

**Evidence:** `scripts/agents/hot-folder-watcher.sh:296-332` (build_packet function)

### Discovery: RAG-Lite Already Exists

The watcher already implements deterministic retrieval at lines 236-291:

```bash
retrieve_context() {
    # Only retrieve if RAG:ON is present
    if ! grep -q "RAG:ON" "$prompt_file" 2>/dev/null; then
        return
    fi

    # Extract QUERY: line
    local query
    query="$(grep -oP '^QUERY:\s*\K.*' "$prompt_file" 2>/dev/null | head -1)"

    # Search in bounded scope (docs, modules only)
    local search_dirs=("$REPO/docs")
    [[ -d "$REPO/modules" ]] && search_dirs+=("$REPO/modules")

    # Max 3 files, 200 lines total
    matches="$(rg -l -i "$query" "${search_dirs[@]}" --type md 2>/dev/null | head -3)"
}
```

**Current Contract:**
- **Trigger:** `RAG:ON` in prompt + `QUERY:` line
- **Scope:** `docs/` and `modules/` only
- **Max files:** 3
- **Max lines per file:** 50 (hardcoded)
- **Total budget:** ~200 lines
- **Traceability:** `context_used` field in ledger, header in outbox

---

## 2. RAG Tiers (Increasing Complexity)

### Tier 0: None (Pre-Implementation)
- **What:** No retrieval; static context only
- **Components:** None
- **Data searched:** None
- **Traceability:** N/A
- **Failure modes:** None

### Tier 1: Deterministic Retrieval (CURRENT)
- **What:** `rg` search over bounded folders with explicit query
- **Components:** ripgrep, shell script
- **Data searched:** `docs/`, `modules/` (markdown only)
- **Traceability:** `context_used` field in ledger, files listed in packet header
- **Failure modes:**
  - Query returns zero matches (graceful: proceeds without context)
  - Query too broad (limited by `head -3`)
  - Sensitive file inadvertently matched (partially mitigated by scope)

### Tier 2: Index-Based Retrieval (NOT IMPLEMENTED)
- **What:** Embeddings/vector store (AnythingLLM, Qdrant)
- **Components:** Vector DB, embedding model, semantic search API, manifest governance
- **Data searched:** Documents matching `WORKSPACE_MANIFEST.json` patterns
- **Traceability:** Requires citation extraction, source provenance tracking
- **Failure modes:**
  - Stale index returns outdated content
  - Pollution cycles (bad doc indexed → bad answers → bad doc written → indexed)
  - Token explosion (semantic search may return verbose chunks)
  - Hallucinated citations (model claims doc says X when it doesn't)
  - Index desync (code changes, index lags)

### Tier 3: Agentic Retrieval (NOT IMPLEMENTED)
- **What:** Multi-step retrieval with planning, re-ranking, citations
- **Components:** RAG orchestrator, retrieval agent, citation formatter, access controls
- **Data searched:** Dynamic; could span entire repo
- **Traceability:** Full chain-of-retrieval audit log required
- **Failure modes:** All Tier 2 failures plus:
  - Planning loops (agent decides to search indefinitely)
  - Citation drift (cites outdated version of file)
  - Secrets exposure (retrieves .env or credentials)
  - Cost explosion (multiple LLM calls per query)

---

## 3. Why Full RAG is NOT a Simple Drop-In

### 3.1 Scope Explosion: What Constitutes "Searchable Canon"?

The repo contains **434 markdown/shell files** (at depth 3) but governance defines clear boundaries:

**Evidence:**
```bash
$ find . -maxdepth 3 -type f \( -name "*.md" -o -name "*.sh" \) | wc -l
434
```

The `WORKSPACE_MANIFEST.json` defines **criticalPatterns** including:
- 5 directory patterns
- 9 specific files
- 8 name patterns
- 11 explicit exclusions

**Problem:** No manifest currently governs what the *watcher* can search. The watcher scope (`docs/`, `modules/`) is hardcoded, not manifest-driven.

### 3.2 Risk of Leaking Secrets/Private Data

The repo contains **28 `.env` files** including:
- `infrastructure/mcpjungle/servers/*/.env` (MCP credentials)
- `mint-os/apps/*/.env` (API keys)
- `infrastructure/secrets/.env.n8n`

**Evidence:**
```
/Users/ronnyworks/ronny-ops/mint-os/apps/web/.env
/Users/ronnyworks/ronny-ops/infrastructure/mcpjungle/servers/media-stack/.env
/Users/ronnyworks/ronny-ops/infrastructure/secrets/.env.n8n
... (28 total)
```

**Current Mitigation:**
- The watcher has `contains_secrets()` function (lines 139-148) that quarantines files with secret patterns
- Searches `docs/` and `modules/` only (not `infrastructure/dotfiles/`, not `receipts/`)

**Gap:** If scope expanded to `infrastructure/`, secrets in MCP configs could be included.

### 3.3 Nondeterminism + Hallucinated Citations

Vector-based RAG returns different chunks based on:
- Embedding model version
- Index state at query time
- Chunk size/overlap settings

**Evidence from governance:**
```markdown
# RAG_INDEXING_RULES.md, lines 70-85
Agent logs wrong info (port 3001)
        ↓
Gets indexed to RAG
        ↓
Next agent queries RAG
        ↓
Gets wrong info (port 3001)
        ↓
POLLUTION CYCLE
```

The existing RAG system (`mint ask`) has extensive governance precisely because of this risk.

### 3.4 Token/Cost Explosion

**Evidence - Directory Sizes:**
```
756K    docs/
88M     modules/
748K    receipts/
```

If retrieval were naive (no limits), a single prompt could inject megabytes of context.

**Current Mitigation:** Hard limits: 3 files, 50 lines/file

### 3.5 No Existing Index/Manifest for Watcher

The watcher uses `rg` directly. It does NOT use:
- `mint ask` (the existing RAG CLI)
- `WORKSPACE_MANIFEST.json`
- AnythingLLM API

**Why this matters:** The watcher operates independently of the established RAG infrastructure. Adding "full RAG" would mean either:
1. Duplicating the RAG stack (two sources of truth), or
2. Calling out to `mint ask` (introducing network/container dependency)

### 3.6 Missing Citation Format Contract

Outbox results include a `Context` field but no structured citation format:

```bash
# From hot-folder-watcher.sh:434
echo "| Context | ${context_used} |"
```

For Tier 2+ RAG, we'd need:
- File path + line ranges (or heading anchors)
- Document version/hash
- Retrieval confidence score

---

## 4. Requirements Before RAG is Safe

### 4.1 Bounded Retrieval Scope (DONE)

Current implementation searches only `docs/` and `modules/`. This is correct.

**Gap:** Scope is hardcoded, not configurable via manifest.

### 4.2 Canonical Allowlist (PARTIAL)

`WORKSPACE_MANIFEST.json` exists but is not read by the watcher.

**Requirement:** If expanding RAG, the watcher should read `WORKSPACE_MANIFEST.json` to determine scope.

### 4.3 Redaction/Denylist Patterns (DONE)

The `contains_secrets()` function provides basic protection.

**Gap:** Only checks prompts, not retrieved content. If a doc *contains* an API key example, it could be injected.

### 4.4 Citation Format (NOT IMPLEMENTED)

For traceable RAG, outbox needs:
```markdown
## Retrieved Context
- `docs/governance/ISSUE_CLOSURE_SOP.md` (lines 10-45)
- `modules/files-api/SPEC.md` (lines 1-30)
```

### 4.5 Hard Token Budget (DONE)

Current: 3 files, 50 lines each = ~200 lines max.

### 4.6 Retrieval Logging (DONE)

The `context_used` ledger field tracks whether retrieval occurred:
- `none` - no retrieval
- `rag-lite` - deterministic retrieval

### 4.7 Failure Behavior (DONE)

If query matches nothing, retrieval returns empty and packet proceeds normally.

---

## 5. Recommendation

### Decision: Keep Tier 1 RAG-Lite; Do NOT Escalate

The current implementation is correct for the watcher's purpose:

| Requirement | Status |
|-------------|--------|
| Bounded scope | Done (hardcoded to docs/, modules/) |
| Explicit trigger | Done (RAG:ON + QUERY:) |
| Max file limit | Done (3 files) |
| Max line limit | Done (~200 lines) |
| Ledger tracking | Done (context_used field) |
| Secrets quarantine | Done (contains_secrets) |

### What We CAN Safely Do Now (No Changes Needed)

The current implementation already provides:
1. **Opt-in only:** Prompts must explicitly request RAG via `RAG:ON`
2. **Explicit query:** Must provide `QUERY:` line
3. **Bounded search:** Only `docs/` and `modules/`
4. **Limited results:** Max 3 files, 200 lines
5. **Traceability:** Logged in ledger, noted in outbox header

### What We Should Defer

| Feature | Why Defer |
|---------|-----------|
| Vector-based retrieval | Requires index sync governance, citation format, pollution prevention |
| Manifest-driven scope | Watcher should stabilize before coupling to manifest |
| Multi-hop retrieval | Scope explosion risk without agentic boundaries |
| Semantic search | AnythingLLM already exists; don't duplicate |

### Next Gate Before Full RAG

Before escalating to Tier 2:
1. Traceability infrastructure must stabilize (run_id, lanes, ledger - in progress)
2. Citation format contract must be defined
3. Watcher must be tested with 100+ real prompts
4. Governance must document watcher-specific allowlist

---

## 6. One-Page Summary

### Why We Can't Just Add RAG

1. **28 `.env` files** in repo - naive search could expose secrets
2. **434 markdown/shell files** - no watcher-specific manifest defines scope
3. **Existing RAG (`mint ask`)** has extensive governance; watcher bypasses it
4. **Pollution cycle risk** - bad docs get indexed, return bad answers, create worse docs
5. **No citation format** - outbox can't currently trace which docs were retrieved
6. **Nondeterminism** - vector search returns different results over time

### What We Can Safely Do Instead

**Keep the current Tier 1 RAG-lite (already implemented):**
- Deterministic `rg` search
- Explicit opt-in (`RAG:ON` + `QUERY:`)
- Bounded scope (`docs/`, `modules/` only)
- Hard limits (3 files, 200 lines)
- Logged in ledger (`context_used: rag-lite`)

### Next Gate Before Full RAG

| Gate | Status |
|------|--------|
| Traceability stabilized (run_id, lanes, ledger) | In progress |
| Citation format defined | Not started |
| 100+ real prompt tests | Not started |
| Watcher allowlist documented | Not started |

---

## Evidence References

| Evidence | Path/Command |
|----------|--------------|
| Watcher script | `scripts/agents/hot-folder-watcher.sh` |
| RAG-lite impl | Lines 236-291 |
| Secret detection | Lines 139-148 |
| Ledger tracking | Lines 176-202 |
| `.env` files | 28 files via `Glob **/*.env*` |
| Directory sizes | `docs/` 756K, `modules/` 88M, `receipts/` 748K |
| File count | 434 md/sh files at depth 3 |
| Governance | `docs/governance/RAG_INDEXING_RULES.md` |
| Exclusions | `docs/governance/SEARCH_EXCLUSIONS.md` |
| Manifest | Workbench RAG manifest (external; see WORKBENCH_TOOLING_INDEX.md) |
| SSOT Registry | `docs/governance/SSOT_REGISTRY.yaml` (50+ entries) |

---

*End of audit. No code changes made.*
