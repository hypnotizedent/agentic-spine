#!/usr/bin/env bash
# TRIAGE: fail when externally-authoritative mailroom runtime artifacts exist in-repo.
# Gate: D377 — mailroom-runtime-split-brain-lock
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DEFAULT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT="${SPINE_ROOT:-$ROOT_DEFAULT}"
CONTRACT="$ROOT/ops/bindings/mailroom.runtime.contract.yaml"

fail() {
  echo "D377 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing runtime contract: $CONTRACT"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

active="$(yq e -r '.active // false' "$CONTRACT" 2>/dev/null || echo "false")"
if [[ "$active" != "true" ]]; then
  echo "D377 PASS: runtime externalization inactive; split-brain lock not applicable"
  exit 0
fi

is_allowlisted() {
  local rel="$1"
  local pattern
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    [[ "$pattern" == "null" ]] && continue
    if [[ "$rel" == $pattern ]]; then
      return 0
    fi
  done < <(yq e -r '.tracked_exceptions[]?' "$CONTRACT" 2>/dev/null || true)
  return 1
}

declare -a violations=()

while IFS= read -r rel; do
  [[ -n "$rel" && "$rel" != "null" ]] || continue
  target="$ROOT/$rel"
  [[ -e "$target" ]] || continue

  if [[ -f "$target" ]]; then
    if ! is_allowlisted "$rel"; then
      violations+=("$rel")
    fi
    continue
  fi

  if [[ -d "$target" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      rel_file="${file#$ROOT/}"

      # Intentional stubs are allowed to keep directories materialized.
      if [[ "$(basename "$rel_file")" == ".keep" ]]; then
        continue
      fi

      if ! is_allowlisted "$rel_file"; then
        violations+=("$rel_file")
      fi
    done < <(find "$target" -type f 2>/dev/null | sort)
  fi
done < <(yq e -r '.runtime_migration.items[]?' "$CONTRACT" 2>/dev/null || true)

if (( ${#violations[@]} > 0 )); then
  echo "D377 FAIL: runtime split-brain duplicates detected in repo-tracked runtime trees" >&2
  echo "offending_paths:" >&2
  for path in "${violations[@]}"; do
    echo "  - $path" >&2
  done
  echo "fix_hint: run mailroom.runtime.migrate and prune migrated in-repo runtime artifacts to stubs/exceptions only." >&2
  exit 1
fi

echo "D377 PASS: no duplicate externally-authoritative runtime artifacts exist in repo runtime trees"
