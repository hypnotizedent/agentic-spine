# rag

Canonical domain policy for `rag`.

- Authority: `docs/governance/SPINE.md`
- Runtime contract: `ops/bindings/domains/rag/rag.workspace.contract.yaml`
- Health: `./bin/ops cap run rag.direct.health`
- Quality gate: `./bin/ops cap run rag.direct.quality`
- Retrieval: `./bin/ops cap run rag.direct.retrieve -- "<question>"`
- Workbench agent root: `~/code/workbench/agents/ai-consolidation/`

The workbench agent uses the name `ai-consolidation` (matching the VM/host identity).
Spine retains `rag` as the capability domain name for policy and control-plane authority.
RAG is L2 retrieval assistance only. It returns source refs for agents to read;
it is not authority, not L1 kernel, and not a promoted standalone node.

The RAG allowlist must index governed source surfaces, not consumer-local mixed
memory. `$SPINE_STATE/domain-state/spine/` is excluded because it contains
historical narrative bodies, archived receipts, and projection/cache artifacts;
indexing it as authority teaches agents to recreate that residue.

AnythingLLM is retired from normal RAG agent grammar. Its runtime may remain
temporarily on ai-consolidation as compatibility residue, but the canonical
agent path is direct Qdrant/Ollama through `rag.direct.*`.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

- `rag.capacity.status` — embedding/inference contention status.
- `rag.direct.health` — direct Qdrant/Ollama health.
- `rag.direct.manifest` — Packet 63 allowlist manifest.
- `rag.direct.index` — governed direct source-card indexer.
- `rag.direct.progress` — index progress and collection count.
- `rag.direct.quality` — retrieval quality gate.
- `rag.direct.retrieve` — source-ref retrieval.
- `rag.direct.query` — cited answer synthesis from retrieved refs.
- `rag.direct.retry_failed` — retry lane for indexed source-card failures.
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
