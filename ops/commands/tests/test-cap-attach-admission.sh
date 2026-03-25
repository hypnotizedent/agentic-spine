#!/usr/bin/env bash
set -euo pipefail

REAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CAP_SCRIPT="$REAL_ROOT/ops/commands/cap.sh"
YAML_LIB="$REAL_ROOT/ops/lib/yaml.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    fail "$label (unexpected: $needle)"
  else
    pass "$label"
  fi
}

make_fake_repo() {
  local repo="$1"
  mkdir -p \
    "$repo/ops/commands" \
    "$repo/ops/lib" \
    "$repo/ops/bindings" \
    "$repo/ops/plugins/demo/bin"

  cp "$CAP_SCRIPT" "$repo/ops/commands/cap.sh"
  cp "$YAML_LIB" "$repo/ops/lib/yaml.sh"

  cat > "$repo/ops/lib/runtime-paths.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
spine_runtime_resolve_paths() {
  local runtime_root="${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine}"
  export SPINE_TARGET_REPO="${SPINE_TARGET_REPO:-$PWD}"
  export SPINE_REPO="${SPINE_REPO:-$SPINE_TARGET_REPO}"
  export SPINE_CODE="${SPINE_CODE:-$SPINE_TARGET_REPO}"
  export SPINE_RUNTIME_ROOT="$runtime_root"
  export SPINE_STATE="${SPINE_STATE:-$runtime_root/state}"
  export SPINE_TMP="${SPINE_TMP:-$runtime_root/tmp}"
  export SPINE_INBOX="${SPINE_INBOX:-$runtime_root/inbox}"
  export SPINE_OUTBOX="${SPINE_OUTBOX:-$runtime_root/outbox}"
  export SPINE_LOCKS="${SPINE_LOCKS:-$runtime_root/locks}"
  export SPINE_LOGS="${SPINE_LOGS:-$runtime_root/logs}"
  export SPINE_RECEIPTS="${SPINE_RECEIPTS:-$runtime_root/receipts}"
  export SPINE_VERIFY_ROOT="${SPINE_VERIFY_ROOT:-$runtime_root/verify}"
  export SPINE_DOMAIN_STATE="${SPINE_DOMAIN_STATE:-$runtime_root/domain-state}"
  export SPINE_VERIFY_HISTORY_DIR="${SPINE_VERIFY_HISTORY_DIR:-$runtime_root/verify/history}"
  export SPINE_VERIFY_FAILURE_HISTORY_FILE="${SPINE_VERIFY_FAILURE_HISTORY_FILE:-$runtime_root/verify/history/failures.log}"
  export SPINE_VERIFY_STATE_ROOT="${SPINE_VERIFY_STATE_ROOT:-$runtime_root/verify/state}"
  export SPINE_VERIFY_PASS_STREAK_FILE="${SPINE_VERIFY_PASS_STREAK_FILE:-$runtime_root/verify/state/pass-streak.json}"
  export SPINE_AGENT_CONTEXT_ROOT="${SPINE_AGENT_CONTEXT_ROOT:-$runtime_root/context}"
}
SH

  cat > "$repo/ops/lib/spine-log.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
spine_log_event() {
  return 0
}
SH

  cat > "$repo/ops/lib/resolve-policy.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
resolve_policy_knobs() {
  export RESOLVED_POLICY_PRESET="balanced"
  export RESOLVED_APPROVAL_DEFAULT="automatic"
  export RESOLVED_MULTI_AGENT_WRITES="direct"
  export RESOLVED_MULTI_AGENT_WRITES_WHEN_MULTI_SESSION="proposal-only"
  export RESOLVED_PROPOSAL_REQUIRED="false"
}
SH

  cat > "$repo/ops/capabilities.yaml" <<'YAML'
capabilities:
  demo.write:
    description: Demo write capability
    safety: mutating
    approval: automatic
    command: ./ops/plugins/demo/bin/demo-write
    cwd: $SPINE_TARGET_REPO
  orchestration.wave.start:
    description: Demo wave start alias
    safety: mutating
    approval: automatic
    command: ./ops/plugins/demo/bin/demo-wave-start
    cwd: $SPINE_TARGET_REPO
  session.start:
    description: Demo session start
    safety: mutating
    approval: automatic
    command: ./ops/plugins/demo/bin/demo-session-start
    cwd: $SPINE_TARGET_REPO
YAML

  cat > "$repo/ops/bindings/role.runtime.control.contract.yaml" <<'YAML'
runtime_roles:
  canonical: [researcher, worker]
  default_role: worker
  read_only_roles: [researcher]
  mutating_roles: [worker]
  session_role_override_cache:
    cache_filename: role-override.env
    ttl_seconds: 14400
    session_env_var: SPINE_SESSION_ID
    terminal_role_env_var: OPS_TERMINAL_ROLE
    require_session_binding: false
    require_terminal_role_binding: false
attach_admission:
  enforce_top_level: true
  required_safety: [mutating, destructive]
  required_env:
    - SPINE_ENTRY_PACKET_PATH
    - SPINE_ENTRY_PACKET_HASH
  exempt_capabilities:
    - session.start
    - session.v3.attach
    - session.role.override
    - aof.contract.acknowledge
YAML

  cat > "$repo/ops/bindings/terminal.role.contract.yaml" <<'YAML'
runtime_role_defaults:
  by_terminal_id: {}
  by_terminal_type: {}
roles: []
YAML

  cat > "$repo/ops/plugins/demo/bin/demo-write" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "demo-write-ok"
SH

  cat > "$repo/ops/plugins/demo/bin/demo-wave-start" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "demo-wave-start-ok"
SH

  cat > "$repo/ops/plugins/demo/bin/demo-session-start" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "demo-session-start-ok"
SH

  chmod +x \
    "$repo/ops/commands/cap.sh" \
    "$repo/ops/lib/yaml.sh" \
    "$repo/ops/lib/runtime-paths.sh" \
    "$repo/ops/lib/spine-log.sh" \
    "$repo/ops/lib/resolve-policy.sh" \
    "$repo/ops/plugins/demo/bin/demo-write" \
    "$repo/ops/plugins/demo/bin/demo-wave-start" \
    "$repo/ops/plugins/demo/bin/demo-session-start"

  git init "$repo" >/dev/null
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" add .
  git -C "$repo" commit -m "base" >/dev/null
  git -C "$repo" branch -M main >/dev/null
  git -C "$repo" checkout -b feature/attach-admission >/dev/null
}

