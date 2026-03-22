#!/usr/bin/env bash
set -euo pipefail

# Regression tests for mcp-config-generate supplemental provisioning (GAP-OP-1583).
# Validates: supplemental fallback, live-wins, optional-not-provisioned,
# preferences preserved, deterministic JSON output.

# Always resolve from test file location, not SPINE_ROOT (which may point elsewhere)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
GENERATOR="$ROOT/ops/plugins/infra/mcp/bin/mcp-config-generate"

PASS=0
FAIL=0
TOTAL=0

run_test() {
  local name="$1"
  TOTAL=$((TOTAL + 1))
  echo -n "  [$TOTAL] $name ... "
}
pass() { PASS=$((PASS + 1)); echo "PASS"; }
fail_test() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Extract JSON from dry-run output (strips header lines before ---)
extract_json() { sed '1,/^---$/d'; }

# --- Fixture: contract with required + optional + supplemental ---
cat > "$TMPDIR/contract.yaml" <<'YAML'
version: 3
required_servers_by_surface:
  claude_desktop:
    - spine
    - immich-photos
optional_servers:
  claude_desktop:
    - docker
    - finance-agent
supplemental_server_definitions:
  immich-photos:
    description: "Immich photo MCP server"
    command: "/usr/bin/immich-mcp"
    args: ["--mode", "stdio"]
    env:
      IMMICH_API_URL: "http://localhost:2283"
    surfaces: [claude_desktop]
    health_check: binary_exists
  docker:
    description: "Docker MCP server"
    command: "/usr/bin/docker-mcp"
    args: []
    surfaces: [claude_desktop]
    health_check: binary_exists
surface_paths:
  claude_desktop: "UNUSED"
YAML

# =============================================================================
# Test 1: Missing required server provisioned from supplemental definitions
# =============================================================================
run_test "missing required server provisioned from supplemental"

cat > "$TMPDIR/live1.json" <<'JSON'
{
  "mcpServers": {
    "spine": {"command": "/usr/bin/spine", "args": ["mcp", "serve"]}
  },
  "preferences": {}
}
JSON

output="$(MCP_CONTRACT_OVERRIDE="$TMPDIR/contract.yaml" \
  MCP_LIVE_CONFIG_OVERRIDE="$TMPDIR/live1.json" \
  bash "$GENERATOR" 2>/dev/null | extract_json)"

if echo "$output" | jq -e '.mcpServers["immich-photos"]' >/dev/null 2>&1; then
  immich_cmd="$(echo "$output" | jq -r '.mcpServers["immich-photos"].command')"
  immich_env="$(echo "$output" | jq -r '.mcpServers["immich-photos"].env.IMMICH_API_URL // empty')"
  if [[ "$immich_cmd" == "/usr/bin/immich-mcp" && "$immich_env" == "http://localhost:2283" ]]; then
    pass
  else
    fail_test "supplemental definition not materialized correctly (cmd=$immich_cmd, env=$immich_env)"
  fi
else
  fail_test "immich-photos not in generated config"
fi

# =============================================================================
# Test 2: Existing required server in live config is preserved (live wins)
# =============================================================================
run_test "live config definition preserved over supplemental"

cat > "$TMPDIR/live2.json" <<'JSON'
{
  "mcpServers": {
    "spine": {"command": "/usr/bin/spine", "args": ["mcp", "serve"]},
    "immich-photos": {"command": "/custom/immich", "args": ["--custom"], "env": {"CUSTOM": "yes"}}
  },
  "preferences": {}
}
JSON

output="$(MCP_CONTRACT_OVERRIDE="$TMPDIR/contract.yaml" \
  MCP_LIVE_CONFIG_OVERRIDE="$TMPDIR/live2.json" \
  bash "$GENERATOR" 2>/dev/null | extract_json)"

live_cmd="$(echo "$output" | jq -r '.mcpServers["immich-photos"].command')"
if [[ "$live_cmd" == "/custom/immich" ]]; then
  pass
else
  fail_test "live definition overwritten (got cmd=$live_cmd, expected /custom/immich)"
fi

# =============================================================================
# Test 3: Optional servers not auto-provisioned unless already in live config
# =============================================================================
run_test "optional server not provisioned when missing from live"

cat > "$TMPDIR/live3.json" <<'JSON'
{
  "mcpServers": {
    "spine": {"command": "/usr/bin/spine", "args": ["mcp", "serve"]},
    "immich-photos": {"command": "/usr/bin/immich-mcp", "args": []}
  },
  "preferences": {}
}
JSON

output="$(MCP_CONTRACT_OVERRIDE="$TMPDIR/contract.yaml" \
  MCP_LIVE_CONFIG_OVERRIDE="$TMPDIR/live3.json" \
  bash "$GENERATOR" 2>/dev/null | extract_json)"

if echo "$output" | jq -e '.mcpServers.docker' >/dev/null 2>&1; then
  fail_test "docker (optional) was auto-provisioned"
elif echo "$output" | jq -e '.mcpServers["finance-agent"]' >/dev/null 2>&1; then
  fail_test "finance-agent (optional) was auto-provisioned"
else
  pass
fi

# =============================================================================
# Test 4: Preferences are preserved
# =============================================================================
run_test "preferences preserved in generated config"

cat > "$TMPDIR/live4.json" <<'JSON'
{
  "mcpServers": {
    "spine": {"command": "/usr/bin/spine", "args": ["mcp", "serve"]},
    "immich-photos": {"command": "/usr/bin/immich-mcp", "args": []}
  },
  "preferences": {"theme": "dark", "hasCompletedOnboarding": true}
}
JSON

output="$(MCP_CONTRACT_OVERRIDE="$TMPDIR/contract.yaml" \
  MCP_LIVE_CONFIG_OVERRIDE="$TMPDIR/live4.json" \
  bash "$GENERATOR" 2>/dev/null | extract_json)"

theme="$(echo "$output" | jq -r '.preferences.theme')"
onboarding="$(echo "$output" | jq -r '.preferences.hasCompletedOnboarding')"
if [[ "$theme" == "dark" && "$onboarding" == "true" ]]; then
  pass
else
  fail_test "preferences lost (theme=$theme, onboarding=$onboarding)"
fi

# =============================================================================
# Test 5: Output is valid JSON and deterministic
# =============================================================================
run_test "output is valid deterministic JSON"

json1="$(MCP_CONTRACT_OVERRIDE="$TMPDIR/contract.yaml" \
  MCP_LIVE_CONFIG_OVERRIDE="$TMPDIR/live1.json" \
  bash "$GENERATOR" 2>/dev/null | extract_json)"
json2="$(MCP_CONTRACT_OVERRIDE="$TMPDIR/contract.yaml" \
  MCP_LIVE_CONFIG_OVERRIDE="$TMPDIR/live1.json" \
  bash "$GENERATOR" 2>/dev/null | extract_json)"

if jq -e '.' <<<"$json1" >/dev/null 2>&1 && [[ "$json1" == "$json2" ]]; then
  pass
else
  fail_test "output is not valid JSON or not deterministic"
fi

# =============================================================================
echo ""
echo "=== mcp-config-generate regression: $PASS/$TOTAL PASS, $FAIL FAIL ==="
[[ "$FAIL" -eq 0 ]]
