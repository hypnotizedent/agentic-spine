#!/usr/bin/env bash
set -euo pipefail

SPINE_TX_TMPDIR="${SPINE_TX_TMPDIR:-}"
declare -ag SPINE_TX_TRACKED=()

spine_tx_init() {
  SPINE_TX_TMPDIR="$(mktemp -d)"
  SPINE_TX_TRACKED=()
}

spine_tx_track() {
  local target="$1"
  local entry_type="missing"
  local backup_path=""

  [[ -n "${SPINE_TX_TMPDIR:-}" ]] || {
    echo "spine_tx_track: transaction not initialized" >&2
    return 1
  }

  if [[ -e "$target" ]]; then
    backup_path="$SPINE_TX_TMPDIR/$(printf '%03d' "${#SPINE_TX_TRACKED[@]}").bak"
    cp -R "$target" "$backup_path"
    entry_type="present"
  fi

  SPINE_TX_TRACKED+=("$target::$entry_type::$backup_path")
}

spine_tx_rollback() {
  local i entry target entry_type backup_path
  for ((i=${#SPINE_TX_TRACKED[@]} - 1; i>=0; i--)); do
    entry="${SPINE_TX_TRACKED[$i]}"
    target="${entry%%::*}"
    entry_type="${entry#*::}"
    entry_type="${entry_type%%::*}"
    backup_path="${entry##*::}"

    if [[ "$entry_type" == "present" ]]; then
      rm -rf "$target"
      cp -R "$backup_path" "$target"
    else
      rm -rf "$target"
    fi
  done
}

spine_tx_cleanup() {
  if [[ -n "${SPINE_TX_TMPDIR:-}" && -d "${SPINE_TX_TMPDIR:-}" ]]; then
    rm -rf "$SPINE_TX_TMPDIR"
  fi
  SPINE_TX_TMPDIR=""
  SPINE_TX_TRACKED=()
}
