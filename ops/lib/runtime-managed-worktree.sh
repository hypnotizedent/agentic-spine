#!/usr/bin/env bash
set -euo pipefail

# Resolve scheduler execution context for recurring runtime jobs.
#
# Historical name retained for compatibility with existing launchd wrappers.
# Scheduler jobs now run against control-root code plus externalized runtime
# roots. They no longer provision or impersonate a standing git worktree.
spine_runtime_resolve_control_root() {
  local script_path="${1:-}"
  local cwd_root=""
  local script_root=""
  local env_name=""
  local value=""
  local probe=""

  cwd_root="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$cwd_root" && -f "$cwd_root/ops/capabilities.runtime.yaml" ]]; then
    printf '%s\n' "$cwd_root"
    return 0
  fi

  if [[ -n "$script_path" ]]; then
    if [[ -d "$script_path" ]]; then
      probe="$script_path"
    else
      probe="$(dirname "$script_path")"
    fi
    script_root="$(git -C "$probe" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$script_root" && -f "$script_root/ops/capabilities.runtime.yaml" ]]; then
      printf '%s\n' "$script_root"
      return 0
    fi
  fi

  for env_name in SPINE_TARGET_REPO SPINE_ROOT SPINE_REPO SPINE_CODE; do
    value="${!env_name:-}"
    if [[ -z "$value" ]]; then
      continue
    fi
    if value="$(cd "$value" 2>/dev/null && pwd -P)"; then
      if [[ -f "$value/ops/capabilities.runtime.yaml" ]]; then
        printf '%s\n' "$value"
        return 0
      fi
    fi
  done

  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

spine_runtime_prepare_managed_worktree() {
  local control_root="$1"
  local runtime_root="$control_root"

  if [[ -z "$control_root" || ! -e "$control_root/.git" ]]; then
    echo "runtime-managed-worktree FAIL: invalid control root: $control_root" >&2
    return 1
  fi

  if [[ ! -x "$runtime_root/bin/ops" ]]; then
    echo "runtime-managed-worktree FAIL: missing scheduler ops runner at $runtime_root/bin/ops" >&2
    return 1
  fi

  printf '%s\n' "$runtime_root"
}

spine_runtime_activate_managed_worktree() {
  local control_root="$1"
  local runtime_root=""

  runtime_root="$(spine_runtime_prepare_managed_worktree "$control_root")" || return 1

  export SPINE_CONTROL_ROOT="${SPINE_CONTROL_ROOT:-$control_root}"
  export SPINE_RUNTIME_ACTIVE_ROOT="$runtime_root"
  export SPINE_ROOT="$runtime_root"
  export SPINE_TARGET_REPO="$runtime_root"
  export SPINE_REPO="$runtime_root"
  export SPINE_CODE="$runtime_root"

  cd "$runtime_root"
}

spine_runtime_refresh_managed_worktree() {
  local control_root="$1"
  local runtime_root="${SPINE_RUNTIME_ACTIVE_ROOT:-}"
  if [[ -z "$runtime_root" ]]; then
    runtime_root="$(spine_runtime_prepare_managed_worktree "$control_root")" || return 1
  fi
  printf '%s\n' "$runtime_root"
}
