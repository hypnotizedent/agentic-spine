---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-14
scope: rag-reindex-runbook
---

# RAG Reindex Runbook

> Governed checklist for performing a full RAG reindex.
> Authority: `ops/bindings/rag.workspace.contract.yaml`, `ops/bindings/rag.reindex.quality.yaml`

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

4. Remote dependencies are within SLO:
   ```
   ./bin/ops cap run rag.remote.dependency.probe
   ```
   All three probes must report OK within SLO thresholds.

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
- `ops/bindings/rag.reindex.quality.yaml`
- `surfaces/verify/d88-rag-remote-reindex-governance-lock.sh`
- `surfaces/verify/d89-rag-reindex-quality-contract-lock.sh`

### Step 1: Dry-Run Manifest

Run a dry-run to capture the eligible document list:

```
echo "yes" | ./bin/ops cap run rag.anythingllm.sync --dry-run
```

Review the manifest output. Verify:
- Eligible count matches expectations (~90 docs as of 2026-02-14)
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

### Step 3: Verify Quality (CRITICAL)

**Before relying on the reindex, run quality verification:**

```
./bin/ops cap run rag.reindex.remote.verify
```

This validates against `ops/bindings/rag.reindex.quality.yaml`:
- Session is STOPPED (not running/paused)
- Failed uploads == 0 (no HTTP 000 timeouts)
- Checkpoint is empty/absent (complete sync)
- Index inflation ratio within threshold

**If verification FAILS:**
- Review `rag.reindex.remote.status` for error details
- Check for timeout storms in the log
- Resume or restart sync as needed

### Step 4: Verify Parity

Check post-sync parity:

```
./bin/ops cap run rag.anythingllm.status
```

Acceptance: `parity: OK` (docs_indexed >= docs_eligible).

**WARNING:** Parity OK alone is NOT sufficient - always run `rag.reindex.remote.verify` to catch false-green conditions where stale/inflated counts mask failed uploads.

### Step 5: Smoke Test Queries

Run at least two smoke queries to verify index quality:

```
./bin/ops cap run rag.anythingllm.ask "What is the canonical session entry protocol file?"
./bin/ops cap run rag.anythingllm.ask "How do I file a gap?"
```

Verify:
- Answers reference correct governance docs
- Sources list includes relevant file paths
- No stale or archived docs in sources

### Step 6: Record Attestation

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
| Timeout storms (HTTP 000) | Run `rag.remote.dependency.probe` to check VM207 dependencies; may be embedding/processing bottleneck |
| Verify fails with failed uploads | Resume sync; if persistent, check AnythingLLM container logs |
| Verify fails with session running | Wait for completion or stop session manually |

## Frequency

- After significant governance doc changes (>5 files modified)
- After adding new eligible docs to `docs/`, `ops/`, or `surfaces/`
- Monthly as baseline refresh
- After RAG infrastructure changes (model swap, version upgrade)
