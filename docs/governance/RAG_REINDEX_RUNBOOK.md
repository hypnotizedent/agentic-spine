---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: rag-reindex-runbook
---

# RAG Reindex Runbook

> Governed checklist for performing a full RAG reindex.
> Authority: `ops/bindings/rag.workspace.contract.yaml`, `docs/governance/RAG_INDEXING_RULES.md`

## Prerequisites

1. RAG infrastructure is healthy:
   ```
   ./bin/ops cap run rag.health
   ```
   All three services (AnythingLLM, Qdrant, Ollama) must report OK.

2. Workspace exists on AnythingLLM:
   ```
   ./bin/ops cap run rag.anythingllm.status
   ```
   Must show workspace name and doc count (not "workspace not found").

3. Spine is clean and verified:
   ```
   ./bin/ops cap run spine.verify
   ```

## Reindex Steps

### Step 0: Preferred Runtime (Server-Side Detached)

Use governed remote controls so reindex continues even if your laptop sleeps:

```
./bin/ops cap run rag.reindex.remote.start
./bin/ops cap run rag.reindex.remote.start --execute
./bin/ops cap run rag.reindex.remote.status
```

Stop only if needed:

```
./bin/ops cap run rag.reindex.remote.stop
./bin/ops cap run rag.reindex.remote.stop --execute
```

Remote execution is governed by:
- `ops/bindings/rag.remote.runner.yaml`
- `surfaces/verify/d88-rag-remote-reindex-governance-lock.sh`

### Step 1: Dry-Run Manifest

Run a dry-run to capture the eligible document list:

```
echo "yes" | ./bin/ops cap run rag.anythingllm.sync --dry-run
```

Review the manifest output. Verify:
- Eligible count matches expectations (~90 docs as of 2026-02-13)
- No non-canonical paths (no `_audits/`, `_archived/`, `legacy/`)
- No files with known secret material

### Step 2: Execute Sync

Run the full sync:

```
echo "yes" | ./bin/ops cap run rag.anythingllm.sync
```

If sync fails partway through, resume from checkpoint:

```
echo "yes" | ./bin/ops cap run rag.anythingllm.sync --resume
```

The checkpoint file at `mailroom/state/rag-sync/checkpoint.txt` tracks completed uploads.

### Step 3: Verify Parity

Check post-sync parity:

```
./bin/ops cap run rag.anythingllm.status
```

Acceptance: `parity: OK` (docs_indexed >= docs_eligible).

### Step 4: Smoke Test Queries

Run at least two smoke queries to verify index quality:

```
./bin/ops cap run rag.anythingllm.ask "What is the canonical session entry protocol file?"
./bin/ops cap run rag.anythingllm.ask "How do I file a gap?"
```

Verify:
- Answers reference correct governance docs
- Sources list includes relevant file paths
- No stale or archived docs in sources

### Step 5: Record Attestation

After successful reindex, record metrics:
- Workspace slug
- Eligible docs count
- Indexed docs count
- Failed uploads (should be 0)
- Smoke query results

## Failure Recovery

| Scenario | Action |
|----------|--------|
| Sync fails partway | Use `--resume` to continue from checkpoint |
| Workspace missing | Create via AnythingLLM UI or API (see error hint) |
| Parity drift after sync | Re-run sync (idempotent; duplicates are safe) |
| Smoke query returns stale data | Wait 60s for index propagation, then re-query |
| Infrastructure down | Run `rag.health` to identify which service is down |

## Frequency

- After significant governance doc changes (>5 files modified)
- After adding new eligible docs to `docs/`, `ops/`, or `surfaces/`
- Monthly as baseline refresh
- After RAG infrastructure changes (model swap, version upgrade)
