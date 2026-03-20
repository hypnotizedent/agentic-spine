#!/usr/bin/env bash
# TRIAGE: classify lifecycle ownership with worktree.lifecycle.reconcile, then close
# explicitly. D48 is non-destructive and lifecycle-aware.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT="$SPINE_CODE/ops/plugins/core/ops/bin/worktree-lifecycle-reconcile"

if [[ ! -x "$SCRIPT" ]]; then
  echo "D48 FAIL: missing lifecycle reconcile script: $SCRIPT" >&2
  exit 1
fi

exec "$SCRIPT" --gate
