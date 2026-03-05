#!/usr/bin/env bash
# TRIAGE: classify lifecycle ownership with worktree.lifecycle.reconcile, then close
# explicitly. D48 is non-destructive and lifecycle-aware.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SPINE_REPO="${SPINE_REPO:-$(git -C "$SPINE_CODE" rev-parse --show-toplevel 2>/dev/null || echo "$SPINE_CODE")}"
SCRIPT="$SPINE_REPO/ops/plugins/ops/bin/worktree-lifecycle-reconcile"

if [[ ! -x "$SCRIPT" ]]; then
  echo "D48 FAIL: missing lifecycle reconcile script: $SCRIPT" >&2
  exit 1
fi

exec "$SCRIPT" --gate
