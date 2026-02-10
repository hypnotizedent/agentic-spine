---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: search-indexing
github_issue: "#541"
---

# Search Exclusions

> **Purpose:** Define what directories and file patterns are excluded from
> search indexes and RAG ingestion in the agentic-spine repository.

---

## Excluded Directories

| Path | Reason |
|------|--------|
| `docs/legacy/` | Quarantined legacy imports (D16/D17 drift gates enforce isolation) |
| `receipts/sessions/` | High-volume session receipts; searchable via `ops` commands |
| `mailroom/state/` | Runtime state (ledger, loops); not documentation |
| `fixtures/` | Test fixtures; synthetic data only |
| `.worktrees/` | Worktree clones (high-volume duplicate trees; drift magnet) |
| `.git/` | Git internals |
| `node_modules/` | Third-party dependencies |

---

## Excluded File Patterns

| Pattern | Reason |
|---------|--------|
| `*.jsonl` | Append-only logs (open_loops.jsonl, ledger data) |
| `*.csv` | Ledger files; machine-readable, not prose |
| `output.txt` | Receipt output captures |

---

## Where Exclusions Are Enforced

| System | Mechanism |
|--------|-----------|
| `docs.lint` | Skips `docs/legacy/` for metadata checks |
| Drift gates D16/D17 | Enforce legacy isolation |
| `.gitignore` | Standard git exclusions |

---

## Adding New Exclusions

1. Add the pattern to this document.
2. If the exclusion affects drift gates, update `docs/core/CORE_LOCK.md`.
3. Run `./bin/ops cap run docs.lint` to verify no false positives.

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [RAG_INDEXING_RULES.md](RAG_INDEXING_RULES.md) | What gets indexed (complement of this doc) |
| [CORE_LOCK.md](../core/CORE_LOCK.md) | Drift gate definitions including D16/D17 |
