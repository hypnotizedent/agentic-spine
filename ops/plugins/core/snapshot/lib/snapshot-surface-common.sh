#!/usr/bin/env bash

_SNAPSHOT_SURFACE_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_SNAPSHOT_SURFACE_LIB_DIR" == "${BASH_SOURCE}" ]] && _SNAPSHOT_SURFACE_LIB_DIR="$(pwd)"
_SNAPSHOT_SURFACE_CONTROL_ROOT="$(cd "$_SNAPSHOT_SURFACE_LIB_DIR/../../../../.." && pwd)"
source "$_SNAPSHOT_SURFACE_CONTROL_ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

snapshot_surface_usage_fallback() {
  cat <<'USAGE'
Flags:
  --apply               Write tracked projection binding.
  --check               Read-only mode (default): write runtime state only.
  --state-path <path>   Override output path (defaults to runtime state path).
USAGE
}

snapshot_surface_file_hash() {
  local path="$1"
  if [[ -f "$path" ]]; then
    shasum -a 256 "$path" | awk '{print $1}'
    return
  fi
  echo "missing"
}

snapshot_surface_resolve_root() {
  spine_resolve_target_repo
}

snapshot_surface_runtime_output_path() {
  local root="$1"
  local tracked_rel="$2"
  printf '%s/runtime/domain-state/snapshots/%s\n' "$root" "$(basename "$tracked_rel")"
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

snapshot_surface_yaml_semantic_equal() {
  local left="$1"
  local right="$2"
  python3 - "$left" "$right" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

IGNORED_KEYS = {"generated", "generated_at", "generated_at_utc", "updated_at", "last_snapshot"}


def normalize(value):
    if isinstance(value, dict):
        return {
            key: normalize(item)
            for key, item in value.items()
            if key not in IGNORED_KEYS
        }
    if isinstance(value, list):
        return [normalize(item) for item in value]
    return value


def load(path_str: str):
    path = Path(path_str)
    if not path.is_file():
        raise FileNotFoundError(path)
    with path.open("r", encoding="utf-8") as handle:
        return normalize(yaml.safe_load(handle))


left = load(sys.argv[1])
right = load(sys.argv[2])
raise SystemExit(0 if left == right else 1)
PY
}

snapshot_surface_parse_common_args() {
  local tracked_rel="$1"
  shift

  SNAPSHOT_SURFACE_TRACKED_REL="$tracked_rel"
  SNAPSHOT_SURFACE_MODE="check"
  SNAPSHOT_SURFACE_TRACKED_OUTPUT="$SNAPSHOT_SURFACE_ROOT/$tracked_rel"
  SNAPSHOT_SURFACE_RUNTIME_OUTPUT_DEFAULT="$(snapshot_surface_runtime_output_path "$SNAPSHOT_SURFACE_ROOT" "$tracked_rel")"
  SNAPSHOT_SURFACE_OUTPUT="$SNAPSHOT_SURFACE_RUNTIME_OUTPUT_DEFAULT"

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        SNAPSHOT_SURFACE_MODE="apply"
        SNAPSHOT_SURFACE_OUTPUT="$SNAPSHOT_SURFACE_TRACKED_OUTPUT"
        shift
        ;;
      --check)
        SNAPSHOT_SURFACE_MODE="check"
        SNAPSHOT_SURFACE_OUTPUT="$SNAPSHOT_SURFACE_RUNTIME_OUTPUT_DEFAULT"
        shift
        ;;
      --state-path|--output)
        SNAPSHOT_SURFACE_OUTPUT="${2:-}"
        shift 2
        ;;
      -h|--help)
        if declare -F usage >/dev/null 2>&1; then
          usage
        else
          snapshot_surface_usage_fallback
        fi
        exit 0
        ;;
      *)
        SNAPSHOT_SURFACE_REMAINING_ARGS+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "${SNAPSHOT_SURFACE_OUTPUT:-}" ]]; then
    echo "$(basename "$0") FAIL: output path cannot be empty" >&2
    exit 1
  fi

  if [[ "$SNAPSHOT_SURFACE_MODE" == "check" && "$SNAPSHOT_SURFACE_OUTPUT" == "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" ]]; then
    echo "$(basename "$0") FAIL: check mode cannot write tracked binding: $SNAPSHOT_SURFACE_TRACKED_OUTPUT" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$SNAPSHOT_SURFACE_OUTPUT")"
  SNAPSHOT_SURFACE_TRACKED_HASH_BEFORE="$(snapshot_surface_file_hash "$SNAPSHOT_SURFACE_TRACKED_OUTPUT")"
}

snapshot_surface_init() {
  local tracked_rel="$1"
  shift
  SNAPSHOT_SURFACE_REMAINING_ARGS=()
  SNAPSHOT_SURFACE_ROOT="$(snapshot_surface_resolve_root)"
  snapshot_surface_parse_common_args "$tracked_rel" "$@"
}

snapshot_surface_finalize() {
  local staged_path="$1"

  if [[ "$SNAPSHOT_SURFACE_MODE" == "apply" && "$SNAPSHOT_SURFACE_OUTPUT" == "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" ]]; then
    if [[ -f "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" ]] && snapshot_surface_yaml_semantic_equal "$SNAPSHOT_SURFACE_TRACKED_OUTPUT" "$staged_path"; then
      SNAPSHOT_SURFACE_FINAL_ACTION="semantic-noop"
      return 0
    fi
  fi

  cp "$staged_path" "$SNAPSHOT_SURFACE_OUTPUT"
  SNAPSHOT_SURFACE_FINAL_ACTION="wrote"
}

snapshot_surface_assert_tracked_unchanged_in_check_mode() {
  if [[ "$SNAPSHOT_SURFACE_MODE" != "check" ]]; then
    return 0
  fi
  local tracked_hash_after
  tracked_hash_after="$(snapshot_surface_file_hash "$SNAPSHOT_SURFACE_TRACKED_OUTPUT")"
  if [[ "$SNAPSHOT_SURFACE_TRACKED_HASH_BEFORE" != "$tracked_hash_after" ]]; then
    echo "$(basename "$0") FAIL: tracked binding mutated in check mode: $SNAPSHOT_SURFACE_TRACKED_OUTPUT" >&2
    exit 1
  fi
}
