# The Rules

> **Status:** authoritative
> **Last verified:** 2026-02-04

```
1. NO ISSUE = NO WORK       → gh issue list --state open
2. NO GUESSING = RAG FIRST  → mint ask "question"
3. NO INVENTING             → match existing patterns
4. FIX ONE THING            → verify before next
5. UPDATE MEMORY            → Ctrl+9 when done
```

## Commands

```bash
mint ask "question"         # Query RAG
mint health                 # Check RAG status
gh issue list               # See open issues
gh issue close N            # Close issue
```

## Approval Required

Code changes, git commits, database writes, deploys, docker restarts.

## Entry Points

| Working on | Read first |
|------------|------------|
| Data/files | docs/governance/INFRASTRUCTURE_MAP.md |
| Code | docs/governance/AGENTS_GOVERNANCE.md |
| Services | docs/governance/SERVICE_REGISTRY.yaml |
