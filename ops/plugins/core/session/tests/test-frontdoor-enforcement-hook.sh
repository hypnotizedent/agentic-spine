#!/usr/bin/env bash
set -euo pipefail

# Test: Front-door enforcement hook (PreToolUse)
# Verifies that the hook correctly admits/rejects Edit/Write on governed paths
# based on session admission context.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
HOOK="$ROOT/.claude/hooks/frontdoor-enforcement-hook.sh"
PASS=0
FAIL=0
TOTAL=0

assert_allow() {
  local label="$1"
  local input="$2"
  local env_setup="${3:-}"
  TOTAL=$((TOTAL + 1))
  local output
  if [[ -n "$env_setup" ]]; then
    output=$(eval "$env_setup" bash -c "echo '$input' | \"$HOOK\"" 2>/dev/null || true)
  else
    output=$(echo "$input" | "$HOOK" 2>/dev/null || true)
  fi
  local decision
  decision=$(echo "$output" | jq -r '.decision // "allow"' 2>/dev/null || echo "allow")
  if [[ "$decision" == "allow" || "$output" == "{}" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (expected allow, got decision=$decision)"
    FAIL=$((FAIL + 1))
  fi
}

assert_block() {
  local label="$1"
  local input="$2"
  local env_setup="${3:-}"
  TOTAL=$((TOTAL + 1))
  local output
  if [[ -n "$env_setup" ]]; then
    output=$(eval "$env_setup" bash -c "echo '$input' | \"$HOOK\"" 2>/dev/null || true)
  else
    output=$(echo "$input" | "$HOOK" 2>/dev/null || true)
  fi
  local decision
  decision=$(echo "$output" | jq -r '.decision // "allow"' 2>/dev/null || echo "allow")
  if [[ "$decision" == "block" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (expected block, got decision=$decision)"
    FAIL=$((FAIL + 1))
  fi
}

# Verify hook exists and is executable
TOTAL=$((TOTAL + 1))
if [[ -x "$HOOK" ]]; then
  echo "PASS: hook exists and is executable"
  PASS=$((PASS + 1))
else
  echo "FAIL: hook missing or not executable at $HOOK"
  FAIL=$((FAIL + 1))
fi

# ── Test 1: Read tool is not intercepted ──
assert_allow "Read tool not intercepted" \
  '{"tool_name":"Read","tool_input":{"file_path":"'"$ROOT"'/ops/commands/cap.sh"}}'

# ── Test 2: Grep tool is not intercepted ──
assert_allow "Grep tool not intercepted" \
  '{"tool_name":"Grep","tool_input":{"pattern":"test","path":"'"$ROOT"'/ops/"}}'

# ── Test 3: Bash tool is not intercepted ──
assert_allow "Bash tool not intercepted" \
  '{"tool_name":"Bash","tool_input":{"command":"ls"}}'

# ── Test 4: Edit on non-governed path is allowed ──
assert_allow "Edit on non-governed path (fixtures/) allowed" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$ROOT"'/fixtures/test.yaml","old_string":"a","new_string":"b"}}'

# ── Test 5: Write to non-governed path is allowed ──
assert_allow "Write to non-governed path allowed" \
  '{"tool_name":"Write","tool_input":{"file_path":"'"$ROOT"'/docs/product/test.md","content":"test"}}'

# ── Test 6: Edit on file outside repo is allowed ──
assert_allow "Edit on file outside repo allowed" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.txt","old_string":"a","new_string":"b"}}'

# ── Test 7: Edit on governed path WITH env admission is allowed ──
# Current session has SPINE_ENTRY_PACKET_PATH set (inherited)
if [[ -n "${SPINE_ENTRY_PACKET_PATH:-}" && -f "${SPINE_ENTRY_PACKET_PATH:-}" ]]; then
  assert_allow "Edit on ops/ with env admission allowed" \
    '{"tool_name":"Edit","tool_input":{"file_path":"'"$ROOT"'/ops/bindings/test.yaml","old_string":"a","new_string":"b"}}'

  assert_allow "Edit on bin/ with env admission allowed" \
    '{"tool_name":"Edit","tool_input":{"file_path":"'"$ROOT"'/bin/test.sh","old_string":"a","new_string":"b"}}'

  assert_allow "Write to surfaces/ with env admission allowed" \
    '{"tool_name":"Write","tool_input":{"file_path":"'"$ROOT"'/surfaces/verify/test.sh","content":"test"}}'
else
  echo "SKIP: env admission tests (SPINE_ENTRY_PACKET_PATH not set)"
fi

# ── Test 8: Edit on governed path WITHOUT admission is blocked ──
# Simulate missing admission by unsetting env and using an empty entry-packets dir
FAKE_STATE=$(mktemp -d)
mkdir -p "$FAKE_STATE/entry-packets"
# No entry packets and no env var → should block
TOTAL=$((TOTAL + 1))
BLOCK_OUTPUT=$(
  echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$ROOT"'/ops/bindings/test.yaml","old_string":"a","new_string":"b"}}' \
  | env SPINE_ENTRY_PACKET_PATH="" SPINE_STATE="$FAKE_STATE" "$HOOK" 2>/dev/null || true
)
BLOCK_DECISION=$(echo "$BLOCK_OUTPUT" | jq -r '.decision // "allow"' 2>/dev/null || echo "allow")
if [[ "$BLOCK_DECISION" == "block" ]]; then
  echo "PASS: Edit on ops/ without admission blocked"
  PASS=$((PASS + 1))
