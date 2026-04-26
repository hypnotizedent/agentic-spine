#!/usr/bin/env bash
# git-lock.sh - typed process lock for git-mutating ops commands
#
# Supports typed locks so independent subsystems can operate concurrently.
# Usage: acquire_git_lock [type]
#   type: proposals | orchestration | gaps | infra  (or any custom name)
#   no argument: uses global git.lock (backward compat)
#
# TTL: locks older than GIT_LOCK_TTL seconds are only auto-recovered when owner
# PID is missing/dead. Live owners are never reclaimed by TTL.
#
set -euo pipefail

# Derive ROOT from script location, ignoring ambient SPINE_REPO leak
# (ambient env can point to wrong worktree/checkout from previous operations)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/ops/lib/runtime-paths.sh"
# Set SPINE_CODE explicitly before calling resolve, so it uses script-derived root
export SPINE_CODE="$ROOT"
spine_runtime_resolve_paths
if [[ -f "$ROOT/ops/lib/passive-friction-capture.sh" ]]; then
  source "$ROOT/ops/lib/passive-friction-capture.sh"
fi

LOCKS_DIR="${SPINE_LOCKS:?SPINE_LOCKS must be set — source runtime-paths.sh first}"
GIT_LOCK_TTL="${GIT_LOCK_TTL:-300}"

_GIT_LOCK_DIR=""

_git_lock_emit_retry_hint() {
  local lock_name="${1:-git.lock}"
  if declare -F auto_file_lock_retry >/dev/null 2>&1; then
    auto_file_lock_retry "$lock_name" || true
  fi
}

_git_lock_proc_start_ticks() {
  local pid="${1:-}"
  [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] || return 1
  [[ -r "/proc/$pid/stat" ]] || return 1

  awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || return 1
}

_git_lock_proc_start_epoch() {
  local pid="${1:-}"
  local start_ticks=""
  local boot_epoch=""
  local hz=""

  start_ticks="$(_git_lock_proc_start_ticks "$pid" 2>/dev/null || true)"
  [[ -n "$start_ticks" && "$start_ticks" =~ ^[0-9]+$ ]] || return 1

  boot_epoch="$(awk '/^btime / {print $2; exit}' /proc/stat 2>/dev/null || true)"
  [[ -n "$boot_epoch" && "$boot_epoch" =~ ^[0-9]+$ ]] || return 1

  hz="$(getconf CLK_TCK 2>/dev/null || true)"
  [[ -n "$hz" && "$hz" =~ ^[0-9]+$ ]] || hz=100

  awk -v boot="$boot_epoch" -v ticks="$start_ticks" -v hz="$hz" 'BEGIN { printf "%d\n", boot + int(ticks / hz) }' 2>/dev/null || return 1
}

acquire_git_lock() {
  local lock_type="${1:-}"
  local lock_name="git.lock"
  [[ -n "$lock_type" ]] && lock_name="git.${lock_type}.lock"
  _GIT_LOCK_DIR="${LOCKS_DIR}/${lock_name}"
  local pid_file="${_GIT_LOCK_DIR}/pid"
  local ts_file="${_GIT_LOCK_DIR}/created_at_epoch"
  local start_file="${_GIT_LOCK_DIR}/owner_start_ticks"
  local owner_start_ticks=""
  owner_start_ticks="$(_git_lock_proc_start_ticks "$$" 2>/dev/null || true)"

  mkdir -p "$LOCKS_DIR"
  if mkdir "$_GIT_LOCK_DIR" 2>/dev/null; then
    echo "$$" >"$pid_file" 2>/dev/null || true
    date +%s >"$ts_file" 2>/dev/null || true
    [[ -n "$owner_start_ticks" ]] && echo "$owner_start_ticks" >"$start_file" 2>/dev/null || true
    trap release_git_lock EXIT INT TERM
    return 0
  fi

  local old_pid=""
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  local created_epoch=""
  created_epoch="$(cat "$ts_file" 2>/dev/null || true)"
  local old_start_ticks=""
  old_start_ticks="$(cat "$start_file" 2>/dev/null || true)"
  local now_epoch
  now_epoch="$(date +%s)"
  local age=0
  if [[ -n "$created_epoch" && "$created_epoch" =~ ^[0-9]+$ ]]; then
    age=$(( now_epoch - created_epoch ))
  fi

  local owner_alive=0
  if [[ -n "$old_pid" && "$old_pid" =~ ^[0-9]+$ ]] && ps -p "$old_pid" >/dev/null 2>&1; then
    owner_alive=1
    if [[ -n "$old_start_ticks" && "$old_start_ticks" =~ ^[0-9]+$ ]]; then
      local current_start_ticks=""
      current_start_ticks="$(_git_lock_proc_start_ticks "$old_pid" 2>/dev/null || true)"
      if [[ -z "$current_start_ticks" || "$current_start_ticks" != "$old_start_ticks" ]]; then
        owner_alive=0
      fi
    elif [[ -n "$created_epoch" && "$created_epoch" =~ ^[0-9]+$ ]]; then
      local current_start_epoch=""
      current_start_epoch="$(_git_lock_proc_start_epoch "$old_pid" 2>/dev/null || true)"
      if [[ -n "$current_start_epoch" && "$current_start_epoch" -gt "$created_epoch" ]]; then
        owner_alive=0
      fi
    fi
  fi

  local stale=0
  if (( owner_alive == 0 )); then
    if [[ -n "$old_pid" ]]; then
      stale=1
    elif [[ -n "$created_epoch" && "$created_epoch" =~ ^[0-9]+$ ]] && (( age > GIT_LOCK_TTL )); then
      stale=1
    fi
  fi

  if (( stale == 1 )); then
    echo "INFO: Recovering stale ${lock_name} (pid=${old_pid:-?} age=${age}s ttl=${GIT_LOCK_TTL}s)" >&2
    rm -rf "$_GIT_LOCK_DIR" 2>/dev/null || true
    if mkdir "$_GIT_LOCK_DIR" 2>/dev/null; then
      echo "$$" >"$pid_file" 2>/dev/null || true
      date +%s >"$ts_file" 2>/dev/null || true
      [[ -n "$owner_start_ticks" ]] && echo "$owner_start_ticks" >"$start_file" 2>/dev/null || true
      trap release_git_lock EXIT INT TERM
      return 0
    fi
  fi

  if (( owner_alive == 1 )); then
    _git_lock_emit_retry_hint "$lock_name"
    echo "STOP: Another git-mutating ops command is running (lock: ${lock_name} pid=$old_pid age=${age}s)" >&2
    echo "Remedy: retry after the live owner exits; inspect it with: ps -p $old_pid -o pid=,etime=,command=" >&2
    return 1
  fi

  _git_lock_emit_retry_hint "$lock_name"
  echo "STOP: Unable to acquire ${lock_name}" >&2
  echo "Remedy: rerun the same governed command; if the prior owner is gone, stale-lock recovery will reclaim it automatically." >&2
  return 1
}

release_git_lock() {
  [[ -n "${_GIT_LOCK_DIR:-}" ]] && rm -rf "$_GIT_LOCK_DIR" 2>/dev/null || true
}
