#!/usr/bin/env bash
# TRIAGE: HA MCP governance check failed — run ha.mcp.status to diagnose; check GOVERNED_TOOLS block and policy doc
# D105: ha-mcp-governance-lock
# Enforces: MCP source exists, GOVERNED_TOOLS block present, ha_call_service blocked, policy doc exists
set -euo pipefail

MCP_SRC="${HOME}/code/workbench/infra/compose/mcpjungle/servers/home-assistant/src/index.ts"
SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY_DOC="$SPINE_ROOT/docs/governance/HASS_MCP_INTEGRATION.md"
FAIL=0

# Check 1: MCP source exists
if [[ ! -f "$MCP_SRC" ]]; then
  echo "  D105 FAIL: MCP source not found at $MCP_SRC"
  FAIL=1
fi

# Check 2: GOVERNED_TOOLS block present
if [[ -f "$MCP_SRC" ]] && ! grep -q 'GOVERNED_TOOLS' "$MCP_SRC"; then
  echo "  D105 FAIL: GOVERNED_TOOLS block not found in MCP source"
  FAIL=1
fi

# Check 3: ha_call_service is null/blocked
if [[ -f "$MCP_SRC" ]] && ! grep -q '"ha_call_service": null' "$MCP_SRC"; then
  echo "  D105 FAIL: ha_call_service is not null — may be unblocked"
  FAIL=1
fi

# Check 4: Policy doc exists
if [[ ! -f "$POLICY_DOC" ]]; then
  echo "  D105 FAIL: HASS_MCP_INTEGRATION.md not found"
  FAIL=1
fi

exit $FAIL
