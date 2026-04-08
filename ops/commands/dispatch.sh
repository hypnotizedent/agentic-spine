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
  --dry-run               Show plan without executing

Example:
  ops dispatch local \
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
LANES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --loop-id) LOOP_ID="${2:-}"; shift 2 ;;
    --objective) OBJECTIVE="${2:-}"; shift 2 ;;
    --wave-id) WAVE_ID="${2:-}"; shift 2 ;;
    --lane) LANES+=("${2:-}"); shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
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
  echo "# ops dispatch local (dry-run)"
  echo "# Wave:      $WAVE_ID"
  echo "# Loop:      $LOOP_ID"
  echo "# Objective: $OBJECTIVE"
  echo "# Evidence:  $EVIDENCE_DIR"
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
echo "  Evidence:  $EVIDENCE_DIR"
echo ""

# ── Step 1: Wave start ───────────────────────────────────────────────────

echo "── wave start ──────────────────────────────────────────────────────"
bash "$WAVE_CMD" start "$WAVE_ID" \
  --loop-id "$LOOP_ID" \
  --objective "$OBJECTIVE" \
  --worktree off
echo ""

# ── Step 2: Dispatch lanes ───────────────────────────────────────────────

echo "── dispatch lanes ──────────────────────────────────────────────────"
for i in "${!LANE_NAMES[@]}"; do
  local_name="${LANE_NAMES[$i]}"
  local_cmd="${LANE_CMDS[$i]}"
  task_desc="[local-research:${local_name}] ${local_cmd}"
  bash "$WAVE_CMD" dispatch "$WAVE_ID" \
    --lane execution \
    --task "$task_desc"
  echo ""
done

# ── Step 3: Execute locally and ack ──────────────────────────────────────

echo "── execute + ack ─────────────────────────────────────────────────"
for i in "${!LANE_NAMES[@]}"; do
  local_name="${LANE_NAMES[$i]}"
  local_cmd="${LANE_CMDS[$i]}"
  dispatch_id="D$((i + 1))"
  lane_evidence="$EVIDENCE_DIR/lane-${local_name}.txt"

  echo "  [$dispatch_id] ${local_name}: executing..."

  set +e
  lane_output="$(cd "$SPINE_REPO" && eval "$local_cmd" 2>&1)"
  lane_exit=$?
  set -e

  # Write lane output to evidence
  {
    echo "# Lane: $local_name"
    echo "# Command: $local_cmd"
    echo "# Exit code: $lane_exit"
    echo "# Timestamp: $(TZ=UTC date '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "---"
    echo "$lane_output"
  } > "$lane_evidence"

  # Build result summary (first 5 lines + line count)
  total_lines="$(echo "$lane_output" | wc -l | tr -d ' ')"
  result_preview="$(echo "$lane_output" | head -5)"
  if [[ "$lane_exit" -eq 0 ]]; then
    result_text="OK (${total_lines} lines). Preview: ${result_preview}"
  else
    result_text="FAIL exit=${lane_exit} (${total_lines} lines). Preview: ${result_preview}"
  fi

  bash "$WAVE_CMD" ack "$WAVE_ID" \
    --dispatch "$dispatch_id" \
    --result "$result_text"
  echo ""
done

# ── Step 4: Collect ──────────────────────────────────────────────────────

echo "── collect ─────────────────────────────────────────────────────────"
bash "$WAVE_CMD" collect "$WAVE_ID"
echo ""

echo "════════════════════════════════════════════════════════════════════════"
echo "  LOCAL DISPATCH COMPLETE: $WAVE_ID"
echo "  Evidence: $EVIDENCE_DIR"
echo "════════════════════════════════════════════════════════════════════════"
