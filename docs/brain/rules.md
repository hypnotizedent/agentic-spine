# The Rules

> **Status:** reference
> **Last verified:** 2026-02-07

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
| Remote paths | ops/bindings/docker.compose.targets.yaml, ops/bindings/ssh.targets.yaml |
| Issues discovered mid-work (SSOT/script drift) | ops/bindings/operational.gaps.yaml |
| CLI tools | ops/bindings/cli.tools.inventory.yaml |
| VM provisioning / bootstrap | docs/brain/lessons/VM_INFRA_LESSONS.md |
| Media stack / NFS | docs/brain/lessons/MEDIA_STACK_LESSONS.md |
