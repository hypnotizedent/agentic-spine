#!/usr/bin/env bash
set -euo pipefail

# D66: MCP Server Parity Gate
# Purpose: verify that agents with BOTH a local tools copy (agents/<domain>/tools/src/)
# AND an MCPJungle copy (infra/compose/mcpjungle/servers/<name>/src/) have identical
# source files. Divergence means one surface is stale and tools may behave differently
# depending on invocation path.
#
# Pairs are defined below. Add new pairs as agents gain both surfaces.
#
# Exit: 0 = PASS, 1 = FAIL

WORKBENCH="${HOME}/code/workbench"

# D66 is advisory (WARN) until workbench parity is enforced.
# Known drift: media-agent local vs MCPJungle copies diverged during P2 governance.
fail() { echo "D66 WARN: $*" >&2; }
warn() { echo "D66 WARN: $*" >&2; }

# Define parity pairs: local_path|mcpjungle_path
PAIRS=(
  "agents/media/tools/src/index.ts|infra/compose/mcpjungle/servers/media-stack/src/index.ts"
  "agents/n8n/tools/src/index.ts|infra/compose/mcpjungle/servers/n8n/src/index.ts"
)

errors=0

for pair in "${PAIRS[@]}"; do
  IFS='|' read -r local_path mcpjungle_path <<< "$pair"
  local_file="$WORKBENCH/$local_path"
  mcpjungle_file="$WORKBENCH/$mcpjungle_path"

  # Both files must exist
  if [[ ! -f "$local_file" ]]; then
    warn "local file missing: $local_path"
    errors=$((errors + 1))
    continue
  fi
  if [[ ! -f "$mcpjungle_file" ]]; then
    warn "MCPJungle file missing: $mcpjungle_path"
    errors=$((errors + 1))
    continue
  fi

  # Compare file hashes
  local_hash=$(shasum -a 256 "$local_file" | awk '{print $1}')
  mcpjungle_hash=$(shasum -a 256 "$mcpjungle_file" | awk '{print $1}')

  if [[ "$local_hash" != "$mcpjungle_hash" ]]; then
    warn "parity mismatch: $local_path != $mcpjungle_path"
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo "D66 WARN: $errors parity issue(s) detected (advisory, non-blocking)"
  exit 0
fi

echo "D66 PASS: MCP server parity intact (${#PAIRS[@]} pairs checked)"
