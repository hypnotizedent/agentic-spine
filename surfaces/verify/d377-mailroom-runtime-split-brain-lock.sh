#!/usr/bin/env bash
# TRIAGE: Fail when repo-local mailroom runtime trees or tracked mailroom runtime artifacts drift back into agentic-spine.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
ROOT="$SPINE_TARGET_REPO"

fail() {
  echo "D377 FAIL: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

need_cmd git

declare -a allowed_repo_paths=(
  "mailroom/.keep"
  "mailroom/README.md"
  "mailroom/templates"
)

is_allowed_repo_path() {
  local rel="$1"
  local allowed
  for allowed in "${allowed_repo_paths[@]}"; do
    if [[ "$rel" == "$allowed" || "$rel" == "$allowed/"* ]]; then
      return 0
    fi
  done
  return 1
}

if [[ -d "$ROOT/mailroom" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    rel="${path#$ROOT/}"
    is_allowed_repo_path "$rel" || fail "repo-local mailroom runtime path present: $rel"
  done < <(find "$ROOT/mailroom" -mindepth 1 -print | sort)
fi

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  is_allowed_repo_path "$rel" || fail "tracked repo mailroom artifact present: $rel"
done < <(git -C "$ROOT" ls-files 'mailroom/**')

echo "D377 PASS: repo-local mailroom runtime drift absent"
