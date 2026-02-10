#!/usr/bin/env bash
set -euo pipefail

# ops hooks - install/status for repo-local git hooks
#
# Usage:
#   ops hooks status
#   ops hooks install

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

cmd="${1:-}"
shift || true

usage() {
  cat <<'EOF'
ops hooks

Usage:
  ops hooks status   Show whether hooks are installed for this repo
  ops hooks install  Configure git to use .githooks/ and ensure pre-commit is executable
EOF
}

hooks_path="$(git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || true)"
hook_file="$REPO_ROOT/.githooks/pre-commit"

case "$cmd" in
  status)
    echo "hooksPath: ${hooks_path:-<unset>}"
    if [[ "${hooks_path:-}" == ".githooks" ]]; then
      echo "status: OK (core.hooksPath=.githooks)"
    else
      echo "status: WARN (core.hooksPath is not .githooks)"
    fi
    if [[ -x "$hook_file" ]]; then
      echo "pre-commit: OK ($hook_file executable)"
    else
      echo "pre-commit: WARN ($hook_file missing or not executable)"
    fi
    ;;
  install)
    mkdir -p "$REPO_ROOT/.githooks"
    if [[ -f "$hook_file" ]]; then
      chmod +x "$hook_file" || true
    fi
    git -C "$REPO_ROOT" config core.hooksPath .githooks
    echo "Installed: core.hooksPath=.githooks"
    if [[ -x "$hook_file" ]]; then
      echo "pre-commit: OK"
    else
      echo "pre-commit: WARN (missing or not executable): $hook_file"
      exit 1
    fi
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown subcommand: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
