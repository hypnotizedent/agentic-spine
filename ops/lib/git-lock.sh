#!/usr/bin/env bash
# git-lock.sh - typed process lock for git-mutating ops commands
#
# Supports typed locks so independent subsystems can operate concurrently.
# Usage: acquire_git_lock [type]
#   type: proposals | orchestration | gaps | infra  (or any custom name)
#   no argument: uses global git.lock (backward compat)
#
# TTL: locks older than GIT_LOCK_TTL seconds with a dead PID are auto-recovered.
#
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
LOCKS_DIR="${SPINE_REPO}/mailroom/state/locks"
GIT_LOCK_TTL="${GIT_LOCK_TTL:-300}"

_GIT_LOCK_DIR=""

acquire_git_lock() {
  local lock_type="${1:-}"
  local lock_name="git.lock"
  [[ -n "$lock_type" ]] && lock_name="git.${lock_type}.lock"
  _GIT_LOCK_DIR="${LOCKS_DIR}/${lock_name}"
  local pid_file="${_GIT_LOCK_DIR}/pid"
  local ts_file="${_GIT_LOCK_DIR}/created_at_epoch"

  mkdir -p "$LOCKS_DIR"
  if mkdir "$_GIT_LOCK_DIR" 2>/dev/null; then
    echo "$$" >"$pid_file" 2>/dev/null || true
    date +%s >"$ts_file" 2>/dev/null || true
    trap release_git_lock EXIT INT TERM
    return 0
  fi

  # Lock exists — check staleness.
  local old_pid=""
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  local created_epoch=""
  created_epoch="$(cat "$ts_file" 2>/dev/null || true)"
  local now_epoch
  now_epoch="$(date +%s)"
  local age=0
  if [[ -n "$created_epoch" && "$created_epoch" =~ ^[0-9]+$ ]]; then
    age=$(( now_epoch - created_epoch ))
  fi

  local stale=0
  # PID dead → stale
  if [[ -n "$old_pid" ]] && ! ps -p "$old_pid" >/dev/null 2>&1; then
    stale=1
  fi
  # TTL expired → stale (only when timestamp available)
  if [[ -n "$created_epoch" && "$created_epoch" =~ ^[0-9]+$ ]] && (( age > GIT_LOCK_TTL )); then
    stale=1
  fi

  if (( stale == 1 )); then
    echo "INFO: Recovering stale ${lock_name} (pid=${old_pid:-?} age=${age}s ttl=${GIT_LOCK_TTL}s)" >&2
    rm -rf "$_GIT_LOCK_DIR" 2>/dev/null || true
    if mkdir "$_GIT_LOCK_DIR" 2>/dev/null; then
      echo "$$" >"$pid_file" 2>/dev/null || true
      date +%s >"$ts_file" 2>/dev/null || true
      trap release_git_lock EXIT INT TERM
      return 0
    fi
  fi

  if [[ -n "$old_pid" ]] && ps -p "$old_pid" >/dev/null 2>&1; then
    echo "STOP: Another git-mutating ops command is running (lock: ${lock_name} pid=$old_pid age=${age}s)" >&2
    return 1
  fi

  echo "STOP: Unable to acquire ${lock_name}" >&2
  return 1
}

release_git_lock() {
  [[ -n "${_GIT_LOCK_DIR:-}" ]] && rm -rf "$_GIT_LOCK_DIR" 2>/dev/null || true
}
