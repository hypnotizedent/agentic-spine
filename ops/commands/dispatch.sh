#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops dispatch - Thin local multi-lane dispatch bridge
# ═══════════════════════════════════════════════════════════════════════════
#
# Composes the wave/packet lifecycle into a single local dispatch cycle:
#   wave start → dispatch N lanes → execute locally → ack → collect
#
# This restores the controller terminal's ability to run bounded multi-lane
# research without requiring worktrees, external subagents, or mailroom.
#
# Usage:
#   ops dispatch local --loop-id <LOOP_ID> --objective "<text>" \
#     --lane "<name>:<shell_command>" [--lane "<name>:<command>" ...]
#
# Options:
#   --loop-id <id>          Loop to attach (or SPINE_LOOP_ID env)
#   --objective "<text>"    Wave objective
#   --lane "<name>:<cmd>"   Lane name and shell command to execute (repeatable)
#   --wave-id <id>          Override wave ID (default: auto-generated)
#   --evidence-dir <path>   Override evidence output directory
#   --parallel              Execute lanes in parallel (default: serial)
#   --dry-run               Show plan without executing
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_REPO="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WAVE_CMD="$SPINE_REPO/ops/commands/wave.sh"

[[ -f "$WAVE_CMD" ]] || { echo "FATAL: wave.sh not found at $WAVE_CMD" >&2; exit 1; }

usage() {
  cat <<'EOF'
ops dispatch - Local multi-lane dispatch bridge

Subcommands:
  local    Run bounded local research dispatch via wave/packet

Usage:
  ops dispatch local --loop-id <LOOP_ID> --objective "<text>" \
    --lane "<name>:<shell_command>" [--lane "<name>:<command>" ...]

Options:
  --loop-id <id>          Loop to attach (or SPINE_LOOP_ID env)
  --objective "<text>"    Wave objective
  --lane "<name>:<cmd>"   Lane name and shell command (repeatable)
  --wave-id <id>          Override wave ID (default: auto-generated)
  --evidence-dir <path>   Override evidence output directory
  --parallel              Execute lanes in parallel (default: serial)
  --dry-run               Show plan without executing

Example:
  ops dispatch local \
    --loop-id LOOP-RESEARCH-20260408 \
    --objective "Domain binding inventory" \
    --lane "immich:find ops/bindings/domains/immich -type f" \
    --lane "ha:find ops/bindings/domains/ha -type f" \
    --lane "media:find ops/bindings/domains/media -type f"

  # Parallel execution:
  ops dispatch local --parallel \
    --loop-id LOOP-RESEARCH-20260408 \
    --objective "Domain binding inventory" \
    --lane "immich:find ops/bindings/domains/immich -type f" \
    --lane "ha:find ops/bindings/domains/ha -type f" \
    --lane "media:find ops/bindings/domains/media -type f"
EOF
}

fail() { echo "ops dispatch: $*" >&2; exit 1; }

SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  local) ;;
  -h|--help|"") usage; exit 0 ;;
  *) fail "unknown subcommand '$SUBCMD' (expected: local)" ;;
esac

# ── Parse options ─────────────────────────────────────────────────────────

LOOP_ID="${SPINE_LOOP_ID:-}"
OBJECTIVE=""
WAVE_ID=""
EVIDENCE_DIR=""
DRY_RUN=0
PARALLEL=0
LANES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --loop-id) LOOP_ID="${2:-}"; shift 2 ;;
    --objective) OBJECTIVE="${2:-}"; shift 2 ;;
    --wave-id) WAVE_ID="${2:-}"; shift 2 ;;
    --lane) LANES+=("${2:-}"); shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    --parallel) PARALLEL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --) shift; break ;;
    -*) fail "unknown flag '$1'" ;;
    *) shift ;;
  esac
done

