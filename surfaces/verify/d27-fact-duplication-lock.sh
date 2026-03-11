#!/usr/bin/env bash
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$SP/ops/bindings/agent.fact.lock.yaml"

command -v yq >/dev/null 2>&1 || {
  echo "D27 FAIL: missing dependency: yq"
  exit 1
}

[[ -f "$BINDING" ]] || {
  echo "D27 FAIL: missing binding: $BINDING"
  exit 1
}

failures=0
declare -A seen=()

check_doc() {
  local rel="$1"
  local group="$2"
  [[ -n "$rel" ]] || return 0
  if [[ ! -f "$SP/$rel" ]]; then
    echo "D27 FAIL: missing ${group} doc: $rel"
    failures=$((failures + 1))
  fi
}

while IFS= read -r rel; do
  check_doc "$rel" "canonical fact"
  if [[ -n "${seen[$rel]:-}" ]]; then
    echo "D27 FAIL: duplicate canonical fact doc entry: $rel"
    failures=$((failures + 1))
  fi
  seen["$rel"]=1
done < <(yq -r '.canonical_fact_docs[]?' "$BINDING")

while IFS= read -r rel; do
  check_doc "$rel" "no-fact"
  if [[ -n "${seen[$rel]:-}" ]]; then
    echo "D27 FAIL: doc listed as both canonical_fact_doc and no_fact_doc: $rel"
    failures=$((failures + 1))
  fi
done < <(yq -r '.no_fact_docs[]?' "$BINDING")

service_registry="$(yq -r '.service_registry // ""' "$BINDING")"
check_doc "$service_registry" "service registry"

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "D27 PASS: fact authority docs exist and no-fact surfaces do not overlap"

