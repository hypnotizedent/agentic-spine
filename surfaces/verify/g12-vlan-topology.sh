#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT="$ROOT/ops/plugins/infra/network/bin/network-vlan-status"

[[ -x "$SCRIPT" ]] || {
  echo "G12 FAIL: missing VLAN probe: $SCRIPT" >&2
  exit 2
}

set +e
output="$("$SCRIPT" 2>&1)"
rc=$?
set -e

printf '%s\n' "$output"

if [[ "$rc" -ne 0 ]]; then
  echo "G12 FAIL: VLAN topology drift detected" >&2
  exit 1
fi

echo "G12 PASS: VLAN topology healthy"
