#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
PARITY_GUARD="$ROOT/ops/plugins/core/session/bin/session-start-main-parity-guard"
SESSION_START="$ROOT/ops/plugins/core/session/bin/session-start"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (expected: $needle)"
  fi
}

echo "session-start main parity guard tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

REMOTE="$TMPDIR_BASE/remote.git"
WORK="$TMPDIR_BASE/work"
STATE_ROOT="$TMPDIR_BASE/state"
RUNTIME_ROOT="$TMPDIR_BASE/runtime"

git init --bare "$REMOTE" >/dev/null
git clone "$REMOTE" "$WORK" >/dev/null 2>&1
git -C "$WORK" config user.name "Test User"
git -C "$WORK" config user.email "test@example.com"
git -C "$WORK" checkout -b main >/dev/null 2>&1
printf 'base\n' > "$WORK/file.txt"
git -C "$WORK" add file.txt
git -C "$WORK" commit -m "base" >/dev/null
git -C "$WORK" push -u origin main >/dev/null 2>&1

export SPINE_STATE="$STATE_ROOT"
export SPINE_RUNTIME_ROOT="$RUNTIME_ROOT"

STARTUP_NOOP_STUB="$TMPDIR_BASE/session-startup-noop.sh"
cat > "$STARTUP_NOOP_STUB" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$STARTUP_NOOP_STUB"

echo ""
echo "── T1: clean main parity passes ──"
set +e
t1_out="$(cd "$WORK" && "$PARITY_GUARD" 2>&1)"
t1_status=$?
set -e
assert_eq "$t1_status" "0" "clean main checkout passes"

echo ""
echo "── T2: diverged main blocks ──"
printf 'ahead\n' >> "$WORK/file.txt"
git -C "$WORK" commit -am "ahead local" >/dev/null
set +e
t2_out="$(cd "$WORK" && "$PARITY_GUARD" 2>&1)"
t2_status=$?
set -e
assert_eq "$t2_status" "1" "diverged main exits non-zero"
assert_contains "$t2_out" "Current branch is 'main'" "block message identifies main"
assert_contains "$t2_out" "ahead: 1" "block message reports ahead count"
assert_contains "$t2_out" "Use a worktree branch for real task work." "block message points to worktree flow"

echo ""
echo "── T3: override allows diverged main and logs reason ──"
set +e
t3_out="$(cd "$WORK" && "$PARITY_GUARD" --allow-main-divergence --main-divergence-reason "test override" 2>&1)"
t3_status=$?
set -e
assert_eq "$t3_status" "0" "override permits diverged main"
assert_contains "$t3_out" "Proceeding with main-divergence override" "override path is explicit"
log_file="$STATE_ROOT/main-divergence-overrides/main-divergence-override-log.csv"
if [[ -f "$log_file" ]]; then
  pass "override log file created"
else
  fail "override log file created"
fi
assert_contains "$(cat "$log_file")" "test override" "override reason logged"

echo ""
echo "── T4: non-main branch is ignored ──"
git -C "$WORK" switch -c feature/local >/dev/null
set +e
t4_out="$(cd "$WORK" && "$PARITY_GUARD" 2>&1)"
t4_status=$?
set -e
assert_eq "$t4_status" "0" "non-main branch bypasses guard"
assert_eq "$t4_out" "" "non-main branch stays quiet"

echo ""
echo "── T5: session-start --help no longer parses as lane ──"
set +e
t5_out="$("$SESSION_START" --help 2>&1)"
t5_status=$?
set -e
assert_eq "$t5_status" "1" "--help exits with usage status"
assert_contains "$t5_out" "session-start [--mode fast|full|degraded]" "help prints usage"
assert_contains "$t5_out" "startup blocks dirty checkouts and clean-but-diverged main checkouts by default." "help documents parity guard"

echo ""
echo "── T6: coordinator env activation does not leak governed main override ──"
git -C "$WORK" switch main >/dev/null
git -C "$WORK" reset --hard origin/main >/dev/null
set +e
t6_out="$(cd "$WORK" && SPINE_ROOT_BORING_RECONCILE_BIN="$STARTUP_NOOP_STUB" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STARTUP_NOOP_STUB" "$SESSION_START" coordinator 2>&1)"
t6_status=$?
set -e
assert_eq "$t6_status" "0" "coordinator startup succeeds on clean main"
env_file="$(printf '%s\n' "$t6_out" | sed -n 's/^  source \(.*env\.sh\)$/\1/p' | tail -1)"
if [[ -n "$env_file" && -f "$env_file" ]]; then
  pass "coordinator env file emitted"
else
  fail "coordinator env file emitted"
