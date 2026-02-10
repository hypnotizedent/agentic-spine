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
runtime_paths=(
  "mailroom/state/ledger.csv"
)

runtime_flag() {
  local p="$1"
  if ! git -C "$REPO_ROOT" ls-files --error-unmatch "$p" >/dev/null 2>&1; then
    echo "<untracked>"
    return 0
  fi
  # git ls-files -v prefixes "S" for skip-worktree.
  git -C "$REPO_ROOT" ls-files -v "$p" 2>/dev/null | awk '{print substr($0,1,1)}'
}

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

    for p in "${runtime_paths[@]}"; do
      flag="$(runtime_flag "$p")"
      if [[ "$flag" == "S" || "$flag" == "<untracked>" ]]; then
        echo "runtime: OK ($p skip-worktree)"
      else
        echo "runtime: WARN ($p is tracked and not skip-worktree)"
        echo "  fix: ./bin/ops hooks install"
      fi
    done
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

    # Mark runtime state files as skip-worktree so multi-terminal workflows
    # don't get stuck on local-only churn.
    for p in "${runtime_paths[@]}"; do
      if git -C "$REPO_ROOT" ls-files --error-unmatch "$p" >/dev/null 2>&1; then
        git -C "$REPO_ROOT" update-index --skip-worktree "$p" >/dev/null 2>&1 || true
        echo "runtime: set skip-worktree ($p)"
      fi
    done
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
