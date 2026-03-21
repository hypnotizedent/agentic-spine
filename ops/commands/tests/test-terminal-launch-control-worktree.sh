#!/usr/bin/env bash
set -euo pipefail

REAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LAUNCH_SCRIPT="$REAL_ROOT/ops/commands/terminal-launch.sh"
HELPER_SRC="$REAL_ROOT/ops/lib/launcher-control-worktree.sh"
EXEC_SRC="$REAL_ROOT/ops/plugins/core/session/bin/terminal-launch-exec"

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

echo "terminal launch control worktree tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

FAKE_ROOT="$TMPDIR_BASE/agentic-spine"
CONTROL_WT="$TMPDIR_BASE/.wt/agentic-spine/control-plane"
WORKBENCH="$TMPDIR_BASE/workbench"
SESSION_ENV="$TMPDIR_BASE/session-env.sh"
mkdir -p \
  "$FAKE_ROOT/bin" \
  "$FAKE_ROOT/ops/lib" \
  "$FAKE_ROOT/ops/bindings" \
  "$FAKE_ROOT/ops/plugins/core/session/bin" \
  "$FAKE_ROOT/ops/plugins/core/orchestration/bin" \
  "$FAKE_ROOT/mailroom/state/loop-scopes" \
  "$WORKBENCH"

cat > "$FAKE_ROOT/ops/lib/runtime-paths.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
spine_runtime_resolve_paths() {
  SPINE_TARGET_REPO="${SPINE_TARGET_REPO:-${SPINE_REPO:-$PWD}}"
  SPINE_REPO="$SPINE_TARGET_REPO"
  SPINE_CODE="$SPINE_TARGET_REPO"
  SPINE_STATE="${SPINE_STATE:-$SPINE_TARGET_REPO/mailroom/state}"
  SPINE_TMP="${SPINE_TMP:-$SPINE_TARGET_REPO/.runtime/tmp}"
  export SPINE_TARGET_REPO SPINE_REPO SPINE_CODE SPINE_STATE SPINE_TMP
}
SH

cat > "$FAKE_ROOT/ops/lib/spine-paths.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/runtime-paths.sh"
spine_paths_init() {
  spine_runtime_resolve_paths
  export SPINE_TARGET_REPO SPINE_REPO SPINE_CODE SPINE_STATE SPINE_TMP
}
SH

cat > "$FAKE_ROOT/bin/ops" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "fake ops $*" >/dev/null
SH

cat > "$FAKE_ROOT/ops/bindings/lane.profiles.yaml" <<'YAML'
profiles:
  control:
    description: Control lane
    mode: read-write
YAML

cat > "$FAKE_ROOT/ops/bindings/terminal.launcher.view.yaml" <<'YAML'
terminals:
  SPINE-CONTROL-01:
    terminal_id: SPINE-CONTROL-01
    label: Spine Control
    status: active
    picker_group: core
    sort_order: 100
    default_tool: verify
    allowed_tools:
      - verify
      - codex
    lane_profile: control
YAML

cat > "$FAKE_ROOT/ops/bindings/terminal.role.contract.yaml" <<'YAML'
runtime_role_defaults:
  by_terminal_id:
    SPINE-CONTROL-01: researcher
  by_terminal_type: {}
roles:
  - id: SPINE-CONTROL-01
    type: control
YAML

cat > "$FAKE_ROOT/ops/bindings/role.runtime.control.contract.yaml" <<'YAML'
runtime_roles:
  default_role: researcher
YAML

cat > "$FAKE_ROOT/ops/bindings/worktree.lifecycle.contract.yaml" <<YAML
version: "1.4"
updated: "2026-03-21"
owner: "@test"
scope: worktree-lifecycle
policy:
  main_branch: "main"
  managed_worktree_paths:
    - "$CONTROL_WT"
  launcher_control_worktree_path: "$CONTROL_WT"
  launcher_control_worktree_branch: "runtime/control-plane"
  launcher_control_worktree_base_ref: "main"
YAML

cat > "$FAKE_ROOT/ops/plugins/core/session/bin/session-start" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "session_start_target_repo=\${SPINE_TARGET_REPO:-}"
echo "session_start_repo=\${SPINE_REPO:-}"
echo "session_start_code=\${SPINE_CODE:-}"
cat > "$SESSION_ENV" <<'SH'
export SPINE_SESSION_ID=TEST-SESSION
SH
echo "  source $SESSION_ENV"
EOF

cat > "$FAKE_ROOT/ops/plugins/core/orchestration/bin/orchestration-launcher-plan" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "orchestration.launcher.plan"
echo "role=solo"
echo "loop_id="
echo "lane="
echo "repo="
echo "branch="
echo "worktree="
echo "worktree_exists=false"
echo "resolution_mode=solo"
echo "active_lock_count=0"
SH

cp "$HELPER_SRC" "$FAKE_ROOT/ops/lib/launcher-control-worktree.sh"
cp "$EXEC_SRC" "$FAKE_ROOT/ops/plugins/core/session/bin/terminal-launch-exec"

