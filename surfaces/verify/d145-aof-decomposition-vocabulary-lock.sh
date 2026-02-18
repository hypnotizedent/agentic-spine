#!/usr/bin/env bash
# TRIAGE: Use Step labels for decomposition in active loop scopes and docs/product; replace legacy WS/Move/Wave/Phase/P-tier labels.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONVENTIONS="$ROOT/ops/bindings/spine.schema.conventions.yaml"
LOOP_SCOPE_GLOB="$ROOT/mailroom/state/loop-scopes/*.scope.md"
PRODUCT_DIR="$ROOT/docs/product"

fail() {
  echo "D145 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONVENTIONS" ]] || fail "missing conventions file: $CONVENTIONS"
[[ -d "$PRODUCT_DIR" ]] || fail "missing product docs dir: $PRODUCT_DIR"

canonical_term="$(yq -r '.decomposition_rules.canonical_term // ""' "$CONVENTIONS")"
[[ -n "$canonical_term" && "$canonical_term" != "null" ]] || fail "missing decomposition_rules.canonical_term in conventions"

mapfile -t banned_terms < <(yq -r '.decomposition_rules.disallowed_terms[]?' "$CONVENTIONS")
(( ${#banned_terms[@]} > 0 )) || fail "missing decomposition_rules.disallowed_terms in conventions"

target_files=()
active_scope_count=0

for file in $LOOP_SCOPE_GLOB; do
  [[ -f "$file" ]] || continue
  if head -n 20 "$file" | rg -q '^status:[[:space:]]*active$'; then
    target_files+=("$file")
    active_scope_count=$((active_scope_count + 1))
  fi
done

while IFS= read -r file; do
  [[ -n "$file" ]] && target_files+=("$file")
done < <(find "$PRODUCT_DIR" -type f -name '*.md' | sort)

(( ${#target_files[@]} > 0 )) || fail "no target files found"

violations=()
for term in "${banned_terms[@]}"; do
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    violations+=("$hit (term=$term)")
  done < <(rg -n -w --no-heading --color never "$term" "${target_files[@]}" || true)
done

if (( ${#violations[@]} > 0 )); then
  fail "decomposition vocabulary violations detected:
$(printf '  - %s\n' "${violations[@]}")"
fi

echo "D145 PASS: decomposition vocabulary lock valid (canonical=$canonical_term, active_scopes=$active_scope_count, files_checked=${#target_files[@]})"
