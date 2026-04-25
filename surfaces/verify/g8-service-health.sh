#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT="$ROOT/ops/plugins/infra/services/bin/services-health-status"
TIMEOUT_SEC="${SPINE_VERIFY_G8_TIMEOUT_SEC:-300}"

timeout_bin() {
  if command -v timeout >/dev/null 2>&1; then
    command -v timeout
    return 0
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    command -v gtimeout
    return 0
  fi
  return 1
}

[[ -x "$SCRIPT" ]] || {
  echo "G8 FAIL: missing service health probe: $SCRIPT" >&2
  exit 2
}

TIMEOUT_BIN="$(timeout_bin || true)"

set +e
if [[ -n "$TIMEOUT_BIN" ]]; then
  output="$("$TIMEOUT_BIN" "$TIMEOUT_SEC" "$SCRIPT" --strict-exit 2>&1)"
else
  output="$("$SCRIPT" --strict-exit 2>&1)"
fi
rc=$?
set -e

printf '%s\n' "$output"

if [[ "$rc" -eq 124 ]]; then
  echo "G8 FAIL: service health probe timed out after ${TIMEOUT_SEC}s" >&2
  exit 1
fi

if [[ "$rc" -ne 0 ]]; then
  echo "G8 FAIL: service health probe reported unhealthy endpoints" >&2
  exit 1
fi

echo "G8 PASS: service endpoints healthy"