else
  echo "FAIL: Edit on ops/ without admission should be blocked (got $BLOCK_DECISION)"
  FAIL=$((FAIL + 1))
fi

# ── Test 9: Block includes remediation text ──
TOTAL=$((TOTAL + 1))
BLOCK_REASON=$(echo "$BLOCK_OUTPUT" | jq -r '.reason // ""' 2>/dev/null || echo "")
if echo "$BLOCK_REASON" | grep -q "session.v3.attach"; then
  echo "PASS: Block message includes session.v3.attach remediation"
  PASS=$((PASS + 1))
else
  echo "FAIL: Block message missing session.v3.attach remediation"
  FAIL=$((FAIL + 1))
fi

# ── Test 10: Write to governed path WITHOUT admission is blocked ──
TOTAL=$((TOTAL + 1))
WRITE_BLOCK=$(
  echo '{"tool_name":"Write","tool_input":{"file_path":"'"$ROOT"'/surfaces/verify/test.sh","content":"test"}}' \
  | env SPINE_ENTRY_PACKET_PATH="" SPINE_STATE="$FAKE_STATE" "$HOOK" 2>/dev/null || true
)
WRITE_DECISION=$(echo "$WRITE_BLOCK" | jq -r '.decision // "allow"' 2>/dev/null || echo "allow")
if [[ "$WRITE_DECISION" == "block" ]]; then
  echo "PASS: Write to surfaces/ without admission blocked"
  PASS=$((PASS + 1))
else
  echo "FAIL: Write to surfaces/ without admission should be blocked (got $WRITE_DECISION)"
  FAIL=$((FAIL + 1))
fi

# ── Test 11: Edit on governed path WITH recent entry packet (no env) is allowed ──
TOTAL=$((TOTAL + 1))
# Create a fake recent entry packet
touch "$FAKE_STATE/entry-packets/TEST__researcher__solo.entry.packet.yaml"
RECENT_OUTPUT=$(
  echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$ROOT"'/ops/bindings/test.yaml","old_string":"a","new_string":"b"}}' \
  | env SPINE_ENTRY_PACKET_PATH="" SPINE_STATE="$FAKE_STATE" "$HOOK" 2>/dev/null || true
)
RECENT_DECISION=$(echo "$RECENT_OUTPUT" | jq -r '.decision // "allow"' 2>/dev/null || echo "allow")
if [[ "$RECENT_DECISION" == "allow" || "$RECENT_OUTPUT" == "{}" ]]; then
  echo "PASS: Edit on ops/ with recent entry packet (no env) allowed"
  PASS=$((PASS + 1))
else
  echo "FAIL: Edit on ops/ with recent entry packet should be allowed (got $RECENT_DECISION)"
  FAIL=$((FAIL + 1))
fi

# ── Test 12: Edit on governed path with STALE entry packet is blocked ──
TOTAL=$((TOTAL + 1))
# Make the packet look old (>4 hours)
touch -t 202601010000 "$FAKE_STATE/entry-packets/TEST__researcher__solo.entry.packet.yaml"
STALE_OUTPUT=$(
  echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$ROOT"'/ops/bindings/test.yaml","old_string":"a","new_string":"b"}}' \
  | env SPINE_ENTRY_PACKET_PATH="" SPINE_STATE="$FAKE_STATE" "$HOOK" 2>/dev/null || true
)
STALE_DECISION=$(echo "$STALE_OUTPUT" | jq -r '.decision // "allow"' 2>/dev/null || echo "allow")
if [[ "$STALE_DECISION" == "block" ]]; then
  echo "PASS: Edit on ops/ with stale entry packet blocked"
  PASS=$((PASS + 1))
else
  echo "FAIL: Edit on ops/ with stale entry packet should be blocked (got $STALE_DECISION)"
  FAIL=$((FAIL + 1))
fi

# ── Test 13: Operational mailroom path unaffected ──
# Mailroom worker uses cap.sh (Bash), not Edit/Write. Verify Bash is not intercepted.
assert_allow "Bash (mailroom cap run) not intercepted" \
  '{"tool_name":"Bash","tool_input":{"command":"./bin/ops cap run verify.fast"}}'

# ── Cleanup ──
rm -rf "$FAKE_STATE"

# ── Summary ──
echo ""
echo "════════════════════════════════════════"
echo "FRONT-DOOR ENFORCEMENT HOOK: $PASS/$TOTAL passed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILURES: $FAIL"
  exit 1
fi
echo "════════════════════════════════════════"
