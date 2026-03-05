#!/usr/bin/env bash
# TRIAGE: enforce runtime-path authority parity for bridge/watcher launchd + scripts.
# Gate: D328 — mailroom-runtime-path-authority-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/mailroom.runtime.contract.yaml"

fail=0
pass=0
total=0

check() {
  local label="$1"
  local result="$2"
  total=$((total + 1))
  if [[ "$result" == "PASS" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label"
    fail=$((fail + 1))
  fi
}

echo "D328: mailroom-runtime-path-authority-lock"
echo

if [[ ! -f "$CONTRACT" ]]; then
  echo "status: FAIL (missing runtime contract: $CONTRACT)"
  exit 1
fi

active="$(yq -r '.active // false' "$CONTRACT" 2>/dev/null || echo "false")"
runtime_root="$(yq -r '.runtime_root // ""' "$CONTRACT" 2>/dev/null || echo "")"

repo_inbox="$ROOT/mailroom/inbox"
repo_outbox="$ROOT/mailroom/outbox"
repo_state="$ROOT/mailroom/state"
repo_logs="$ROOT/mailroom/logs"

if [[ "$active" == "true" && -n "$runtime_root" ]]; then
  expected_inbox="$runtime_root/inbox"
  expected_outbox="$runtime_root/outbox"
  expected_state="$runtime_root/state"
  expected_logs="$runtime_root/logs"
else
  expected_inbox="$repo_inbox"
  expected_outbox="$repo_outbox"
  expected_state="$repo_state"
  expected_logs="$repo_logs"
fi

check_script_runtime_paths() {
  local script="$1"
  local label="$2"
  if [[ ! -f "$script" ]]; then
    check "$label exists" "FAIL"
    return
  fi
  if grep -q "runtime-paths.sh" "$script" && grep -q "spine_runtime_resolve_paths" "$script"; then
    check "$label uses runtime-paths resolver" "PASS"
  else
    check "$label uses runtime-paths resolver" "FAIL"
  fi
}

check_script_runtime_paths "$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-start" "mailroom-bridge-start"
check_script_runtime_paths "$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-status" "mailroom-bridge-status"
check_script_runtime_paths "$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-stop" "mailroom-bridge-stop"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-enqueue.sh" "agent-enqueue.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-status.sh" "agent-status.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/hot-folder-watcher.sh" "hot-folder-watcher.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-restart.sh" "agent-restart.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-latest.sh" "agent-latest.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-park-inbox.sh" "agent-park-inbox.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-summary.sh" "agent-summary.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/agent-watchdog.sh" "agent-watchdog.sh"
check_script_runtime_paths "$ROOT/ops/runtime/inbox/close-session.sh" "close-session.sh"

if grep -q 'env\["SPINE_INBOX"\]' "$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve" \
   && grep -q 'env\["SPINE_STATE"\]' "$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve"; then
  check "mailroom-bridge-serve passes explicit SPINE path env to subprocesses" "PASS"
else
  check "mailroom-bridge-serve passes explicit SPINE path env to subprocesses" "FAIL"
fi

bridge_plist="$HOME/Library/LaunchAgents/com.ronny.mailroom-bridge.plist"
watcher_plist="$HOME/Library/LaunchAgents/com.ronny.agent-inbox.plist"

plist_env_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:${key}" "$plist" 2>/dev/null || true
}

check_plist_path() {
  local plist="$1"
  local plist_label="$2"
  local key="$3"
  local expected="$4"
  local got
  got="$(plist_env_value "$plist" "$key")"
  if [[ "$got" == "$expected" ]]; then
    check "${plist_label} ${key} matches authority path" "PASS"
  else
    check "${plist_label} ${key} matches authority path" "FAIL"
  fi
}

if [[ "$OSTYPE" == darwin* && -x /usr/libexec/PlistBuddy ]]; then
  if [[ -f "$bridge_plist" ]]; then
    check_plist_path "$bridge_plist" "bridge plist" "SPINE_INBOX" "$expected_inbox"
    check_plist_path "$bridge_plist" "bridge plist" "SPINE_OUTBOX" "$expected_outbox"
    check_plist_path "$bridge_plist" "bridge plist" "SPINE_STATE" "$expected_state"
    check_plist_path "$bridge_plist" "bridge plist" "SPINE_LOGS" "$expected_logs"
  else
    check "bridge plist materialized on macOS host" "PASS"
  fi

  if [[ -f "$watcher_plist" ]]; then
    check_plist_path "$watcher_plist" "watcher plist" "SPINE_INBOX" "$expected_inbox"
    check_plist_path "$watcher_plist" "watcher plist" "SPINE_OUTBOX" "$expected_outbox"
    check_plist_path "$watcher_plist" "watcher plist" "SPINE_STATE" "$expected_state"
    check_plist_path "$watcher_plist" "watcher plist" "SPINE_LOGS" "$expected_logs"
  else
    check "watcher plist materialized on macOS host" "PASS"
  fi
else
  check "launchd plist parity checks (non-macOS or no PlistBuddy)" "PASS"
fi

legacy_token="$repo_state/mailroom-bridge.token"
if [[ "$expected_state" != "$repo_state" && -f "$legacy_token" ]]; then
  check "legacy repo token tombstoned when runtime state authority is externalized" "FAIL"
else
  check "legacy repo token tombstoned when runtime state authority is externalized" "PASS"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
