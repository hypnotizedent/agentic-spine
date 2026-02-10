#!/usr/bin/env bash
# git-lock.sh - coarse process lock for git-mutating ops commands
#
# Goal: prevent concurrent agent sessions from mutating the repo at the same time.
# This is the simplest "single-writer" contract to eliminate split-brain races.
#
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
LOCKS_DIR="${SPINE_REPO}/mailroom/state/locks"
LOCK_DIR="${LOCKS_DIR}/git.lock"
PID_FILE="${LOCK_DIR}/pid"

acquire_git_lock() {
  mkdir -p "$LOCKS_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" >"$PID_FILE" 2>/dev/null || true
    trap release_git_lock EXIT INT TERM
    return 0
  fi

  # Lock exists. If the PID is gone, treat as stale and recover.
  local old_pid=""
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && ps -p "$old_pid" >/dev/null 2>&1; then
    echo "STOP: Another git-mutating ops command is running (lock: $LOCK_DIR pid=$old_pid)" >&2
    return 1
  fi

  # Stale lock.
  rm -rf "$LOCK_DIR" 2>/dev/null || true
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" >"$PID_FILE" 2>/dev/null || true
    trap release_git_lock EXIT INT TERM
    return 0
  fi

  echo "STOP: Unable to acquire git lock: $LOCK_DIR" >&2
  return 1
}

release_git_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
}

