#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT="$ROOT/ops/plugins/infra/network/bin/network-firewall-audit"

[[ -x "$SCRIPT" ]] || {
  echo "G13 FAIL: missing firewall audit: $SCRIPT" >&2
  exit 2
}

set +e
output="$("$SCRIPT" 2>&1)"
rc=$?
set -e

printf '%s\n' "$output"

if [[ "$rc" -ne 0 ]]; then
  echo "G13 FAIL: firewall baseline drift detected" >&2
  exit 1
fi

echo "G13 PASS: firewall baseline healthy"
