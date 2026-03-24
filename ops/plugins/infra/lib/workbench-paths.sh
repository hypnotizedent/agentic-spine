#!/usr/bin/env bash
set -euo pipefail

# Shared path resolution for workflow wrappers that need the workbench repo.
# Keep explicit overrides first and only fall back to a canonical checkout
# when no managed path is supplied.

if [[ -z "${SPINE_ROOT:-}" ]]; then
  SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
fi

# Required by repo policy for new shell helpers.
# shellcheck source=/dev/null
source "$SPINE_ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

workbench_repo_root() {
  local candidate
  local -a candidates=()

  if [[ -n "${WORKBENCH_REPO:-}" ]]; then
    candidates+=("$WORKBENCH_REPO")
  fi
  if [[ -n "${WORKBENCH_MANAGED_CONFIG_ROOT:-}" ]]; then
    candidates+=("$WORKBENCH_MANAGED_CONFIG_ROOT")
  fi
  if [[ -n "${WORKBENCH_ROOT:-}" ]]; then
    candidates+=("$WORKBENCH_ROOT")
  fi
  if [[ -n "${SPINE_ROOT:-}" ]]; then
    candidates+=("${SPINE_ROOT%/}/../workbench")
  fi
  candidates+=("${HOME}/code/workbench")

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      (cd "$candidate" && pwd -P)
      return 0
    fi
  done

  printf '%s\n' "${HOME}/code/workbench"
}
