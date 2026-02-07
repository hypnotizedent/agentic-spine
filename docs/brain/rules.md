# The Rules

> **Status:** authoritative
> **Last verified:** 2026-02-04

```
1. NO OPEN LOOPS = NO WORK  → ./bin/ops loops list --open
2. NO GUESSING = RAG FIRST  → mint ask "question"
3. NO INVENTING             → match existing patterns
4. FIX ONE THING            → verify before next
5. WORK GENERATES RECEIPTS  → ./bin/ops cap run <name>
```

## Commands

```bash
./bin/ops loops list --open  # See open work
./bin/ops cap run <name>     # Run governed capability
mint ask "question"          # Query RAG
mint health                  # Check RAG status
cat ops/bindings/cli.tools.inventory.yaml  # What CLI tools are installed
```

## Approval Required

Code changes, git commits, database writes, deploys, docker restarts.

## Entry Points

| Working on | Read first |
|------------|------------|
| Data/files | docs/governance/INFRASTRUCTURE_MAP.md |
| Code | docs/governance/AGENTS_GOVERNANCE.md |
| Services | docs/governance/SERVICE_REGISTRY.yaml |
| CLI tools | ops/bindings/cli.tools.inventory.yaml |
