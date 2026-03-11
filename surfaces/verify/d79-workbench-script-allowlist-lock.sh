#!/usr/bin/env bash
# TRIAGE: Enforce the governed workbench shell-script surface.
# D79: Workbench script allowlist lock

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALLOWLIST="${ALLOWLIST_FILE:-$ROOT/ops/bindings/workbench.script.allowlist.yaml}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"

fail() {
  echo "D79 FAIL: $*" >&2
  exit 1
}

[[ -f "$ALLOWLIST" ]] || fail "missing allowlist: $ALLOWLIST"
[[ -d "$WORKBENCH_ROOT" ]] || fail "workbench not found: $WORKBENCH_ROOT"
command -v yq >/dev/null 2>&1 || fail "yq required"

yq e '.' "$ALLOWLIST" >/dev/null 2>&1 || fail "invalid YAML: $ALLOWLIST"

shopt -s globstar nullglob

declare -A allow_index=()
declare -A seen_index=()
declare -a violations=()

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  allow_index["$rel"]=1
  if [[ ! -e "$WORKBENCH_ROOT/$rel" ]]; then
    violations+=("allowlist entry missing on disk: $rel")
  fi
done < <(yq e -r '.scripts[]' "$ALLOWLIST")

matches_excluded() {
  local rel="$1"
  local pattern
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    if [[ "$rel" == $pattern ]]; then
      return 0
    fi
  done < <(yq e -r '.excluded[]?' "$ALLOWLIST")
  return 1
}

while IFS= read -r pattern; do
  [[ -n "$pattern" ]] || continue
  for path in $WORKBENCH_ROOT/$pattern; do
    [[ -e "$path" ]] || continue
    [[ -f "$path" ]] || continue
    [[ "$path" == *.sh ]] || continue

    rel="${path#$WORKBENCH_ROOT/}"
    matches_excluded "$rel" && continue
    seen_index["$rel"]=1

    if [[ -z "${allow_index[$rel]:-}" ]]; then
      violations+=("active shell surface missing from allowlist: $rel")
    fi
  done
done < <(yq e -r '.active_surfaces[]' "$ALLOWLIST")

for rel in "${!allow_index[@]}"; do
  if [[ -z "${seen_index[$rel]:-}" ]]; then
    violations+=("allowlist entry not covered by active surfaces: $rel")
  fi
done

if [[ "${#violations[@]}" -gt 0 ]]; then
  IFS=$'\n' sorted=($(printf '%s\n' "${violations[@]}" | sort))
  unset IFS
  fail "$(printf '%s\n' "${sorted[@]}")"
fi

count="${#seen_index[@]}"
echo "D79 PASS: workbench script allowlist enforced (scripts=$count)"
