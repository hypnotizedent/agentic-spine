#!/usr/bin/env bash
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$SP/ops/bindings/agent.read.surface.yaml"

command -v yq >/dev/null 2>&1 || {
  echo "D26 FAIL: missing dependency: yq"
  exit 1
}

[[ -f "$BINDING" ]] || {
  echo "D26 FAIL: missing binding: $BINDING"
  exit 1
}

failures=0

check_repo_path() {
  local rel="$1"
  [[ -n "$rel" ]] || return 0
  if [[ ! -e "$SP/$rel" ]]; then
    echo "D26 FAIL: missing agent read surface: $rel"
    failures=$((failures + 1))
  fi
}

while IFS= read -r rel; do
  check_repo_path "$rel"
done < <(
  yq -r '
    .startup_read_surface[]?,
    .host_fact_routes.identity?,
    .host_fact_routes.services?,
    .host_fact_routes.host_detail[]?
  ' "$BINDING"
)

while IFS=$'\t' read -r repo path must_ref; do
  [[ -n "$repo" && -n "$path" ]] || continue
  repo_root="$HOME/code/$repo"
  target="$repo_root/$path"
  if [[ ! -f "$target" ]]; then
    echo "D26 FAIL: missing external entrypoint: $target"
    failures=$((failures + 1))
    continue
  fi
  if [[ -n "$must_ref" ]] && ! rg -Fq "$must_ref" "$target"; then
    echo "D26 FAIL: external entrypoint missing required reference: $target -> $must_ref"
    failures=$((failures + 1))
  fi
done < <(yq -r '.external_entrypoints[]? | [.repo, .path, (.must_reference // "")] | @tsv' "$BINDING")

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "D26 PASS: agent read surfaces and entrypoint references present"

