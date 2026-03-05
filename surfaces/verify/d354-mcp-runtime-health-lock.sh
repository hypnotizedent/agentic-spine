#!/usr/bin/env bash
# TRIAGE: enforce MCP runtime health via canonical runtime status check.
# D354: mcp-runtime-health-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATUS_SCRIPT="$ROOT/ops/plugins/mcp/bin/mcp-runtime-status"

fail() {
  echo "D354 FAIL: $*" >&2
  exit 1
}

[[ -x "$STATUS_SCRIPT" ]] || fail "missing executable runtime status script: $STATUS_SCRIPT"

if "$STATUS_SCRIPT"; then
  echo "D354 PASS: MCP runtime health lock enforced"
  exit 0
fi

fail "mcp.runtime.status reported runtime health errors"