[[ -n "$LOOP_ID" ]] || fail "missing --loop-id (or set SPINE_LOOP_ID)"
[[ -n "$OBJECTIVE" ]] || fail "missing --objective"
[[ ${#LANES[@]} -gt 0 ]] || fail "at least one --lane required"

# ── Generate wave ID ──────────────────────────────────────────────────────

if [[ -z "$WAVE_ID" ]]; then
  WAVE_ID="WAVE-LOCAL-$(TZ=UTC date '+%Y%m%d-%H%M%S' 2>/dev/null || date -u '+%Y%m%d-%H%M%S')"
fi

# ── Evidence directory ────────────────────────────────────────────────────

if [[ -z "$EVIDENCE_DIR" ]]; then
  EVIDENCE_DIR="/Users/ronnyworks/code/.evidence/spine/sessions/$WAVE_ID"
fi
mkdir -p "$EVIDENCE_DIR"

# ── Parse lanes ───────────────────────────────────────────────────────────

LANE_NAMES=()
LANE_CMDS=()

for lane_spec in "${LANES[@]}"; do
  if [[ "$lane_spec" != *":"* ]]; then
    fail "lane spec must be 'name:command', got: $lane_spec"
  fi
  name="${lane_spec%%:*}"
  cmd="${lane_spec#*:}"
  [[ -n "$name" ]] || fail "lane name empty in: $lane_spec"
  [[ -n "$cmd" ]] || fail "lane command empty in: $lane_spec"
  LANE_NAMES+=("$name")
  LANE_CMDS+=("$cmd")
done

# ── Dry run ───────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$PARALLEL" -eq 1 ]]; then
    mode="parallel"
  else
    mode="serial"
  fi
  echo "# ops dispatch local (dry-run)"
  echo "# Wave:      $WAVE_ID"
  echo "# Loop:      $LOOP_ID"
  echo "# Objective: $OBJECTIVE"
  echo "# Evidence:  $EVIDENCE_DIR"
  echo "# Mode:      $mode"
  echo "# Lanes:"
  for i in "${!LANE_NAMES[@]}"; do
    echo "#   ${LANE_NAMES[$i]}: ${LANE_CMDS[$i]}"
  done
  exit 0
fi

echo "════════════════════════════════════════════════════════════════════════"
echo "  LOCAL DISPATCH: $WAVE_ID"
echo "════════════════════════════════════════════════════════════════════════"
echo "  Loop:      $LOOP_ID"
echo "  Objective: $OBJECTIVE"
echo "  Lanes:     ${#LANE_NAMES[@]}"
if [[ "$PARALLEL" -eq 1 ]]; then
  echo "  Mode:      parallel"
else
  echo "  Mode:      serial"
fi
echo "  Evidence:  $EVIDENCE_DIR"
echo ""

# ── Step 1: Wave start ───────────────────────────────────────────────────

echo "── wave start ──────────────────────────────────────────────────────"
bash "$WAVE_CMD" start "$WAVE_ID" \
  --loop-id "$LOOP_ID" \
  --objective "$OBJECTIVE" \
  --worktree off
echo ""

# ── Step 2: Dispatch lanes and capture real dispatch IDs ─────────────────

echo "── dispatch lanes ──────────────────────────────────────────────────"
LANE_DISPATCH_IDS=()
for i in "${!LANE_NAMES[@]}"; do
  local_name="${LANE_NAMES[$i]}"
  local_cmd="${LANE_CMDS[$i]}"
  task_desc="[local-research:${local_name}] ${local_cmd}"
  dispatch_output="$(bash "$WAVE_CMD" dispatch "$WAVE_ID" \
    --lane execution \
    --task "$task_desc")"
  echo "$dispatch_output"
  # Extract real dispatch ID from "Dispatch ID: D<N>" line
  real_id="$(echo "$dispatch_output" | (grep -o 'Dispatch ID: D[0-9]*' || true) | head -1 | sed 's/Dispatch ID: //')"
  if [[ -z "$real_id" ]]; then
    fail "could not parse dispatch ID from wave.sh output for lane '${local_name}'"
  fi
  LANE_DISPATCH_IDS+=("$real_id")
  echo ""
done

# ── Step 3: Execute locally and ack ──────────────────────────────────────

# Helper: build result summary from evidence file and exit code
_build_result_summary() {
  local lane_evidence="$1"
  local lane_exit="$2"
  local lane_output
  # Read content after the --- header
  lane_output="$(sed '1,/^---$/d' "$lane_evidence")"
  local total_lines
  total_lines="$(echo "$lane_output" | wc -l | tr -d ' ')"
  local result_preview
  result_preview="$(echo "$lane_output" | head -5)"
  if [[ "$lane_exit" -eq 0 ]]; then
    echo "OK (${total_lines} lines). Preview: ${result_preview}"
  else
    echo "FAIL exit=${lane_exit} (${total_lines} lines). Preview: ${result_preview}"
  fi
}

# Helper: write evidence file for a lane
_write_lane_evidence() {
  local local_name="$1"
  local local_cmd="$2"
  local lane_exit="$3"
  local lane_evidence="$4"
  # stdin is piped lane output
  {
    echo "# Lane: $local_name"
    echo "# Command: $local_cmd"
    echo "# Exit code: $lane_exit"
    echo "# Timestamp: $(TZ=UTC date '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "---"
    cat
  } > "$lane_evidence"
}

ANY_FAILED=0

if [[ "$PARALLEL" -eq 1 ]]; then
  # ── Parallel execution ──────────────────────────────────────────────
  echo "── execute (parallel) ──────────────────────────────────────────"

  LANE_PIDS=()
  LANE_EXIT_FILES=()

  # Trap to kill background children on interrupt
  trap 'kill "${LANE_PIDS[@]}" 2>/dev/null; exit 130' INT TERM

  # Phase A: Launch all lanes as background subshells
  for i in "${!LANE_NAMES[@]}"; do
    local_name="${LANE_NAMES[$i]}"
    local_cmd="${LANE_CMDS[$i]}"
    dispatch_id="${LANE_DISPATCH_IDS[$i]}"
    lane_evidence="$EVIDENCE_DIR/lane-${local_name}.txt"
    exit_file="$EVIDENCE_DIR/.exit-${local_name}"
    LANE_EXIT_FILES+=("$exit_file")

    echo "  [$dispatch_id] ${local_name}: launched"

    (
      set +e
      lane_output="$(cd "$SPINE_REPO" && eval "$local_cmd" 2>&1)"
      lane_exit=$?
      set -e
      echo "$lane_output" | _write_lane_evidence "$local_name" "$local_cmd" "$lane_exit" "$lane_evidence"
      echo "$lane_exit" > "$exit_file"
    ) &
    LANE_PIDS+=($!)
  done
  echo ""

  # Phase B: Wait for all PIDs, capture exit codes
  echo "── waiting for lanes ───────────────────────────────────────────"
  LANE_EXITS=()
  set +e
  for i in "${!LANE_PIDS[@]}"; do
    pid="${LANE_PIDS[$i]}"
    local_name="${LANE_NAMES[$i]}"
    wait "$pid" 2>/dev/null
    # Read the exit code written by the subshell
    exit_file="${LANE_EXIT_FILES[$i]}"
    if [[ -f "$exit_file" ]]; then
      lane_exit="$(cat "$exit_file")"
      rm -f "$exit_file"
    else
      lane_exit=1
    fi
    LANE_EXITS+=("$lane_exit")
    if [[ "$lane_exit" -eq 0 ]]; then
      echo "  ${local_name}: done (exit 0)"
    else
      echo "  ${local_name}: done (exit $lane_exit) FAILED"
      ANY_FAILED=1
    fi
  done
  set -e

  # Clear the trap now that all children are done
  trap - INT TERM
  echo ""

  # Phase C: Ack all lanes sequentially
  echo "── ack ─────────────────────────────────────────────────────────"
  for i in "${!LANE_NAMES[@]}"; do
    local_name="${LANE_NAMES[$i]}"
    dispatch_id="${LANE_DISPATCH_IDS[$i]}"
    lane_evidence="$EVIDENCE_DIR/lane-${local_name}.txt"
    lane_exit="${LANE_EXITS[$i]}"

    result_text="$(_build_result_summary "$lane_evidence" "$lane_exit")"

    bash "$WAVE_CMD" ack "$WAVE_ID" \
      --dispatch "$dispatch_id" \
      --result "$result_text"
    echo ""
  done

else
  # ── Serial execution (default) ─────────────────────────────────────
  echo "── execute + ack ─────────────────────────────────────────────────"
  for i in "${!LANE_NAMES[@]}"; do
    local_name="${LANE_NAMES[$i]}"
    local_cmd="${LANE_CMDS[$i]}"
    dispatch_id="${LANE_DISPATCH_IDS[$i]}"
    lane_evidence="$EVIDENCE_DIR/lane-${local_name}.txt"

    echo "  [$dispatch_id] ${local_name}: executing..."

    set +e
    lane_output="$(cd "$SPINE_REPO" && eval "$local_cmd" 2>&1)"
    lane_exit=$?
    set -e

    # Write lane output to evidence
    echo "$lane_output" | _write_lane_evidence "$local_name" "$local_cmd" "$lane_exit" "$lane_evidence"

    result_text="$(_build_result_summary "$lane_evidence" "$lane_exit")"

    if [[ "$lane_exit" -ne 0 ]]; then
      ANY_FAILED=1
    fi

    bash "$WAVE_CMD" ack "$WAVE_ID" \
      --dispatch "$dispatch_id" \
      --result "$result_text"
    echo ""
  done
fi

# ── Step 4: Collect ──────────────────────────────────────────────────────

echo "── collect ─────────────────────────────────────────────────────────"
bash "$WAVE_CMD" collect "$WAVE_ID"
echo ""

echo "════════════════════════════════════════════════════════════════════════"
echo "  LOCAL DISPATCH COMPLETE: $WAVE_ID"
echo "  Evidence: $EVIDENCE_DIR"
if [[ "$ANY_FAILED" -ne 0 ]]; then
  echo "  Status: SOME LANES FAILED"
fi
echo "════════════════════════════════════════════════════════════════════════"

# Exit nonzero if any lane failed (after all bookkeeping is done)
if [[ "$ANY_FAILED" -ne 0 ]]; then
  exit 1
fi
