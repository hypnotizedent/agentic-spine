---
loop_id: LOOP-NETSEC-W1-STACK-KNOWLEDGE-BASE-20260303
created: 2026-03-03
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Define Wave 1 stack knowledge base contracts for a self-healing, agent-queryable resource index of self-hosted tools, Docker images, and external technology catalogs.
---

# Loop Scope: NetSec W1 Stack Knowledge Base

## Problem Statement

When evaluating new tools, services, or infrastructure components, agents have no queryable index of the self-hosted ecosystem. Discovery relies on ad-hoc web searches or manual conversation. There is no governed way to maintain awareness of tools from LinuxServer.io, selfh.st, AltStack, GitHub repos, or similar catalogs — and no way to recall this knowledge months later when product decisions require it.

## Deliverables

1. Draft `ops/bindings/stack.discovery.sources.yaml` — SSOT for external resource catalogs:
   - Source entries: linuxserver.io, selfh.st/apps, thealtstack.com, altstack-data (GitHub), grammar-llm (GitHub)
   - Required metadata: name, url, type (website|github_repo), refresh cadence, notes
   - Extensible: add new sources by appending entries
2. Draft `ops/bindings/stack.discovery.contract.yaml` covering:
   - Fetch → snapshot → normalize → embed → query pipeline contract
   - Dated immutable snapshots with SHA-256 manifest
   - JSONL normalized docs with source/url/title/text/captured_at fields
   - Embedding model contract (sentence-transformers default, swappable)
   - SQLite storage (docs + embeddings tables), upgradeable to vector DB later
   - Query interface: CLI (`stack.discovery.query`) and optional HTTP API
3. Draft freshness gate specification:
   - Last run < 36 hours
   - Source success rate >= 80%
   - Normalized file exists for latest snapshot date
4. Draft planned capability surface:
   - `stack.discovery.refresh` (mutating, auto) — fetch + normalize + embed
   - `stack.discovery.query` (read-only, auto) — semantic search against indexed sources
   - `stack.discovery.sources.add` (mutating, manual) — add new source entry
5. Child gaps filed and linked for all missing artifacts.

## Acceptance Criteria

1. Sources YAML is extensible — adding a source requires only a YAML append.
2. Pipeline contract is deterministic: fetch → snapshot → normalize → embed → query.
3. Freshness enforcement is gatable (no stale indexes served to agents).
4. Query capability is agent-invocable during planning and product decision sessions.
5. All missing artifacts are represented by child gaps.

## Constraints

1. Design-only; no Python scripts, Docker containers, or LaunchAgent runtime in this loop.
2. No embedding model downloads or API calls.
3. Contract only specifies interfaces — implementation deferred to execution wave.

## Gaps

1. `GAP-OP-1460` — No stack discovery knowledge base.
