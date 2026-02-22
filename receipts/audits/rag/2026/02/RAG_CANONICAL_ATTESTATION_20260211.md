---
status: attestation
owner: "@ronny"
last_verified: 2026-02-11
scope: rag-canonical-attestation
loop: LOOP-RAG-CANONICAL-ATTEST-20260211
---

# RAG Canonical Attestation — 2026-02-11

## Summary

This attestation proves that the RAG indexing pipeline (`ops/plugins/rag/bin/rag`) ingests **only canonical, governance-compliant documents** and explicitly excludes all non-canonical paths.

**Result: PASS** — All checks passed. No non-canonical content in manifest.

---

## 1. Baseline Health

### rag.health

| Service | Endpoint | Status |
|---------|----------|--------|
| AnythingLLM | `http://100.71.17.29:3002` | OK |
| Qdrant | `http://100.71.17.29:6333` | OK |
| Ollama | `http://100.98.70.70:11434` | OK |

Receipt: `RCAP-20260211-123734__rag.health__Rods132842`

### rag.anythingllm.status

| Metric | Value |
|--------|-------|
| Workspace | `agentic-spine` |
| Docs indexed | **34** |

Receipt: `RCAP-20260211-123738__rag.anythingllm.status__R25ls33094`

---

## 2. Manifest Dry-Run

Total eligible documents: **80**

The manifest builder scans three allowed roots (`docs/`, `ops/`, `surfaces/`) and applies:

1. **Path exclusion** — prefix-based deny list (9 prefixes) + `.archive/` path segment deny
2. **Frontmatter filter** — requires `status:`, `owner:`, `last_verified:` in YAML frontmatter
3. **Secrets scan** — runtime deny for PEM keys, AWS keys, GitHub/Slack/OpenAI tokens, generic password fields

Source: `ops/plugins/rag/bin/rag` lines 277–342

---

## 3. Exclusion Proofs

Each non-canonical directory is confirmed excluded from the manifest.

### 3.1 `docs/governance/_audits/`

- **Directory exists**: YES (11 `.md` files)
- **Excluded prefix**: `docs/governance/_audits/` (line 290)
- **In manifest**: NO (0 files)
- **Verdict**: EXCLUDED

### 3.2 `docs/governance/_archived/`

- **Directory exists**: NO (does not exist on disk)
- **Excluded prefix**: `docs/governance/_archived/` (line 291)
- **In manifest**: NO (0 files)
- **Verdict**: EXCLUDED (prefix guard active for future use)

### 3.3 `docs/governance/_imported/`

- **Directory exists**: NO (does not exist on disk)
- **Excluded prefix**: `docs/governance/_imported/` (line 292)
- **In manifest**: NO (0 files)
- **Verdict**: EXCLUDED (prefix guard active for future use)

### 3.4 `docs/legacy/`

- **Directory exists**: YES (11 `.md` files)
- **Excluded prefix**: `docs/legacy/` (line 289, concatenated to avoid D42 self-match)
- **In manifest**: NO (0 files)
- **Verdict**: EXCLUDED

### 3.5 `mailroom/state/`

- **Directory exists**: YES (78 `.md` files including loop scopes, ledger)
- **Excluded prefix**: `mailroom/state/` (line 294)
- **In manifest**: NO (0 files)
- **Verdict**: EXCLUDED

### 3.6 `.archive/` path segments

- **Exclusion**: any path containing `/.archive/`, starting with `.archive/`, or ending with `/.archive` (lines 301–302)
- **In manifest**: NO (0 files)
- **Verdict**: EXCLUDED

---

## 4. D68 Gate Evidence

**Gate**: `surfaces/verify/d68-rag-canonical-only-gate.sh`
**Result**: `PASS`
**Date**: 2026-02-11

D68 performs three checks:

| Check | Description | Result |
|-------|-------------|--------|
| 1 | Exclusion rules present for `_audits/`, `_archived/`, `_imported/`, `legacy/` | PASS |
| 2 | `has_required_frontmatter` filter present in `build_manifest()` | PASS |
| 3 | Dry-run manifest contains zero non-canonical paths (deny patterns: `_audits/`, `_archived/`, `_imported/`, `/legacy/`) | PASS |

---

## 5. Defense-in-Depth Summary

| Layer | Mechanism | Location |
|-------|-----------|----------|
| Allowed roots | Only `docs/`, `ops/`, `surfaces/` scanned | `build_manifest()` line 286 |
| Path exclusion | 9-prefix deny list + `.archive/` segment | `is_excluded()` lines 300–306 |
| Frontmatter gate | Requires `status:`, `owner:`, `last_verified:` | `has_required_frontmatter()` lines 308–325 |
| Secrets filter | PEM, AWS, GitHub, Slack, OpenAI token deny + generic password pattern | `check_secrets()` lines 222–275 |
| Drift gate D68 | Static analysis + dry-run manifest validation | `d68-rag-canonical-only-gate.sh` |
| Governance policy | `RAG_INDEXING_RULES.md` + `SEARCH_EXCLUSIONS.md` | `docs/governance/` |

---

## 6. Residual Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| New non-canonical directory created outside excluded prefixes | Low | D68 dry-run catches deny-pattern paths; frontmatter gate blocks unstructured files |
| Document with valid frontmatter but stale/wrong content indexed | Low | D58 freshness gate enforces `last_reviewed` dates; `status: deprecated` docs should be removed by deprecation sweeper D60 |
| AnythingLLM workspace has 34 docs vs 80 eligible — sync delta | Info | Delta is expected: `rag.anythingllm.sync` must be run to upload new docs. This is by design (manual trigger, not automatic). |
| Secrets filter bypassed by novel token format | Low | Conservative deny patterns + generic password field scan provide layered coverage |

---

## 7. Attestation

The RAG indexing pipeline, as implemented in `ops/plugins/rag/bin/rag` and enforced by drift gate D68, indexes **only canonical, frontmatter-validated documents** from approved directory roots. All non-canonical paths are explicitly excluded by prefix matching and validated by dry-run manifest checks.

**Attested by**: Terminal E (Claude Code session)
**Date**: 2026-02-11
**Loop**: LOOP-RAG-CANONICAL-ATTEST-20260211
