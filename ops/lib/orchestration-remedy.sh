#!/usr/bin/env bash
set -euo pipefail

orchestration_remedy_default_lane() {
  printf '%s\n' "${SPINE_ORCHESTRATION_DEFAULT_LANE:-D}"
}

orchestration_remedy_worker_lane_entry() {
  local loop_id="${1:-}"
  local tool="${2:-claude}"
  local lane

  [[ -n "$loop_id" ]] || {
    echo "ERROR: loop_id required" >&2
    return 2
  }

  lane="$(orchestration_remedy_default_lane)"
  printf './bin/ops terminal launch --loop %s --role lane-worker --lane %s --tool %s\n' \
    "$loop_id" "$lane" "$tool"
}

orchestration_remedy_compact() {
  local loop_id="${1:-}"
  local tool="${2:-claude}"
  local cmd

  cmd="$(orchestration_remedy_worker_lane_entry "$loop_id" "$tool")"
  cat <<EOF
⚠️  This loop uses orchestrator_subagents mode.
   To enter a worker lane, open a new terminal:
   $cmd
EOF
}
