#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# close-session.sh - Restore governed session closeout handoff
# ═══════════════════════════════════════════════════════════════════════════
#
# Purpose:
#   Restore the live Hammerspoon closeout path by creating a governed
#   session handoff packet and surfacing continuity state.
# #
# Notes:
#   - This is intentionally small and only wraps existing governed surfaces.
#   - It does not mutate loop state or create ad hoc receipt files.
#   - If loop context is unknown, it prompts for loop IDs instead of guessing.
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

SPINE_ROOT="${SPINE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)}"
HANDOFF_BIN="$SPINE_ROOT/ops/plugins/core/session/bin/session-handoff"
RECEIPTS_BIN="$SPINE_ROOT/ops/plugins/core/evidence/bin/receipts-summary"

[[ -f "$HANDOFF_BIN" ]] || {
  echo "close-session.sh: missing governed handoff surface at $HANDOFF_BIN" >&2
  exit 1
}

cd "$SPINE_ROOT"

DEFAULT_LOOP="${SPINE_LOOP_ID:-}"
RUNTIME_ROLE="${SPINE_RUNTIME_ROLE:-researcher}"
SOURCE_TERMINAL="${OPS_TERMINAL_ROLE:-unset}"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  SESSION CLOSEOUT                                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "This creates a governed handoff packet for continuity."
echo ""

read -r -p "SUMMARY: " SUMMARY
if [[ -z "$SUMMARY" ]]; then
  echo "close-session.sh: summary is required" >&2
  exit 1
fi

if [[ -n "$DEFAULT_LOOP" ]]; then
  echo "Loop IDs (space-separated, blank keeps current env loop: $DEFAULT_LOOP)"
else
  echo "Loop IDs (space-separated, optional)"
fi
read -r -p "LOOPS: " LOOP_INPUT
if [[ -z "$LOOP_INPUT" && -n "$DEFAULT_LOOP" ]]; then
  LOOP_INPUT="$DEFAULT_LOOP"
fi

read -r -p "NEXT ACTION: " NEXT_ACTION
read -r -p "NOTE (optional): " NOTE

LOOPS=()
if [[ -n "$LOOP_INPUT" ]]; then
  # Intentional shell splitting for space-separated LOOP IDs.
  read -r -a LOOPS <<< "$LOOP_INPUT"
fi

CMD=(python3 "$HANDOFF_BIN" create --summary "$SUMMARY" --from-role "$RUNTIME_ROLE" --transition-gate "session.closeout")
if [[ "${#LOOPS[@]}" -gt 0 ]]; then
  CMD+=(--loops "${LOOPS[@]}")
fi
CMD+=(--note "source_terminal=$SOURCE_TERMINAL")
if [[ -n "$NEXT_ACTION" ]]; then
  CMD+=(--note "next_action=$NEXT_ACTION")
fi
if [[ -n "$NOTE" ]]; then
  CMD+=(--note "$NOTE")
fi

HANDOFF_JSON="$("${CMD[@]}")"

eval "$(
  HANDOFF_JSON="$HANDOFF_JSON" python3 - <<'PY'
import json
import os
import shlex

data = json.loads(os.environ["HANDOFF_JSON"])
print(f"HANDOFF_ID={shlex.quote(str(data.get('handoff_id') or ''))}")
print(f"HANDOFF_PATH={shlex.quote(str(data.get('path') or ''))}")
PY
)"

echo ""
echo "Created governed handoff:"
echo "  id:   ${HANDOFF_ID:-unknown}"
echo "  path: ${HANDOFF_PATH:-unknown}"
echo ""

echo "Active handoff status:"
python3 "$HANDOFF_BIN" status || true
echo ""
echo "Active handoff list:"
python3 "$HANDOFF_BIN" list --state active || true

if [[ -f "$RECEIPTS_BIN" ]]; then
  echo ""
  echo "Recent receipts summary:"
  python3 "$RECEIPTS_BIN" --domain none --days 7 || true
fi
