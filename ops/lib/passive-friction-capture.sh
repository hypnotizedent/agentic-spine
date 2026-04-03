#!/usr/bin/env bash
# passive-friction-capture.sh
#
# Automatic friction filing for common ceremony events without requiring
# explicit agent invocation. Reduces observability gap for medium/low friction.
#
# Usage:
#   source "$SPINE_REPO/ops/lib/passive-friction-capture.sh"
#   auto_file_friction "capability.name" "expected behavior" "actual behavior" "severity"
#
# Note: Friction is filed asynchronously to avoid blocking the primary operation.

auto_file_friction() {
  local capability="${1:?auto_file_friction: capability required}"
  local expected="${2:?auto_file_friction: expected required}"
  local actual="${3:?auto_file_friction: actual required}"
  local severity="${4:-medium}"  # default to medium

  # Skip if passive capture is disabled
  [[ "${OPS_PASSIVE_FRICTION_DISABLED:-0}" == "1" ]] && return 0

  # Skip if we're in a test/CI context
  [[ -n "${OPS_TEST_MODE:-}" || -n "${CI:-}" ]] && return 0

  local friction_ingest="${SPINE_REPO:-}/ops/plugins/core/lifecycle/bin/friction-ingest"
  [[ -x "$friction_ingest" ]] || return 0  # silently skip if friction-ingest unavailable

  # File friction in background to avoid blocking
  (
    # Suppress all output to avoid polluting the calling script's stderr/stdout
    "$friction_ingest" \
      --capability "$capability" \
      --expected "$expected" \
      --actual "$actual" \
      --severity "$severity" \
      --source "passive_capture" \
      --auto-reconcile \
      --json >/dev/null 2>&1 &
  )

  # Return immediately without waiting for background job
  return 0
}

# Auto-file friction for gaps.close projection failure
auto_file_gap_projection_partial() {
  auto_file_friction \
    "gaps.close.projection" \
    "gaps.close should auto-project to YAML or clearly indicate deferred state" \
    "gap closed in SQLite but YAML projection failed; manual project step required" \
    "medium"
}

# Auto-file friction for lock contention/retry
auto_file_lock_retry() {
  local operation="${1:-lifecycle_mutation}"
  auto_file_friction \
    "lock.retry" \
    "lifecycle mutation locks should not require manual retry/backoff" \
    "lock acquisition failed for $operation; manual retry or sleep required" \
    "low"
}

# Auto-file friction for staleness window (query contradicts recent mutation)
auto_file_staleness_contradiction() {
  local capability="${1:-lifecycle.query}"
  local detail="${2:-query returned stale data}"
  auto_file_friction \
    "$capability.staleness" \
    "queries should reflect recent mutations within reasonable window" \
    "$detail" \
    "low"
}

# Auto-file friction for ceremony override usage
auto_file_ceremony_override() {
  local override_type="${1:-main_mutation}"  # main_mutation, force_close, dod_override
  local context="${2:-override required for normal operation}"
  auto_file_friction \
    "ceremony.override.$override_type" \
    "normal operations should not require ceremony overrides" \
    "$context" \
    "low"
}

# Export functions for use in calling scripts
export -f auto_file_friction
export -f auto_file_gap_projection_partial
export -f auto_file_lock_retry
export -f auto_file_staleness_contradiction
export -f auto_file_ceremony_override
