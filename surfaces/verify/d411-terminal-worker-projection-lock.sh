#!/usr/bin/env bash
set -euo pipefail

git_top_level() {
  local probe="${1:-.}"
  git -C "$probe" rev-parse --show-toplevel 2>/dev/null || true
}

resolve_root() {
  local cwd_root script_root env_name value
  cwd_root="$(git_top_level "$PWD")"
  if [[ -n "$cwd_root" ]]; then
    printf '%s\n' "$cwd_root"
    return 0
  fi

  script_root="$(git_top_level "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)")"
  if [[ -n "$script_root" ]]; then
    printf '%s\n' "$script_root"
    return 0
  fi

  for env_name in SPINE_TARGET_REPO SPINE_ROOT SPINE_REPO SPINE_CODE; do
    value="${!env_name:-}"
    if [[ -n "$value" ]]; then
      (cd "$value" && pwd)
      return 0
    fi
  done

  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

ROOT="$(resolve_root)"
export SPINE_ROOT="$ROOT"
export SPINE_TARGET_REPO="$ROOT"
export SPINE_REPO="$ROOT"
export SPINE_CODE="$ROOT"
exec "$ROOT/ops/plugins/core/verify/bin/worker-projection-audit" --root "$ROOT"
