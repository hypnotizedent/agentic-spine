#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: reconcile gate registry + entry-surface projections.
# LaunchAgent: com.ronny.projection-reconcile

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../lib/runtime-managed-worktree.sh"
CONTROL_ROOT="$(spine_runtime_resolve_control_root "${BASH_SOURCE[0]}")"
spine_runtime_activate_managed_worktree "$CONTROL_ROOT"
RUNTIME_ROOT="${SPINE_RUNTIME_ACTIVE_ROOT}"

resolve_capability_script_path() {
  local capability_id="$1"
  local fallback_rel="$2"
  local script_rel=""
  if [[ -f "$RUNTIME_ROOT/ops/capabilities.yaml" ]]; then
    script_rel="$(
      awk -v cap="$capability_id" '
        $0 == "  " cap ":" { in_cap=1; next }
        in_cap && $0 ~ /^  [^[:space:]][^:]*:/ { exit }
        in_cap && $1 == "script_path:" { print $2; exit }
      ' "$RUNTIME_ROOT/ops/capabilities.yaml"
    )"
  fi
  [[ -n "$script_rel" && "$script_rel" != "null" ]] || script_rel="$fallback_rel"
  script_rel="${script_rel#./}"
  printf '%s\n' "$RUNTIME_ROOT/$script_rel"
}

PROJECTION_RECONCILE_CMD="$(resolve_capability_script_path "projection.reconcile" "./ops/plugins/core/docs/bin/projection-reconcile")"
source "${RUNTIME_ROOT}/ops/lib/job-wrapper.sh"

echo "[projection-reconcile] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[projection-reconcile] control_root=${CONTROL_ROOT}"
echo "[projection-reconcile] runtime_root=${RUNTIME_ROOT}"
echo "[projection-reconcile] worktree_identity=${OPS_WORKTREE_IDENTITY:-unset}"

set +e
spine_job_run \
  "projection-reconcile:projection.reconcile.dry-run" \
  "$PROJECTION_RECONCILE_CMD" --dry-run
job_rc=$?
set -e

if [[ "$job_rc" -ne 0 ]]; then
  exit "$job_rc"
fi

echo "[projection-reconcile] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
