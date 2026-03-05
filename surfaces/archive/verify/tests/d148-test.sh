#!/usr/bin/env bash
# Tests for D148: mcp-agent-runtime-binding-lock
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GATE="$SP/surfaces/verify/d148-mcp-agent-runtime-binding-lock.sh"

PASS=0
FAIL_COUNT=0
pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1" >&2; }

run_gate() {
  local mock="$1"
  SPINE_ROOT="$mock" D148_SKIP_LIVE_LAUNCHCTL=1 bash "$GATE"
}

setup_mock() {
  local tmp
  tmp="$(mktemp -d)"

  mkdir -p "$tmp/ops/bindings"
  mkdir -p "$tmp/docs/product"
  mkdir -p "$tmp/ops/runtime/launchd"
  mkdir -p "$tmp/home/Library/LaunchAgents"

  cat > "$tmp/ops/bindings/mcp.runtime.contract.yaml" <<'EOF'
version: "1.0"
surface_paths:
  claude_desktop: "/Users/ronnyworks/Library/Application Support/Claude/claude_desktop_config.json"
  claude_desktop_runtime_state: "/Users/ronnyworks/.claude.json"
required_servers_by_surface:
  claude_desktop:
    - communications-agent
optional_servers:
  claude_desktop: []
EOF

  cat > "$tmp/ops/bindings/launchd.runtime.contract.yaml" <<EOF
version: "1.0"
paths:
  source_dir: "$tmp/ops/runtime/launchd"
  user_launchagents_dir: "$tmp/home/Library/LaunchAgents"
required_labels:
  - com.ronny.mcp-runtime-anti-drift-cycle
EOF

  cat > "$tmp/ops/runtime/launchd/com.ronny.mcp-runtime-anti-drift-cycle.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.ronny.mcp-runtime-anti-drift-cycle</string>
  <key>StartInterval</key>
  <integer>1800</integer>
</dict>
</plist>
EOF

  cp \
    "$tmp/ops/runtime/launchd/com.ronny.mcp-runtime-anti-drift-cycle.plist" \
    "$tmp/home/Library/LaunchAgents/com.ronny.mcp-runtime-anti-drift-cycle.plist"

  cat > "$tmp/ops/bindings/agents.registry.yaml" <<'EOF'
agents:
  - id: communications-agent
    implementation_status: active
    mcp_server: communications-agent
    runtime_bindings:
      - surface: claude_desktop
        server_name: communications-agent
        required: true
EOF

  cat > "$tmp/docs/product/AOF_V1_1_SURFACE_UNIFICATION.md" <<'EOF'
# AOF Surface Unification

communications-agent: active
immich-agent: active
EOF

  echo "$tmp"
}

test_valid_setup() {
  local mock
  mock="$(setup_mock)"
  if run_gate "$mock" >/dev/null 2>&1; then
    pass "valid setup passes D148"
  else
    fail "valid setup should pass D148"
  fi
  rm -rf "$mock"
}

test_non_canonical_desktop_path_fails() {
  local mock
  mock="$(setup_mock)"
  yq e -i '.surface_paths.claude_desktop = "/tmp/claude_desktop_config.json"' "$mock/ops/bindings/mcp.runtime.contract.yaml"
  if run_gate "$mock" >/dev/null 2>&1; then
    fail "non-canonical claude_desktop path should fail D148"
  else
    pass "non-canonical claude_desktop path fails D148"
  fi
  rm -rf "$mock"
}

test_missing_runtime_bindings_fails() {
  local mock
  mock="$(setup_mock)"
  yq e -i '.agents[0] |= del(.runtime_bindings)' "$mock/ops/bindings/agents.registry.yaml"
  if run_gate "$mock" >/dev/null 2>&1; then
    fail "active MCP agent without runtime bindings should fail D148"
  else
    pass "missing runtime bindings fails D148"
  fi
  rm -rf "$mock"
}

test_contract_missing_required_server_fails() {
  local mock
  mock="$(setup_mock)"
  yq e -i '.required_servers_by_surface.claude_desktop = ["spine"]' "$mock/ops/bindings/mcp.runtime.contract.yaml"
  if run_gate "$mock" >/dev/null 2>&1; then
    fail "missing required server linkage should fail D148"
  else
    pass "missing required server linkage fails D148"
  fi
  rm -rf "$mock"
}

test_stale_doc_status_fails() {
  local mock
  mock="$(setup_mock)"
  cat > "$mock/docs/product/AOF_V1_1_SURFACE_UNIFICATION.md" <<'EOF'
# AOF Surface Unification

communications-agent: registered
EOF
  if run_gate "$mock" >/dev/null 2>&1; then
    fail "stale registered status should fail D148"
  else
    pass "stale registered status fails D148"
  fi
  rm -rf "$mock"
}

test_missing_installed_launchagent_fails() {
  local mock
  mock="$(setup_mock)"
  rm -f "$mock/home/Library/LaunchAgents/com.ronny.mcp-runtime-anti-drift-cycle.plist"
  if run_gate "$mock" >/dev/null 2>&1; then
    fail "missing installed launchagent should fail D148"
  else
    pass "missing installed launchagent fails D148"
  fi
  rm -rf "$mock"
}

test_launchagent_schedule_drift_fails() {
  local mock
  mock="$(setup_mock)"
  cat > "$mock/home/Library/LaunchAgents/com.ronny.mcp-runtime-anti-drift-cycle.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.ronny.mcp-runtime-anti-drift-cycle</string>
  <key>StartInterval</key>
  <integer>999</integer>
</dict>
</plist>
EOF
  if run_gate "$mock" >/dev/null 2>&1; then
    fail "launchagent schedule drift should fail D148"
  else
    pass "launchagent schedule drift fails D148"
  fi
  rm -rf "$mock"
}

echo "D148 Tests"
echo "════════════════════════════════════════"
test_valid_setup
test_non_canonical_desktop_path_fails
test_missing_runtime_bindings_fails
test_contract_missing_required_server_fails
test_stale_doc_status_fails
test_missing_installed_launchagent_fails
test_launchagent_schedule_drift_fails

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"
