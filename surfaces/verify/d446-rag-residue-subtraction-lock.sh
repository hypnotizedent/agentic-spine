#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "D446 FAIL: $*" >&2
  exit 1
}

retired_files=(
  "ops/plugins/infra/rag/bin/anythingllm-tune"
  "ops/plugins/infra/rag/bin/rag"
  "ops/plugins/infra/rag/bin/rag-budget-status"
  "ops/plugins/infra/rag/bin/rag-embedding-probe"
  "ops/plugins/infra/rag/bin/rag-index-audit"
  "ops/plugins/infra/rag/bin/rag-index-audit-report.py"
  "ops/plugins/infra/rag/bin/rag-observability-activate"
  "ops/plugins/infra/rag/bin/rag-reindex-metrics-export"
  "ops/plugins/infra/rag/bin/rag-reindex-remote-start"
  "ops/plugins/infra/rag/bin/rag-reindex-remote-status"
  "ops/plugins/infra/rag/bin/rag-reindex-remote-stop"
  "ops/plugins/infra/rag/bin/rag-reindex-remote-verify"
  "ops/plugins/infra/rag/bin/rag-reindex-smoke"
  "ops/plugins/infra/rag/bin/rag-remote-dependency-probe"
  "ops/bindings/domains/rag/rag.metrics.normalization.yaml"
  "ops/bindings/domains/rag/rag.observability.contract.yaml"
  "ops/bindings/domains/rag/rag.reindex.quality.yaml"
  "ops/bindings/domains/rag/rag.remote.runner.yaml"
  "ops/bindings/domains/rag/rag.workload.budget.yaml"
)

for rel in "${retired_files[@]}"; do
  [[ ! -e "$ROOT/$rel" ]] || fail "retired RAG residue still exists: $rel"
done

current_surfaces=(
  "AGENTS.md"
  "docs/governance/SESSION_PROTOCOL.md"
  "docs/governance/SPINE.md"
  "docs/governance/domains/rag.md"
  "ops/capabilities.yaml"
  "ops/plugins/MANIFEST.yaml"
  "ops/plugins/infra/rag/capabilities.yaml"
  "ops/bindings/domains/rag.bundle.yaml"
  "ops/bindings/domains/rag/rag.workspace.contract.yaml"
  "ops/bindings/surface.readonly.contract.yaml"
)

retired_tokens='rag\.anythingllm|rag\.budget\.status|rag\.reindex\.remote|rag\.reindex\.metrics\.export|rag\.observability\.activate|rag\.health\b|rag\.sync\b'
if rg -n "$retired_tokens" "${current_surfaces[@]/#/$ROOT/}" >/tmp/d446-rag-residue.txt 2>/dev/null; then
  cat /tmp/d446-rag-residue.txt >&2
  rm -f /tmp/d446-rag-residue.txt
  fail "retired RAG capability grammar found in current surfaces"
fi
rm -f /tmp/d446-rag-residue.txt

for cap in rag.direct.health rag.direct.quality rag.direct.retrieve rag.direct.query rag.direct.progress; do
  rg -q "^[[:space:]]*$cap:" "$ROOT/ops/capabilities.yaml" || fail "missing direct RAG capability: $cap"
done

grep -q "RAG is first-class retrieval tooling for agents, not memory and not authority" "$ROOT/docs/governance/SESSION_PROTOCOL.md" || fail "SESSION_PROTOCOL must keep RAG as retrieval, not authority"
grep -q "RAG answers must be treated as pointers" "$ROOT/docs/governance/SESSION_PROTOCOL.md" || fail "SESSION_PROTOCOL must require cited source reads before mutation"
grep -q "Do not claim authority; cite source paths" "$ROOT/ops/plugins/infra/rag/bin/rag-direct" || fail "rag.direct must keep non-authority answer boundary"

if rg -n '100\.98\.70\.70:11434|100\.71\.17\.29:6333' "$ROOT/ops/plugins/infra/rag/bin" >/tmp/d446-rag-endpoint-residue.txt 2>/dev/null; then
  cat /tmp/d446-rag-endpoint-residue.txt >&2
  rm -f /tmp/d446-rag-endpoint-residue.txt
  fail "RAG runtime scripts must derive Ollama/Qdrant endpoints from rag.workspace.contract.yaml or service catalogs, not hardcoded host literals"
fi
rm -f /tmp/d446-rag-endpoint-residue.txt

echo "D446 PASS: retired AnythingLLM/remote-reindex RAG residue is absent from current agent grammar and direct RAG remains canonical"
