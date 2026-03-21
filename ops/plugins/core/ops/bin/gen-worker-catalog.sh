#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
source "$CONTROL_ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
ROOT="${SPINE_TARGET_REPO:-$CONTROL_ROOT}"
LOCK_HELD=0
CHECK_MODE=0
APPLY_MODE=0
EXTRA_ARGS=()

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
  case "$arg" in
    --check) CHECK_MODE=1 ;;
    --apply) APPLY_MODE=1 ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

if [[ "$APPLY_MODE" -eq 1 && "$CHECK_MODE" -eq 1 ]]; then
  echo "gen-worker-catalog FAIL: --apply and --check are mutually exclusive" >&2
  exit 1
fi

if [[ "$APPLY_MODE" -eq 0 ]]; then
  CHECK_MODE=1
fi

if [[ "$APPLY_MODE" -eq 1 ]]; then
  if [[ "${SPINE_GIT_LOCK_HELD:-0}" != "1" ]]; then
    acquire_git_lock terminal_worker_runtime || exit 1
    LOCK_HELD=1
    export SPINE_GIT_LOCK_HELD=1
  fi

  spine_tx_init
  spine_tx_track "$ROOT/ops/bindings/terminal.worker.catalog.yaml"
  spine_tx_track "$ROOT/docs/reference/generated/worker-usage"
fi

CMD=(python3 "$ROOT/ops/plugins/core/ops/bin/gen-terminal-worker-runtime-v2.py" --root "$ROOT" --target catalog --target usage)
if [[ "$APPLY_MODE" -eq 1 ]]; then
  CMD+=(--apply)
else
  CMD+=(--check)
fi
CMD+=("${EXTRA_ARGS[@]}")

if ! "${CMD[@]}"; then
  if [[ "$APPLY_MODE" -eq 1 ]]; then
    spine_tx_rollback
  fi
  exit 1
fi