chmod +x \
  "$FAKE_ROOT/bin/ops" \
  "$FAKE_ROOT/ops/lib/runtime-paths.sh" \
  "$FAKE_ROOT/ops/lib/spine-paths.sh" \
  "$FAKE_ROOT/ops/lib/launcher-control-worktree.sh" \
  "$FAKE_ROOT/ops/plugins/core/session/bin/session-start" \
  "$FAKE_ROOT/ops/plugins/core/session/bin/terminal-launch-exec" \
  "$FAKE_ROOT/ops/plugins/core/orchestration/bin/orchestration-launcher-plan"

git init "$FAKE_ROOT" >/dev/null
git -C "$FAKE_ROOT" config user.name "Test User"
git -C "$FAKE_ROOT" config user.email "test@example.com"
git -C "$FAKE_ROOT" add .
git -C "$FAKE_ROOT" commit -m "base" >/dev/null
git -C "$FAKE_ROOT" branch -M main >/dev/null
git -C "$FAKE_ROOT" checkout -b feature/dirty-root >/dev/null
printf 'dirty\n' > "$FAKE_ROOT/dirty.txt"

set +e
launch_out="$(
  cd "$FAKE_ROOT" && \
  env SPINE_LAUNCHER_SOURCE_REPO="$FAKE_ROOT" WORKBENCH_ROOT="$WORKBENCH" TERMINAL_LAUNCH_DRY_RUN=1 \
    bash "$LAUNCH_SCRIPT" launch --terminal SPINE-CONTROL-01 --tool verify 2>&1
)"
launch_rc=$?
set -e
if [[ "$launch_rc" -eq 0 ]]; then
  pass "launcher dry-run succeeds from dirty root checkout"
else
  fail "launcher dry-run succeeds from dirty root checkout"
  echo "$launch_out" >&2
fi

assert_contains "$launch_out" "command=cd '$CONTROL_WT'" "launcher command targets control worktree"
assert_contains "$launch_out" "'$CONTROL_WT/bin/ops'" "launcher command uses control worktree ops runner"

if [[ -e "$CONTROL_WT/.git" ]]; then
  pass "launcher auto-created control worktree"
else
  fail "launcher auto-created control worktree"
fi

printf 'drift\n' >> "$CONTROL_WT/ops/bindings/lane.profiles.yaml"
set +e
launch_out_dirty="$(
  cd "$FAKE_ROOT" && \
  env SPINE_LAUNCHER_SOURCE_REPO="$FAKE_ROOT" WORKBENCH_ROOT="$WORKBENCH" TERMINAL_LAUNCH_DRY_RUN=1 \
    bash "$LAUNCH_SCRIPT" launch --terminal SPINE-CONTROL-01 --tool verify 2>&1
)"
launch_dirty_rc=$?
set -e
if [[ "$launch_dirty_rc" -eq 0 ]]; then
  pass "launcher dry-run self-heals dirty control worktree"
else
  fail "launcher dry-run self-heals dirty control worktree"
  echo "$launch_out_dirty" >&2
fi

if [[ -z "$(git -C "$CONTROL_WT" status --porcelain 2>/dev/null || true)" ]]; then
  pass "launcher refresh returns control worktree to clean state"
else
  fail "launcher refresh returns control worktree to clean state"
fi

set +e
exec_out="$(
  cd "$FAKE_ROOT" && \
  env \
    SPINE_ROOT="$FAKE_ROOT" \
    SPINE_REPO="$FAKE_ROOT" \
    SPINE_CODE="$FAKE_ROOT" \
    SPINE_TARGET_REPO="$FAKE_ROOT" \
    WORKBENCH_ROOT="$WORKBENCH" \
    "$FAKE_ROOT/ops/plugins/core/session/bin/terminal-launch-exec" \
      --role solo --tool verify --terminal-name SPINE-CONTROL-01 --dry-run 2>&1
)"
exec_rc=$?
set -e
if [[ "$exec_rc" -eq 0 ]]; then
  pass "terminal-launch-exec dry-run succeeds from dirty root checkout"
else
  fail "terminal-launch-exec dry-run succeeds from dirty root checkout"
  echo "$exec_out" >&2
fi

assert_contains "$exec_out" "spine_root=$CONTROL_WT" "terminal-launch-exec resolves control worktree as spine root"
assert_contains "$exec_out" "session_start=$CONTROL_WT/ops/plugins/core/session/bin/session-start" "terminal-launch-exec uses control worktree session-start"
assert_contains "$exec_out" "launch_cwd=$CONTROL_WT" "terminal-launch-exec launches from control worktree"
assert_contains "$exec_out" "session_start_target_repo=$CONTROL_WT" "terminal-launch-exec pins session-start target repo to control worktree"
assert_contains "$exec_out" "session_start_repo=$CONTROL_WT" "terminal-launch-exec pins session-start repo to control worktree"
assert_contains "$exec_out" "session_start_code=$CONTROL_WT" "terminal-launch-exec pins session-start control root to control worktree"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
