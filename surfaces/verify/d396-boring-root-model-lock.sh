#!/usr/bin/env bash
# TRIAGE: keep agentic-spine as a five-home control-plane repo with only tiny root stubs/config.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

fail() {
  echo "D396 FAIL: $*" >&2
  exit 1
}

required_dirs=(bin docs fixtures ops surfaces)
allowed_dirs=(.git .claude .gitea .githooks .github bin docs fixtures ops surfaces)
allowed_files=(.environment.yaml .gitignore .identity.yaml .mcp.json AGENTS.md CLAUDE.md README.md)

contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

for dir in "${required_dirs[@]}"; do
  [[ -d "$ROOT/$dir" ]] || fail "missing required repo root directory: $dir"
done

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  name="$(basename "$path")"
  if [[ -d "$path" ]]; then
    contains "$name" "${allowed_dirs[@]}" || fail "unexpected repo root directory: $name"
  else
    contains "$name" "${allowed_files[@]}" || fail "unexpected repo root file: $name"
  fi
done < <(find "$ROOT" -maxdepth 1 -mindepth 1 -print | sort)

echo "D396 PASS: repo root matches boring five-home model"
