#!/usr/bin/env bash
set -euo pipefail

# Shared path resolution for workflow wrappers that need the workbench repo.
# Keep explicit overrides first and fail closed when no managed path is found.

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

  echo "ERROR: unable to resolve workbench repo root from managed overrides or canonical sibling checkout" >&2
  exit 1
}
