---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-04
scope: rag-quality
github_issue: "#541"
---

# RAG Indexing Rules

> **Purpose:** Quality gate for what gets indexed into the RAG knowledge base.
> Prevents pollution, ensures agents receive high-signal answers.

---

## Indexing Criteria

A document is eligible for RAG indexing if it meets **all** of the following:

1. **Lives in a governed directory** — `docs/`, `ops/`, or `surfaces/`.
2. **Has a metadata header** — `status`, `owner`, and `last_verified` fields.
3. **Is not archived** — Files under `docs/legacy/` or `.archive/` are excluded.
4. **Is not ephemeral** — Session logs, plan drafts, and scratch files are excluded.

---

## Exclusion Patterns

These paths are never indexed:

| Pattern | Reason |
|---------|--------|
| `docs/legacy/**` | Quarantined legacy imports |
| `receipts/**` | Session receipts (high volume, low reuse) |
| `mailroom/state/**` | Runtime state files |
| `fixtures/**` | Test fixtures |
| `node_modules/**` | Dependencies |
| `.git/**` | Git internals |

See also: [SEARCH_EXCLUSIONS.md](SEARCH_EXCLUSIONS.md) for the full exclusion list.

---

## Naming Conventions

Indexed docs should follow these naming rules:

- **UPPER_SNAKE_CASE** for governance docs (e.g., `SECRETS_POLICY.md`).
- **kebab-case** for operational scripts and configs.
- Avoid generic names like `notes.md`, `TODO.md`, or `draft.md`.

---

## Re-indexing

After adding or modifying docs:

```bash
# Verify docs pass lint (metadata headers, folder placement)
./bin/ops cap run docs.lint
```

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [SEARCH_EXCLUSIONS.md](SEARCH_EXCLUSIONS.md) | Full exclusion list |
| [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) | Governance entry point |
