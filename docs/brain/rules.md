# The Rules

> **Status:** reference
> **Last verified:** 2026-02-15

```
1. NO OPEN LOOPS = NO WORK  → ./bin/ops loops list --open
2. NO GUESSING = CAPABILITY-FIRST RAG  → run rag.anythingllm.ask, MCP optional, then rg fallback
3. NO INVENTING             → match existing patterns
4. FIX ONE THING            → verify before next
5. WORK GENERATES RECEIPTS  → ./bin/ops cap run <name>
```

## Commands

```bash
./bin/ops loops list --open  # See open work
./bin/ops cap list           # Discover available capabilities
./bin/ops cap run <name>     # Run governed capability
./bin/ops cap show <name>    # Show capability details
cat ops/bindings/cli.tools.inventory.yaml  # What CLI tools are installed
```

Capability SSOT: `ops/capabilities.yaml`.

## RAG Usage

**Discovery path:** When you need to find how something works in the spine:

1. **Capability-first query** via `./bin/ops cap run rag.anythingllm.ask "<query>"`
2. **Optional MCP acceleration** via `spine-rag` (`rag_query`) when available
3. **Fallback to rg** if capability/MCP discovery is unavailable or you know exact file

Good RAG queries:
- "How do I file a gap?"
- "What drift gates check VM parity?"
- "What is the commit message format?"
- "How does the proposal flow work?"

Anti-patterns:
- Do NOT query RAG for real-time state (use capabilities instead)
- Do NOT use RAG when you know which file has the answer (read it directly)

## Approval Required

Code changes, git commits, database writes, deploys, docker restarts.

## Entry Points

| Working on | Read first |
|------------|------------|
| **Discovery/How-to** | **Capability-first RAG** (`./bin/ops cap run rag.anythingllm.ask`) |
| Data/files | docs/governance/INFRASTRUCTURE_MAP.md |
| Code | docs/governance/AGENTS_GOVERNANCE.md |
| Services | docs/governance/SERVICE_REGISTRY.yaml |
| Remote paths | ops/bindings/docker.compose.targets.yaml, ops/bindings/ssh.targets.yaml |
| Issues discovered mid-work (SSOT/script drift) | ops/bindings/operational.gaps.yaml |
| CLI tools | ops/bindings/cli.tools.inventory.yaml |
| VM provisioning / bootstrap | docs/legacy/brain-lessons/VM_INFRA_LESSONS.md |
| Media stack / NFS | docs/legacy/brain-lessons/MEDIA_STACK_LESSONS.md |
