#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# orchestration-remedy.sh - Shared orchestration remedy message generator
# ═══════════════════════════════════════════════════════════════════════════
#
# Single source of truth for orchestration entry remedies.
# Prevents duplicated, brittle remedy strings across attach/hook/launcher surfaces.
#
# Usage:
#   source "$SPINE_ROOT/ops/lib/orchestration-remedy.sh"
#   remedy=$(orchestration_remedy_worker_lane_entry "$LOOP_ID" "claude")
#   echo "$remedy"
#
# ═══════════════════════════════════════════════════════════════════════════

# Generate worker-lane entry remedy for orchestrator_subagents loops
#
# Args:
#   $1 - loop_id (required)
#   $2 - tool (optional, defaults to "claude")
#   $3 - lane (optional, defaults to "D")
#
# Returns:
#   Exact terminal launch command for entering orchestration worker lane
#
orchestration_remedy_worker_lane_entry() {
  local loop_id="${1:?loop_id required}"
  local tool="${2:-claude}"
  local lane="${3:-D}"

  # Lane D is the current default for orchestration worker lanes.
  # Rationale: D is the first worker lane in the standard DEFG sequence.
  # If you need a different lane, the orchestrator should communicate it explicitly.
  # If no orchestrator guidance exists, D is a safe first-entry default.
  #
  # This default is encoded once here instead of scattered across 3+ files.

  echo "./bin/ops terminal launch --loop ${loop_id} --role lane-worker --lane ${lane} --tool ${tool}"
}

# Generate worker-lane entry warning message for orchestrator_subagents loops
#
# Args:
#   $1 - loop_id (required)
#   $2 - tool (optional, defaults to "claude")
#   $3 - lane (optional, defaults to "D")
#
# Returns:
#   Human-readable warning with remedy command
#
orchestration_remedy_worker_lane_warning() {
  local loop_id="${1:?loop_id required}"
  local tool="${2:-claude}"
  local lane="${3:-D}"

  local remedy_cmd
  remedy_cmd="$(orchestration_remedy_worker_lane_entry "$loop_id" "$tool" "$lane")"

  cat <<EOF
⚠️  This loop uses orchestrator_subagents mode but terminal is not in orchestration lane.
   Open worker terminal: ${remedy_cmd}
EOF
}

# Generate compact orchestration remedy for shell banner output
#
# Args:
#   $1 - loop_id (required)
#   $2 - tool (optional, defaults to "claude")
#   $3 - lane (optional, defaults to "D")
#
# Returns:
#   Compact remedy message suitable for shell banners
#
orchestration_remedy_compact() {
  local loop_id="${1:?loop_id required}"
  local tool="${2:-claude}"
  local lane="${3:-D}"

  local remedy_cmd
  remedy_cmd="$(orchestration_remedy_worker_lane_entry "$loop_id" "$tool" "$lane")"

  cat <<EOF
⚠️  This loop uses orchestrator_subagents mode.
   To enter a worker lane, open a new terminal:
   ${remedy_cmd}

   To test without opening iTerm, add --dry-run to see the launch plan.
EOF
}

# Python-callable wrapper for remedy generation
#
# Usage from Python:
#   result = subprocess.run(
#       ["bash", "-c", f"source ops/lib/orchestration-remedy.sh && orchestration_remedy_worker_lane_entry {loop_id}"],
#       capture_output=True, text=True
#   )
#   remedy = result.stdout.strip()
#
# This allows Python scripts like session-v3-attach to use the same remedy source.
