#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT="$ROOT/ops/plugins/domains/communications/bin/communications-tls-status"

[[ -x "$SCRIPT" ]] || {
  echo "G11 FAIL: missing TLS probe: $SCRIPT" >&2
  exit 2
}

set +e
output="$("$SCRIPT" 2>&1)"
rc=$?
set -e

printf '%s\n' "$output"

if [[ "$rc" -ne 0 ]]; then
  echo "G11 FAIL: TLS certificate check failed" >&2
  exit 1
fi

echo "G11 PASS: TLS certificates healthy"
