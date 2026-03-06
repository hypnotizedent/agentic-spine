#!/usr/bin/env bash
set -euo pipefail
ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LOCK_HELD=0
CHECK_MODE=0

source "$ROOT/ops/lib/git-lock.sh"
source "$ROOT/ops/lib/governed-write-transaction.sh"

cleanup() {
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    release_git_lock || true
  fi
  spine_tx_cleanup
  return 0
}

trap cleanup EXIT INT TERM

for arg in "$@"; do
  if [[ "$arg" == "--check" ]]; then
    CHECK_MODE=1
    break
  fi
done

if [[ "$CHECK_MODE" -eq 0 ]]; then
  if [[ "${SPINE_GIT_LOCK_HELD:-0}" != "1" ]]; then
    acquire_git_lock terminal_worker_runtime || exit 1
    LOCK_HELD=1
    export SPINE_GIT_LOCK_HELD=1
  fi

  spine_tx_init
  spine_tx_track "$ROOT/ops/bindings/routing.dispatch.yaml"
fi

if ! python3 "$ROOT/bin/generators/gen-terminal-worker-runtime-v2.py" --target dispatch "$@"; then
  if [[ "$CHECK_MODE" -eq 0 ]]; then
    spine_tx_rollback
  fi
  exit 1
fi
