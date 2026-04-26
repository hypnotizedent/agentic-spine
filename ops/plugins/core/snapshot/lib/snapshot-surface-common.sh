#!/usr/bin/env bash
# snapshot-surface-common.sh — Shared init/finalize for snapshot-surface scripts.
_SNAPSHOT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SNAPSHOT_REPO_ROOT="$(cd "$_SNAPSHOT_LIB_DIR/../../../../.." && pwd)"

snapshot_surface_runtime_output_path() {
  local root="$1"
  local tracked_rel="$2"
  local basename
  basename="$(basename "$tracked_rel")"
  if declare -f spine_resolve_domain_state >/dev/null 2>&1; then
    spine_resolve_domain_state "snapshots/$basename"
    return 0
  fi
  local state_root="${SPINE_STATE:-$HOME/code/.runtime/spine/state}"
  printf '%s/domain-state/snapshots/%s\n' "$state_root" "$basename"
}

snapshot_surface_resolve_source_path() {
  local root="$1"
  local tracked_rel="$2"
  local runtime_path
  runtime_path="$(snapshot_surface_runtime_output_path "$root" "$tracked_rel")"
  if [[ -f "$runtime_path" ]]; then
    printf '%s\n' "$runtime_path"
    return 0
  fi
  printf '%s/%s\n' "$root" "$tracked_rel"
}

snapshot_surface_init() {
  local tracked_rel="$1"
  shift

  SNAPSHOT_SURFACE_ROOT="${SPINE_ROOT:-${SPINE_TARGET_REPO:-$_SNAPSHOT_REPO_ROOT}}"
  SNAPSHOT_SURFACE_TRACKED_OUTPUT="$SNAPSHOT_SURFACE_ROOT/$tracked_rel"
  SNAPSHOT_SURFACE_MODE="check"
  SNAPSHOT_SURFACE_OUTPUT=""
  SNAPSHOT_SURFACE_REMAINING_ARGS=()
  SNAPSHOT_SURFACE_FINAL_ACTION=""

  local runtime_paths="$SNAPSHOT_SURFACE_ROOT/ops/lib/runtime-paths.sh"
  if [[ -f "$runtime_paths" ]]; then
    source "$runtime_paths"
    spine_runtime_resolve_paths
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) SNAPSHOT_SURFACE_MODE="apply"; shift ;;
      --check) SNAPSHOT_SURFACE_MODE="check"; shift ;;
      --state-path|--output) SNAPSHOT_SURFACE_OUTPUT="${2:-}"; shift 2 ;;
      -h|--help) SNAPSHOT_SURFACE_REMAINING_ARGS+=("$1"); shift ;;
      --) shift ;;
      *) SNAPSHOT_SURFACE_REMAINING_ARGS+=("$1"); shift ;;
    esac
  done

  if [[ "$SNAPSHOT_SURFACE_MODE" == "apply" ]]; then
    SNAPSHOT_SURFACE_OUTPUT="$SNAPSHOT_SURFACE_TRACKED_OUTPUT"
  elif [[ -z "$SNAPSHOT_SURFACE_OUTPUT" ]]; then
    SNAPSHOT_SURFACE_OUTPUT="$(snapshot_surface_runtime_output_path "$SNAPSHOT_SURFACE_ROOT" "$tracked_rel")"
  fi

  mkdir -p "$(dirname "$SNAPSHOT_SURFACE_OUTPUT")" 2>/dev/null || true
  mkdir -p "$(dirname "$SNAPSHOT_SURFACE_TRACKED_OUTPUT")" 2>/dev/null || true

  if [[ -f "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" ]]; then
    _SNAPSHOT_TRACKED_HASH_BEFORE="$(shasum -a 256 "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" | awk '{print $1}')"
  else
    _SNAPSHOT_TRACKED_HASH_BEFORE=""
  fi

  export SNAPSHOT_SURFACE_ROOT SNAPSHOT_SURFACE_MODE
  export SNAPSHOT_SURFACE_TRACKED_OUTPUT SNAPSHOT_SURFACE_OUTPUT
}

snapshot_surface_finalize() {
  local staged_file="$1"
  [[ -f "$staged_file" ]] || { echo "snapshot_surface_finalize: staged file missing: $staged_file" >&2; return 1; }
  cp "$staged_file" "$SNAPSHOT_SURFACE_OUTPUT"
  SNAPSHOT_SURFACE_FINAL_ACTION="wrote"
}

snapshot_surface_assert_tracked_unchanged_in_check_mode() {
  [[ "$SNAPSHOT_SURFACE_MODE" == "check" ]] || return 0
  [[ -f "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" ]] || return 0

  local hash_after
  hash_after="$(shasum -a 256 "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" | awk '{print $1}')"

  if [[ -n "$_SNAPSHOT_TRACKED_HASH_BEFORE" && "$_SNAPSHOT_TRACKED_HASH_BEFORE" != "$hash_after" ]]; then
    echo "FAIL: tracked binding mutated in check mode: $SNAPSHOT_SURFACE_TRACKED_OUTPUT" >&2
    return 1
  fi

  return 0
}
