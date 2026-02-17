#!/usr/bin/env bash
set -euo pipefail

# sync-slash-commands.sh — RETIRED (WS-5, GAP-OP-639)
#
# Slash-command distribution is no longer synchronized by file copy.
# Command/tool delivery now routes through governed capabilities and MCP gateway.
#
# This shim remains to avoid breaking callers that still invoke the legacy hook.

echo "sync-slash-commands.sh: RETIRED (no sync action performed)."
echo "Reason: command surfaces now flow through governed capability + MCP gateway lanes."
echo "Hint: use './bin/ops mcp serve' for unified MCP tool delivery."

exit 0
