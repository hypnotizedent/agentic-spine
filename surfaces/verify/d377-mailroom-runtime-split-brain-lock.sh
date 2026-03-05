#!/usr/bin/env bash
# TRIAGE: fail when externally-authoritative mailroom runtime artifacts are
# reintroduced in-repo (regression lock). Legacy committed artifacts are audited
# separately via strict mode.
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

STRICT_MODE="${D377_STRICT:-0}"

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
declare -a scopes=()
while IFS= read -r rel; do
  [[ -n "$rel" && "$rel" != "null" ]] || continue
  scopes+=("$rel")
done < <(yq e -r '.runtime_migration.items[]?' "$CONTRACT" 2>/dev/null || true)

record_if_violation() {
  local rel_path="$1"
  [[ -n "$rel_path" ]] || return 0
  [[ "$(basename "$rel_path")" == ".keep" ]] && return 0
  [[ ! -e "$ROOT/$rel_path" ]] && return 0
  if ! is_allowlisted "$rel_path"; then
    violations+=("$rel_path")
  fi
}

if [[ "$STRICT_MODE" == "1" ]]; then
  # Full scan: strict historical audit across all externalized runtime trees.
  for rel in "${scopes[@]}"; do
    target="$ROOT/$rel"
    [[ -e "$target" ]] || continue
    if [[ -f "$target" ]]; then
      record_if_violation "$rel"
      continue
    fi
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      record_if_violation "${file#$ROOT/}"
    done < <(find "$target" -type f 2>/dev/null | sort)
  done
else
  # Regression scan (default): only fail on newly dirty runtime artifacts.
  # This prevents reintroduction while avoiding permanent failure on legacy
  # committed history that must be cleaned in dedicated migration waves.
  mapfile -t changed_candidates < <(
    for scope in "${scopes[@]}"; do
      git -C "$ROOT" diff --name-only -- "$scope" || true
      git -C "$ROOT" diff --cached --name-only -- "$scope" || true
      git -C "$ROOT" ls-files -mo --exclude-standard -- "$scope" || true
    done | awk 'NF' | sort -u
  )
  for rel in "${changed_candidates[@]}"; do
    record_if_violation "$rel"
  done
fi

if (( ${#violations[@]} > 0 )); then
  mode_label="regression"
  [[ "$STRICT_MODE" == "1" ]] && mode_label="strict"
  echo "D377 FAIL: runtime split-brain duplicates detected (${mode_label} mode)" >&2
  echo "offending_paths:" >&2
  for path in "${violations[@]}"; do
    echo "  - $path" >&2
  done
  echo "fix_hint: run mailroom.runtime.migrate and prune migrated in-repo runtime artifacts to stubs/exceptions only." >&2
  exit 1
fi

if [[ "$STRICT_MODE" == "1" ]]; then
  echo "D377 PASS: no duplicate externally-authoritative runtime artifacts exist in strict scan"
else
  echo "D377 PASS: no runtime split-brain regressions in dirty workspace state"
fi
