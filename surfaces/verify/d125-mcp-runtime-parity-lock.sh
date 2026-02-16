#!/usr/bin/env bash
# TRIAGE: Align MCP runtime registrations with ops/bindings/mcp.runtime.contract.yaml and rerun mcp.runtime.status.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SCRIPT="$ROOT/ops/plugins/mcp/bin/mcp-runtime-status"

if [[ ! -x "$SCRIPT" ]]; then
  echo "D125 FAIL: missing executable runtime status script: $SCRIPT" >&2
  exit 1
fi

if "$SCRIPT"; then
  echo "D125 PASS: MCP runtime parity lock enforced"
  exit 0
fi

echo "D125 FAIL: MCP runtime parity violations detected" >&2
exit 1
