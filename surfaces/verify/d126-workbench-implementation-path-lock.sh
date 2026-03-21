#!/usr/bin/env bash
# TRIAGE: Keep domain_external capability implementation paths truthful and discoverable across declared repos.
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
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:?--root requires a value}" && pwd)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      exit 0
      ;;
    *)
      echo "D126 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

AUDIT="$ROOT/ops/plugins/core/verify/bin/workbench-impl-audit"

fail() {
  echo "D126 FAIL: $*" >&2
  exit 1
}

[[ -x "$AUDIT" ]] || fail "missing executable: $AUDIT"

if ! SPINE_ROOT="$ROOT" "$AUDIT" --root "$ROOT" --strict; then
  fail "domain_external implementation path governance failed (run ./bin/ops cap run workbench.impl.audit --list)"
fi

echo "D126 PASS: domain_external implementation path lock enforced"
