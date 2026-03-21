#!/usr/bin/env bash

_HA_SNAPSHOT_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_HA_SNAPSHOT_LIB_DIR" == "${BASH_SOURCE}" ]] && _HA_SNAPSHOT_LIB_DIR="$(pwd)"
_HA_SNAPSHOT_CONTROL_ROOT="$(cd "$_HA_SNAPSHOT_LIB_DIR/../../../../.." && pwd)"
source "$_HA_SNAPSHOT_CONTROL_ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

ha_snapshot_usage_fallback() {
  cat <<'USAGE'
Flags:
  --apply               Write tracked projection binding.
  --check               Read-only mode (default): write runtime state only.
  --state-path <path>   Override output path (defaults to runtime state path).
USAGE
}

ha_snapshot_file_hash() {
  local path="$1"
  if [[ -f "$path" ]]; then
    shasum -a 256 "$path" | awk '{print $1}'
    return
  fi
  echo "missing"
}

ha_snapshot_resolve_root() {
  spine_resolve_target_repo
}

ha_snapshot_runtime_output_path() {
  local root="$1"
  local tracked_rel="$2"
  printf '%s/runtime/domain-state/snapshots/%s\n' "$root" "$(basename "$tracked_rel")"
}

ha_snapshot_resolve_source_path() {
  local root="$1"
  local tracked_rel="$2"
  local runtime_path
  runtime_path="$(ha_snapshot_runtime_output_path "$root" "$tracked_rel")"
  if [[ -f "$runtime_path" ]]; then
    printf '%s\n' "$runtime_path"
    return 0
  fi
  printf '%s/%s\n' "$root" "$tracked_rel"
}

ha_snapshot_parse_common_args() {
  local tracked_rel="$1"
  shift

  HA_SNAPSHOT_MODE="check"
  HA_SNAPSHOT_TRACKED_OUTPUT="$HA_SNAPSHOT_ROOT/ops/bindings/$tracked_rel"
  HA_SNAPSHOT_RUNTIME_OUTPUT_DEFAULT="$(ha_snapshot_runtime_output_path "$HA_SNAPSHOT_ROOT" "$tracked_rel")"
  HA_SNAPSHOT_OUTPUT="$HA_SNAPSHOT_RUNTIME_OUTPUT_DEFAULT"

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        HA_SNAPSHOT_MODE="apply"
        HA_SNAPSHOT_OUTPUT="$HA_SNAPSHOT_TRACKED_OUTPUT"
        shift
        ;;
      --check)
        HA_SNAPSHOT_MODE="check"
        HA_SNAPSHOT_OUTPUT="$HA_SNAPSHOT_RUNTIME_OUTPUT_DEFAULT"
        shift
        ;;
      --state-path|--output)
        HA_SNAPSHOT_OUTPUT="${2:-}"
        shift 2
        ;;
      -h|--help)
        if declare -F usage >/dev/null 2>&1; then
          usage
        else
          ha_snapshot_usage_fallback
        fi
        exit 0
        ;;
      *)
        echo "$(basename "$0") FAIL: unknown arg '$1'" >&2
        if declare -F usage >/dev/null 2>&1; then
          usage >&2
        else
          ha_snapshot_usage_fallback >&2
        fi
        exit 1
        ;;
    esac
  done

  if [[ -z "$HA_SNAPSHOT_OUTPUT" ]]; then
    echo "$(basename "$0") FAIL: output path cannot be empty" >&2
    exit 1
  fi

  if [[ "$HA_SNAPSHOT_MODE" == "check" && "$HA_SNAPSHOT_OUTPUT" == "$HA_SNAPSHOT_TRACKED_OUTPUT" ]]; then
    echo "$(basename "$0") FAIL: check mode cannot write tracked binding: $HA_SNAPSHOT_TRACKED_OUTPUT" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$HA_SNAPSHOT_OUTPUT")"
  HA_SNAPSHOT_TRACKED_HASH_BEFORE="$(ha_snapshot_file_hash "$HA_SNAPSHOT_TRACKED_OUTPUT")"
}

ha_snapshot_init() {
  local tracked_rel="$1"
  shift
  HA_SNAPSHOT_ROOT="$(ha_snapshot_resolve_root)"
  ha_snapshot_parse_common_args "$tracked_rel" "$@"
}

ha_snapshot_yaml_semantic_equal() {
  local left="$1"
  local right="$2"
  python3 - "$left" "$right" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

IGNORED_KEYS = {"generated", "generated_at", "updated_at", "last_snapshot"}


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

ha_snapshot_finalize() {
  local staged_path="$1"

  if [[ "$HA_SNAPSHOT_MODE" == "apply" && "$HA_SNAPSHOT_OUTPUT" == "$HA_SNAPSHOT_TRACKED_OUTPUT" ]]; then
    if [[ -f "$HA_SNAPSHOT_TRACKED_OUTPUT" ]] && ha_snapshot_yaml_semantic_equal "$HA_SNAPSHOT_TRACKED_OUTPUT" "$staged_path"; then
      HA_SNAPSHOT_FINAL_ACTION="semantic-noop"
      return 0
    fi
  fi

  cp "$staged_path" "$HA_SNAPSHOT_OUTPUT"
  HA_SNAPSHOT_FINAL_ACTION="wrote"
}

ha_snapshot_assert_tracked_unchanged_in_check_mode() {
  if [[ "$HA_SNAPSHOT_MODE" != "check" ]]; then
    return 0
  fi
  local tracked_hash_after
  tracked_hash_after="$(ha_snapshot_file_hash "$HA_SNAPSHOT_TRACKED_OUTPUT")"
  if [[ "$HA_SNAPSHOT_TRACKED_HASH_BEFORE" != "$tracked_hash_after" ]]; then
    echo "$(basename "$0") FAIL: tracked binding mutated in check mode: $HA_SNAPSHOT_TRACKED_OUTPUT" >&2
    exit 1
  fi
}
