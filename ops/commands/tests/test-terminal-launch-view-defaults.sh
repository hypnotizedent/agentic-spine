#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Test: terminal-launch view-defaults + explicit flag precedence
# ═══════════════════════════════════════════════════════════════════════════
# Runs offline with temp fixtures. No iTerm side effects (DRY_RUN mode).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/ops/commands/terminal-launch.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
    local haystack="$1" needle="$2" label="$3"
    if echo "$haystack" | grep -Fq -- "$needle"; then
        pass "$label"
    else
        fail "$label (expected: $needle)"
    fi
}

assert_eq() {
    local actual="$1" expected="$2" label="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected='$expected', got='$actual')"
    fi
}

echo "terminal-launch view-defaults + explicit precedence tests"
echo "════════════════════════════════════════"

# ── Set up temp fixture environment ──────────────────────────────────────

TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

FAKE_SPINE="$TMPDIR_BASE/spine"
FAKE_WORKBENCH="$TMPDIR_BASE/workbench"
mkdir -p "$FAKE_SPINE/ops/bindings"
mkdir -p "$FAKE_SPINE/mailroom/state/loop-scopes"
mkdir -p "$FAKE_WORKBENCH/scripts/root"

# Fixture: terminal.launcher.view.yaml (3 terminals with distinct defaults)
cat > "$FAKE_SPINE/ops/bindings/terminal.launcher.view.yaml" <<'FIXTURE_VIEW'
terminals:
  ALPHA-CORE-01:
    terminal_id: ALPHA-CORE-01
    label: Alpha Core
    status: active
    picker_group: core
    sort_order: 100
    default_tool: codex
    domain: core
    lane_profile: control
  BETA-DOMAIN-01:
    terminal_id: BETA-DOMAIN-01
    label: Beta Domain
    status: active
    picker_group: domain-runtime
    sort_order: 300
    default_tool: claude
    domain: home-automation
    lane_profile: execution
  GAMMA-WATCH-01:
    terminal_id: GAMMA-WATCH-01
    label: Gamma Watch
    status: planned
    picker_group: observation
    sort_order: 200
    default_tool: opencode
    domain: core
    lane_profile: watcher
FIXTURE_VIEW

# Fixture: lane.profiles.yaml (minimal)
cat > "$FAKE_SPINE/ops/bindings/lane.profiles.yaml" <<'FIXTURE_LANES'
profiles:
  control:
    description: Control lane
    mode: read-write
    can_merge: true
  execution:
    description: Execution lane
    mode: read-write
    can_merge: false
FIXTURE_LANES

# Fixture: fake launcher script (executable, does nothing)
cat > "$FAKE_WORKBENCH/scripts/root/spine_terminal_entry.sh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$FAKE_WORKBENCH/scripts/root/spine_terminal_entry.sh"

# Common env for all test runs
export SPINE_REPO="$FAKE_SPINE"
export WORKBENCH_ROOT="$FAKE_WORKBENCH"
export TERMINAL_LAUNCH_DRY_RUN=1

# ── T1: list-roles returns JSON array with expected count ────────────────

echo ""
echo "── T1: list-roles JSON array count ──"
roles_out=$(bash "$SCRIPT" list-roles 2>&1)
role_count=$(echo "$roles_out" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "ERR")
assert_eq "$role_count" "3" "list-roles returns 3 roles from fixture"

# ── T2: list-roles sorted by sort_order then id ─────────────────────────

echo ""
echo "── T2: list-roles sort order ──"
sort_check=$(echo "$roles_out" | python3 -c "
import sys, json
roles = json.load(sys.stdin)
ids = [r['id'] for r in roles]
orders = [r['sort_order'] for r in roles]
# Expected: ALPHA(100) < GAMMA(200) < BETA(300)
if ids == ['ALPHA-CORE-01', 'GAMMA-WATCH-01', 'BETA-DOMAIN-01'] and orders == sorted(orders):
    print('sorted')
else:
    print(f'wrong: {ids}')
" 2>/dev/null || echo "ERR")
assert_eq "$sort_check" "sorted" "list-roles sorted by sort_order then id"

# ── T3: launch --terminal uses view defaults for lane/tool ───────────────

echo ""
echo "── T3: view defaults apply ──"
t3_out=$(bash "$SCRIPT" launch --terminal BETA-DOMAIN-01 2>&1)
assert_contains "$t3_out" "lane=execution" "view default lane=execution"
assert_contains "$t3_out" "tool=claude" "view default tool=claude"
assert_contains "$t3_out" "terminal=BETA-DOMAIN-01" "terminal passed through"

# ── T4: explicit --lane --tool wins over view ────────────────────────────

echo ""
echo "── T4: explicit flags win ──"
t4_out=$(bash "$SCRIPT" launch --terminal BETA-DOMAIN-01 --lane audit --tool verify 2>&1)
assert_contains "$t4_out" "lane=audit" "explicit lane=audit wins over view execution"
assert_contains "$t4_out" "tool=verify" "explicit tool=verify wins over view claude"

# ── T5: explicit --tool opencode preserved when view default differs ─────

echo ""
echo "── T5: explicit --tool opencode preserved ──"
t5_out=$(bash "$SCRIPT" launch --terminal BETA-DOMAIN-01 --tool opencode 2>&1)
assert_contains "$t5_out" "tool=opencode" "explicit --tool opencode wins over view claude"
assert_contains "$t5_out" "lane=execution" "lane still filled from view"

# ── T6: missing view file → list-roles returns [], launch fallback ───────

echo ""
echo "── T6: missing view file fallback ──"
saved_view="$FAKE_SPINE/ops/bindings/terminal.launcher.view.yaml"
mv "$saved_view" "${saved_view}.bak"

no_view_roles=$(bash "$SCRIPT" list-roles 2>&1)
assert_eq "$no_view_roles" "[]" "list-roles returns [] when view missing"

# Launch with --lane (no view to resolve from)
t6_out=$(bash "$SCRIPT" launch --lane control --tool codex 2>&1)
assert_contains "$t6_out" "lane=control" "fallback launch works with --lane"
assert_contains "$t6_out" "tool=codex" "fallback launch uses explicit tool"

mv "${saved_view}.bak" "$saved_view"

# ── T7: --help includes list-roles ───────────────────────────────────────

echo ""
echo "── T7: --help includes list-roles ──"
help_out=$(bash "$SCRIPT" --help 2>&1)
assert_contains "$help_out" "list-roles" "--help mentions list-roles"

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
