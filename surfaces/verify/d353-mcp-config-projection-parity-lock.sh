#!/usr/bin/env bash
# TRIAGE: enforce MCP config projection parity from governed runtime contracts.
# D353: mcp-config-projection-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GENERATOR="$ROOT/ops/plugins/mcp/bin/mcp-config-generate"

fail() {
  echo "D353 FAIL: $*" >&2
  exit 1
}

[[ -x "$GENERATOR" ]] || fail "missing executable generator: $GENERATOR"

if "$GENERATOR" --check; then
  echo "D353 PASS: MCP config projection parity enforced"
  exit 0
fi

fail "mcp.config.generate --check reported projection drift"