fi
if grep -Fq 'OPS_GOVERNED_MAIN_OVERRIDE' "$env_file"; then
  fail "coordinator env file does not export governed main override"
else
  pass "coordinator env file does not export governed main override"
fi

echo ""
echo "── T7: session-start triggers root boring reconcile path ──"
root_stub="$TMPDIR_BASE/session-root-stub.sh"
root_log="$TMPDIR_BASE/session-root.log"
cat > "$root_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${ROOT_STUB_LOG:?}"
EOF
chmod +x "$root_stub"
set +e
t7_out="$(cd "$WORK" && ROOT_STUB_LOG="$root_log" SPINE_ROOT_BORING_RECONCILE_BIN="$root_stub" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STARTUP_NOOP_STUB" "$SESSION_START" 2>&1)"
t7_status=$?
set -e
assert_eq "$t7_status" "0" "fast startup succeeds with root normalize stub"
assert_contains "$(cat "$root_log")" "--trigger session.start.fast --brief" "fast startup invokes root boring reconcile"

echo ""
echo "── T8: session-start fails closed when root boring reconcile blocks ──"
root_fail_stub="$TMPDIR_BASE/session-root-fail-stub.sh"
cat > "$root_fail_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "forced root normalize failure" >&2
exit 1
EOF
chmod +x "$root_fail_stub"
set +e
t8_out="$(cd "$WORK" && SPINE_ROOT_BORING_RECONCILE_BIN="$root_fail_stub" "$SESSION_START" 2>&1)"
t8_status=$?
set -e
assert_eq "$t8_status" "1" "startup exits non-zero when root reconcile blocks"
assert_contains "$t8_out" "session.start FAIL: root boring reconcile blocked" "root reconcile failure is explicit"

echo ""
echo "── T9: session-start triggers managed worktree sync path ──"
sync_stub="$TMPDIR_BASE/session-sync-stub.sh"
sync_log="$TMPDIR_BASE/session-sync.log"
cat > "$sync_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SYNC_STUB_LOG:?}"
EOF
chmod +x "$sync_stub"
set +e
t9_out="$(cd "$WORK" && SYNC_STUB_LOG="$sync_log" SPINE_MANAGED_WORKTREE_SYNC_BIN="$sync_stub" "$SESSION_START" 2>&1)"
t9_status=$?
set -e
assert_eq "$t9_status" "0" "fast startup succeeds with sync stub"
assert_contains "$(cat "$sync_log")" "--trigger session.start.fast --brief" "fast startup invokes managed sync runner"

echo ""
echo "── T10: degraded mode emits continuity packet ──"
set +e
t10_out="$(cd "$WORK" && SPINE_ROOT_BORING_RECONCILE_BIN="$STARTUP_NOOP_STUB" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STARTUP_NOOP_STUB" "$SESSION_START" degraded 2>&1)"
t10_status=$?
set -e
assert_eq "$t10_status" "0" "degraded startup succeeds on clean main"
assert_contains "$t10_out" "mode: degraded" "degraded mode is explicit"
assert_contains "$t10_out" "logical_state_path: mailroom/state" "degraded mode exposes logical state path"
assert_contains "$t10_out" "runtime_state_root: $STATE_ROOT" "degraded mode exposes runtime state root"
assert_contains "$t10_out" "./bin/ops cap run receipts.summary -- --domain none --days 7" "degraded mode emits receipts fallback hint"
assert_contains "$t10_out" "./bin/ops cap run loops.status" "degraded mode emits loop fallback hint"

echo ""
echo "── T11: fast startup surfaces mint operator storage advisory hint ──"
mint_stub="$TMPDIR_BASE/session-mint-storage-stub.sh"
cat > "$mint_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "status=fail mode=mounted_operator_drop remote=ok mount=INACTIVE operator_drop=missing desktop_legacy=dirty fallback=1"
EOF
chmod +x "$mint_stub"
set +e
t11_out="$(cd "$WORK" && SPINE_ROOT_BORING_RECONCILE_BIN="$STARTUP_NOOP_STUB" SPINE_MANAGED_WORKTREE_SYNC_BIN="$STARTUP_NOOP_STUB" SPINE_MINT_OPERATOR_STORAGE_STATUS_BIN="$mint_stub" "$SESSION_START" 2>&1)"
t11_status=$?
set -e
assert_eq "$t11_status" "0" "fast startup succeeds with mint operator storage stub"
assert_contains "$t11_out" "mint_operator_storage: status=fail mode=mounted_operator_drop remote=ok mount=INACTIVE operator_drop=missing desktop_legacy=dirty fallback=1" "fast startup prints mint operator storage advisory"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
