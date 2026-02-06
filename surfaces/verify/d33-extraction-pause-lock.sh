#!/usr/bin/env bash
set -euo pipefail

# D33: Extraction Pause Lock
# Enforces stabilization pause state for extraction workflows.

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
[[ "$MODE" == "paused" ]] || fail "extraction mode must be paused (found: $MODE)"

UNTIL="$(yq e '.until_utc' "$BINDING")"
[[ -n "${UNTIL:-}" && "${UNTIL:-}" != "null" ]] || fail "until_utc missing in extraction binding"

echo "D33 PASS: extraction pause lock enforced (mode=paused, until=$UNTIL)"
