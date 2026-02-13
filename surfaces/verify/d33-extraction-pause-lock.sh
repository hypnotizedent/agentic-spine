#!/usr/bin/env bash
# TRIAGE: Extraction must stay paused during stabilization. Do not resume without operator approval.
set -euo pipefail

# D33: Extraction Pause Lock
# Enforces stabilization pause discipline for extraction workflows.
# - If mode=paused: requires valid until_utc
# - If mode=active: requires previous_pause.expired_at in the past

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/extraction.mode.yaml"

fail() { echo "D33 FAIL: $*" >&2; exit 1; }

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

require_tool yq

[[ -f "$BINDING" ]] || fail "binding missing: $BINDING"
yq e '.' "$BINDING" >/dev/null 2>&1 || fail "binding is not valid YAML"

MODE="$(yq e '.mode' "$BINDING")"
[[ -n "${MODE:-}" && "${MODE:-}" != "null" ]] || fail "mode missing in extraction binding"

case "$MODE" in
  paused)
    UNTIL="$(yq e '.until_utc' "$BINDING")"
    [[ -n "${UNTIL:-}" && "${UNTIL:-}" != "null" ]] || fail "until_utc missing in extraction binding"
    echo "D33 PASS: extraction paused (until=$UNTIL)"
    ;;
  active)
    EXPIRED="$(yq e '.previous_pause.expired_at' "$BINDING")"
    [[ -n "${EXPIRED:-}" && "${EXPIRED:-}" != "null" ]] || fail "mode is active but previous_pause.expired_at missing (no proof pause completed)"
    NOW_EPOCH="$(date -u +%s)"
    # Handle both GNU and BSD date for parsing ISO timestamps
    if date -d "2000-01-01" +%s >/dev/null 2>&1; then
      EXP_EPOCH="$(date -u -d "$EXPIRED" +%s 2>/dev/null)" || fail "cannot parse previous_pause.expired_at: $EXPIRED"
    else
      EXP_EPOCH="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRED" +%s 2>/dev/null)" || fail "cannot parse previous_pause.expired_at: $EXPIRED"
    fi
    [[ "$NOW_EPOCH" -ge "$EXP_EPOCH" ]] || fail "mode is active but pause window has not expired yet (expired_at=$EXPIRED)"
    echo "D33 PASS: extraction active (pause expired=$EXPIRED)"
    ;;
  *)
    fail "unknown extraction mode: $MODE (expected paused or active)"
    ;;
esac