echo "cap attach admission tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
make_fake_repo "$repo"

set +e
out_block="$(
  cd "$repo" && \
  env -u SPINE_ENTRY_PACKET_PATH -u SPINE_ENTRY_PACKET_HASH -u SPINE_RUNTIME_ROLE \
    SPINE_TARGET_REPO="$repo" \
    SPINE_REPO="$repo" \
    SPINE_CODE="$repo" \
    bash ops/commands/cap.sh run demo.write 2>&1
)"
rc_block=$?
set -e
if [[ "$rc_block" -ne 0 ]]; then
  pass "mutating capability blocks without attach packet"
else
  fail "mutating capability blocks without attach packet"
fi
assert_contains "$out_block" "BLOCKED: attach admission required" "missing attach env is reported"
assert_contains "$out_block" "session.v3.attach -- --allow-no-loop" "attach remediation is printed"

set +e
out_wave_block="$(
  cd "$repo" && \
  env -u SPINE_ENTRY_PACKET_PATH -u SPINE_ENTRY_PACKET_HASH -u SPINE_RUNTIME_ROLE \
    SPINE_TARGET_REPO="$repo" \
    SPINE_REPO="$repo" \
    SPINE_CODE="$repo" \
    bash ops/commands/cap.sh run orchestration.wave.start 2>&1
)"
rc_wave_block=$?
set -e
if [[ "$rc_wave_block" -ne 0 ]]; then
  pass "wave start no longer bypasses attach admission"
else
  fail "wave start no longer bypasses attach admission"
fi
assert_contains "$out_wave_block" "BLOCKED: attach admission required" "wave start attach block is reported"

out_session_start="$(
  cd "$repo" && \
  env -u SPINE_ENTRY_PACKET_PATH -u SPINE_ENTRY_PACKET_HASH -u SPINE_RUNTIME_ROLE \
    SPINE_TARGET_REPO="$repo" \
    SPINE_REPO="$repo" \
    SPINE_CODE="$repo" \
    bash ops/commands/cap.sh run session.start 2>&1
)"
assert_contains "$out_session_start" "ATTACH ADMISSION: allowlisted bootstrap/control-plane capability 'session.start'" "session.start remains bootstrap allowlisted"
assert_contains "$out_session_start" "demo-session-start-ok" "session.start still runs as allowlisted bootstrap"

packet="$tmpdir/entry.packet.yaml"
cat > "$packet" <<'YAML'
loop_id: LOOP-TEST-ATTACH
execution_mode: operational
YAML
packet_hash="$(shasum -a 256 "$packet" | awk '{print $1}')"

out_pass="$(
  cd "$repo" && \
  env SPINE_ENTRY_PACKET_PATH="$packet" SPINE_ENTRY_PACKET_HASH="$packet_hash" \
    SPINE_TARGET_REPO="$repo" \
    SPINE_REPO="$repo" \
    SPINE_CODE="$repo" \
    bash ops/commands/cap.sh run demo.write 2>&1
)"
assert_contains "$out_pass" "demo-write-ok" "mutating capability runs with valid attach packet"
assert_not_contains "$out_pass" "BLOCKED: attach admission" "valid attach packet clears admission guard"

set +e
out_hash_block="$(
  cd "$repo" && \
  env SPINE_ENTRY_PACKET_PATH="$packet" SPINE_ENTRY_PACKET_HASH="bad-hash" \
    SPINE_TARGET_REPO="$repo" \
    SPINE_REPO="$repo" \
    SPINE_CODE="$repo" \
    bash ops/commands/cap.sh run demo.write 2>&1
)"
rc_hash_block=$?
set -e
if [[ "$rc_hash_block" -ne 0 ]]; then
  pass "hash mismatch blocks attach admission"
else
  fail "hash mismatch blocks attach admission"
fi
assert_contains "$out_hash_block" "BLOCKED: attach admission packet hash mismatch" "hash mismatch is reported"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
