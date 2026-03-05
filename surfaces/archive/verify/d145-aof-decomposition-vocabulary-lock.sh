#!/usr/bin/env bash
# TRIAGE: Use Step labels for decomposition in active loop scopes and docs/product; replace legacy WS/Move/Wave/Phase/P-tier labels.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONVENTIONS="$ROOT/ops/bindings/spine.schema.conventions.yaml"
LOOP_SCOPE_GLOB="$ROOT/mailroom/state/loop-scopes/*.scope.md"
PRODUCT_DIR="$ROOT/docs/product"
STAGED_ONLY=0

fail() {
  echo "D145 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONVENTIONS" ]] || fail "missing conventions file: $CONVENTIONS"
[[ -d "$PRODUCT_DIR" ]] || fail "missing product docs dir: $PRODUCT_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged-only)
      STAGED_ONLY=1
      shift
      ;;
    --)
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage:
  d145-aof-decomposition-vocabulary-lock.sh [--staged-only]

Modes:
  default       - checks all active loop scopes + docs/product/*.md
  --staged-only - checks only staged files within enforced surfaces (hook-friendly)
USAGE
      exit 0
      ;;
    *)
      fail "unknown arg: $1"
      ;;
  esac
done

canonical_term="$(yq -r '.decomposition_rules.canonical_term // ""' "$CONVENTIONS")"
[[ -n "$canonical_term" && "$canonical_term" != "null" ]] || fail "missing decomposition_rules.canonical_term in conventions"

mapfile -t banned_terms < <(yq -r '.decomposition_rules.disallowed_terms[]?' "$CONVENTIONS")
(( ${#banned_terms[@]} > 0 )) || fail "missing decomposition_rules.disallowed_terms in conventions"

target_files=()
active_scope_count=0

if [[ "$STAGED_ONLY" -eq 1 ]]; then
  command -v git >/dev/null 2>&1 || fail "required tool missing: git"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    abs="$ROOT/$rel"
    [[ -f "$abs" ]] || continue
    if [[ "$rel" == mailroom/state/loop-scopes/*.scope.md ]]; then
      if head -n 20 "$abs" | rg -q '^status:[[:space:]]*active$'; then
        target_files+=("$abs")
        active_scope_count=$((active_scope_count + 1))
      fi
    elif [[ "$rel" == docs/product/*.md ]]; then
      target_files+=("$abs")
    fi
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMRT)
else
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
fi

if (( ${#target_files[@]} == 0 )); then
  if [[ "$STAGED_ONLY" -eq 1 ]]; then
    echo "D145 PASS: no staged files in enforced surfaces"
    exit 0
  fi
  fail "no target files found"
fi

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
