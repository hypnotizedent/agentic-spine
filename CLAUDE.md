# Claude Entry Stub

Canonical contract: [`docs/governance/SPINE.md`](docs/governance/SPINE.md)

Translator doctrine: [`docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)

<!-- SPINE_STARTUP_BLOCK -->
## Mandatory Boot Sequence

**You MUST execute this block at the start of every session before doing any work.**
Do not wait for the operator to ask. Do not skip it. This is not optional.

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

If the operator provides a `loop_id`, attach to it:
```bash
./bin/ops cap run session.v3.attach -- --loop-id LOOP-XXX
```
<!-- /SPINE_STARTUP_BLOCK -->

## Execution Rules

1. **Use governed capabilities, not raw shell.** If `./bin/ops cap list` shows a capability for the task, use it. Raw bash/git/ssh is a last resort, not a first choice. (Principle 13)
2. **Mutating work requires a loop.** If the operator asks for non-trivial changes and no loop is active, create one with `loops.create` before starting work. Do not produce floating WIP.
3. **Commit ceremony.** All commits on main require `OPS_GOVERNED_MAIN_OVERRIDE=1`. D128 trailers are auto-populated. Stage specific files, never `git add -A`.
4. **Verify after mutations.** After committing changes, run `./bin/ops cap run verify.run -- fast` to confirm no gates broke.

## Mandatory Closeout Sequence

**You MUST execute friction capabilities before ending a session with significant work.**

```bash
# Surface any friction from this session
./bin/ops cap run friction.queue.status

# If the session had failures or workarounds worth recording:
./bin/ops cap run friction.ingest -- \
  --loop-id LOOP-XXX \
  --capability <what-failed> \
  --expected "what should have happened" \
  --actual "what actually happened" \
  --severity <low|medium|high> \
  --auto-reconcile
```

If closing a loop:
```bash
./bin/ops cap run loop.closeout.finalize -- \
  --loop-id LOOP-XXX \
  --acceptance-matrix <path> \
  --disposition landed \
  --completion-level loop_complete \
  --propagation-evidence "..." \
  --owner "@ronny"
```

## Quick Reference

- Runtime Repo: `~/code/agentic-spine`
- Workbench Repo: `~/code/workbench`
- Query: direct file read → `./bin/ops cap run rag.anythingllm.ask` → MCP `rag_query` → `rg` fallback
- Docker context: `docker context show`
- Gap operations: `gaps.file --id auto --parent-loop LOOP-XXX`
- Loop operations: `loops.create --name NAME --objective "desc"`

<!-- ENTRY_SURFACE_GATE_METADATA_START -->
# ENTRY SURFACE GATE METADATA (generated)
entry_surface_gate_metadata: projection
source_registry: ops/bindings/gate.registry.yaml
registry_updated: 2026-03-24
gate_count_total: 412
gate_count_active: 112
gate_count_retired: 300
max_gate_id: D422
<!-- ENTRY_SURFACE_GATE_METADATA_END -->
