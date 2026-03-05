#!/usr/bin/env bash
# TRIAGE: Ensure rag.reindex.quality.yaml binding exists with required fields and capabilities are registered.
# D89: RAG Reindex Quality Contract Lock
#
# Enforces:
# 1) rag.reindex.quality.yaml binding exists with required fields
# 2) rag.reindex.remote.verify capability is registered
# 3) rag.remote.dependency.probe capability is registered
# 4) Binding has required threshold fields
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$ROOT"

QUALITY_BINDING="$ROOT/ops/bindings/rag.reindex.quality.yaml"
RUNNER_BINDING="$ROOT/ops/bindings/rag.remote.runner.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
CAP_MAP="$ROOT/ops/bindings/capability_map.yaml"

fail() { echo "D89 FAIL: $*" >&2; exit 1; }

for f in "$QUALITY_BINDING" "$RUNNER_BINDING" "$CAPS" "$CAP_MAP"; do
  [[ -f "$f" ]] || fail "required file missing: $f"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

ERRORS=0
err() { echo "  $*" >&2; ERRORS=$((ERRORS + 1)); }

# 1) Quality binding required fields
required_fields=(
  ".completion.max_failed_uploads"
  ".completion.session_must_be_stopped"
  ".completion.checkpoint_must_be_empty"
  ".index_health.max_index_inflation_ratio"
  ".index_health.min_parity_ratio"
  ".dependency_slos.anythingllm_ping_ms"
  ".dependency_slos.qdrant_healthz_ms"
  ".dependency_slos.ollama_tags_ms"
)
for key in "${required_fields[@]}"; do
  val="$(yq -r "$key // \"\"" "$QUALITY_BINDING" 2>/dev/null || true)"
  if [[ -z "$val" || "$val" == "null" ]]; then
    err "quality binding missing required field: $key"
  fi
done

# 2) Verify capability registration
for cap in rag.reindex.remote.verify rag.remote.dependency.probe; do
  if ! yq -e ".capabilities.\"$cap\"" "$CAPS" >/dev/null 2>&1; then
    err "capability missing in capabilities.yaml: $cap"
  fi
  if ! yq -e ".capabilities.\"$cap\"" "$CAP_MAP" >/dev/null 2>&1; then
    err "capability missing in capability_map.yaml: $cap"
  fi
done

# 3) Verify scripts exist and are executable
for script in rag-reindex-remote-verify rag-remote-dependency-probe; do
  script_path="$ROOT/ops/plugins/rag/bin/$script"
  if [[ ! -f "$script_path" ]]; then
    err "script missing: ops/plugins/rag/bin/$script"
  elif [[ ! -x "$script_path" ]]; then
    err "script not executable: ops/plugins/rag/bin/$script"
  fi
done

# 4) Validate threshold types
max_failed="$(yq -r '.completion.max_failed_uploads // ""' "$QUALITY_BINDING")"
if [[ -n "$max_failed" && "$max_failed" != "null" ]]; then
  if ! [[ "$max_failed" =~ ^[0-9]+$ ]]; then
    err "max_failed_uploads must be integer (got: $max_failed)"
  fi
fi

inflation="$(yq -r '.index_health.max_index_inflation_ratio // ""' "$QUALITY_BINDING")"
if [[ -n "$inflation" && "$inflation" != "null" ]]; then
  if ! [[ "$inflation" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    err "max_index_inflation_ratio must be numeric (got: $inflation)"
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS governance errors found"
fi

echo "D89 PASS: RAG reindex quality contract lock enforced (binding + capabilities + scripts)"
