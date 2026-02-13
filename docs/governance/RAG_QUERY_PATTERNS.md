---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: rag-agent-query-patterns
---

# RAG Query Patterns

> Governs how agents query the spine RAG system (AnythingLLM + Qdrant)
> and defines failure mode behavior.

## Architecture

```
Agent (Claude Code / Codex)
  |
  |-- MCP tool call: rag_query / rag_retrieve / rag_health
  |
  v
rag-mcp-server (ops/plugins/rag/bin/rag-mcp-server)
  |
  |-- secrets-exec (Infisical injection)
  |-- rag CLI (ops/plugins/rag/bin/rag)
  |
  v
AnythingLLM (:3002) --> Qdrant (:6333) + Ollama (:11434)
  on ai-consolidation (VM 207, 100.71.17.29)
```

## Query Methods

### 1. MCP Tool Call (Preferred)

Agents with MCP access can call `rag_query` directly as a tool. This is
the governed path registered in `.mcp.json`.

**When to use:** Agent needs governance knowledge, workflow guidance, or
operational procedure answers during a session.

**Example queries:**
- "How do I file a gap?"
- "What is the commit message format?"
- "What drift gates check VM parity?"
- "How does the proposal flow work?"

### 2. Capability Invocation (Operator)

Operators or agents without MCP access use the capability system:

```bash
./bin/ops cap run rag.anythingllm.ask "how do I file a gap?"
```

**When to use:** Manual operator queries, debugging, receipt generation.

### 3. Direct Retrieval (Advanced)

For raw document chunks without answer synthesis:

```bash
./bin/ops cap run rag.anythingllm.ask --retrieve-only "drift gate"
```

Or via MCP: `rag_retrieve` tool.

**When to use:** When the agent needs exact document text, not a
synthesized answer.

## Failure Mode Behavior

### RAG Unavailable

If the RAG system is unreachable (VM down, Tailscale flap, service crash):

1. **MCP tool call returns error text** — the agent sees "Error: rag ask
   failed (rc=N)" and should fall back to direct file search.
2. **Capability returns non-zero exit** — operator sees error in receipt.
3. **No silent degradation** — RAG failures are always visible.

**Agent fallback contract:** When RAG is unavailable, agents MUST NOT
guess answers. Instead, use `rg` (ripgrep) to search governance docs
directly. This is the Tier 1 RAG-lite path documented in
`docs/governance/_audits/RAG_INTEGRATION_RATIONALE.md`.

### Stale Index

If the AnythingLLM index is behind the repo (docs changed but not synced):

1. RAG answers may reference outdated information.
2. Agents should verify RAG answers against live files when precision matters.
3. Run `./bin/ops cap run rag.anythingllm.sync` (manual approval) to
   re-index after significant doc changes.

### Partial Availability

If Qdrant is up but Ollama is down (or vice versa):

1. `rag health` will show which component is degraded.
2. `rag ask` falls back from chat mode to pure retrieval if Ollama
   is unreachable (built into the RAG CLI).
3. Retrieval-only queries (`rag retrieve`) work as long as Qdrant is up.

## Indexed Content

The RAG system indexes governed spine docs matching these criteria
(defined in `docs/governance/RAG_INDEXING_RULES.md`):

- **Eligible directories:** `docs/`, `ops/`, `surfaces/`
- **Required frontmatter:** `status`, `owner`, `last_verified`
- **Excluded:** `docs/legacy/`, `receipts/`, `mailroom/state/`, fixtures
- **Current index:** ~90 eligible docs, ~102 total indexed

## Anti-Patterns

1. **Do NOT query RAG for real-time state.** RAG indexes documents, not
   live system state. For live state, use capabilities (`ssh.target.status`,
   `rag.health`, etc.).

2. **Do NOT use RAG as a substitute for reading files.** If you know
   which file has the answer, read it directly. RAG is for discovery
   ("where is this documented?") not retrieval of known files.

3. **Do NOT trust RAG answers for commit messages or gap IDs.** These
   change frequently and the index may be stale.

## References

- `ops/plugins/rag/bin/rag` — RAG CLI implementation
- `ops/plugins/rag/bin/rag-mcp-server` — MCP server adapter
- `.mcp.json` — Claude Code MCP registration
- `docs/governance/RAG_INDEXING_RULES.md` — indexing rules
- `docs/governance/_audits/RAG_INTEGRATION_RATIONALE.md` — tier analysis
