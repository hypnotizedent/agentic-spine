#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WAVE_SCRIPT="$ROOT/ops/commands/wave.sh"

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

assert_not_exists() {
  local path="$1" label="$2"
  if [[ ! -e "$path" ]]; then
    pass "$label"
  else
    fail "$label (found: $path)"
  fi
}

extract_preflight_function() {
  python3 - "$WAVE_SCRIPT" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
match = re.search(r"(dispatch_pushability_preflight\(\) \{\n.*?\n\})\n\ncmd_dispatch\(\)", text, re.S)
if not match:
    raise SystemExit("unable to extract dispatch_pushability_preflight()")
print(match.group(1))
PY
}

invoke_preflight() {
  local func_file="$1" state_file="$2" lane="$3" repo_root="$4" state_root="$5"
  env SPINE_REPO="$repo_root" SPINE_STATE="$state_root" bash -lc '
    set -euo pipefail
    source "$1"
    dispatch_pushability_preflight "$2" "$3"
  ' _ "$func_file" "$state_file" "$lane"
}

echo "wave dispatch pushability preflight tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

func_file="$tmpdir/dispatch_pushability_preflight.sh"
extract_preflight_function > "$func_file"

controller_root="$tmpdir/controller"
mkdir -p "$controller_root"

runtime_op="$tmpdir/runtime-operational"
mkdir -p "$runtime_op/state"
operational_state="$runtime_op/operational-state.json"
cat > "$operational_state" <<'JSON'
{
  "wave_id": "WAVE-OP-TEST",
  "preflight": {
    "domain": "dispatch-pushability",
    "verdict": "no-go",
    "blockers": ["stale blocker should be cleared"]
  },
  "packet": {
    "loop_id": "LOOP-OP-TEST",
    "owner_terminal": "SPINE-CONTROL-01",
    "execution_mode": "operational",
    "transport": "mailroom",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "workspace": {}
}
JSON
operational_out="$(
  invoke_preflight "$func_file" "$operational_state" "execution" "$controller_root" "$runtime_op/state" 2>&1
)"
assert_contains "$operational_out" "git pushability skipped" "operational mode skips git preflight"
python3 - <<'PY' "$operational_state"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
gate = state["packet"]["cross_repo_pushability_gate"]
assert gate["status"] == "PASS", gate
assert gate["reason"] == "operational_or_mailroom_transport_skips_git_pushability", gate
assert gate["execution_mode"] == "operational", gate
assert gate["transport"] == "mailroom", gate
assert gate["failure"] == "", gate
preflight = state["preflight"]
assert preflight["verdict"] == "go", preflight
assert preflight["blockers"] == [], preflight
PY
pass "operational mode writes PASS gate and clears no-go verdict"
assert_not_exists "$runtime_op/state/orchestration/LOOP-OP-TEST/stubs" "operational mode does not create blocker stubs"

runtime_mailroom="$tmpdir/runtime-mailroom"
mkdir -p "$runtime_mailroom/state"
mailroom_state="$runtime_mailroom/mailroom-state.json"
cat > "$mailroom_state" <<'JSON'
{
  "wave_id": "WAVE-MAILROOM-TEST",
  "packet": {
    "loop_id": "LOOP-MAILROOM-TEST",
    "owner_terminal": "SPINE-CONTROL-01",
    "execution_mode": "code",
    "transport": "mailroom",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "workspace": {
    "repo": "/definitely/not/required",
    "branch": "unused"
  }
}
JSON
mailroom_out="$(
  invoke_preflight "$func_file" "$mailroom_state" "audit" "$controller_root" "$runtime_mailroom/state" 2>&1
)"
assert_contains "$mailroom_out" "transport=mailroom" "mailroom transport skips git preflight even in code mode"
python3 - <<'PY' "$mailroom_state"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
gate = state["packet"]["cross_repo_pushability_gate"]
assert gate["status"] == "PASS", gate
assert gate["transport"] == "mailroom", gate
assert gate["execution_mode"] == "code", gate
PY
pass "mailroom transport alone is enough to bypass git pushability"
assert_not_exists "$runtime_mailroom/state/orchestration/LOOP-MAILROOM-TEST/stubs" "mailroom transport does not create blocker stubs"

runtime_code="$tmpdir/runtime-code"
mkdir -p "$runtime_code/state"
code_state="$runtime_code/code-state.json"
cat > "$code_state" <<'JSON'
{
  "wave_id": "WAVE-CODE-TEST",
  "packet": {
    "loop_id": "LOOP-CODE-TEST",
    "owner_terminal": "SPINE-CONTROL-01",
    "execution_mode": "code",
    "transport": "git",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "workspace": {}
}
JSON
set +e
code_out="$(
  invoke_preflight "$func_file" "$code_state" "execution" "$controller_root" "$runtime_code/state" 2>&1
)"
code_rc=$?
set -e
if [[ "$code_rc" -ne 0 ]]; then
  pass "code/git mode still blocks when workspace repo+branch are missing"
else
  fail "code/git mode still blocks when workspace repo+branch are missing"
fi
assert_contains "$code_out" "BLOCKED: dispatch pushability preflight failed" "code/git mode still emits blocker output"
python3 - <<'PY' "$code_state"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
gate = state["packet"]["cross_repo_pushability_gate"]
assert gate["status"] == "FAIL", gate
assert "workspace.repo missing" in gate["failure"], gate
assert "workspace.branch missing" in gate["failure"], gate
preflight = state["preflight"]
assert preflight["verdict"] == "no-go", preflight
assert len(state["packet"]["stub_matrix"]) == 1, state["packet"]["stub_matrix"]
assert state["packet"]["lane_outcomes"][0]["lane_status"] == "BLOCKED", state["packet"]["lane_outcomes"]
PY
pass "code/git mode preserves existing blocking behavior"

bare_remote="$tmpdir/remote.git"
git init --bare "$bare_remote" >/dev/null
git -C "$controller_root" init >/dev/null
git -C "$controller_root" config user.name "Test User"
git -C "$controller_root" config user.email "test@example.com"
printf 'seed\n' > "$controller_root/README.md"
git -C "$controller_root" add README.md
git -C "$controller_root" commit -m "seed" >/dev/null
git -C "$controller_root" branch -M main >/dev/null
git -C "$controller_root" remote add origin "$bare_remote"
git -C "$controller_root" push -u origin main >/dev/null
git -C "$controller_root" branch codex/WAVE-PASS-TEST >/dev/null

runtime_pass="$tmpdir/runtime-pass"
mkdir -p "$runtime_pass/state"
pass_state="$runtime_pass/pass-state.json"
cat > "$pass_state" <<EOF
{
  "wave_id": "WAVE-PASS-TEST",
  "packet": {
    "loop_id": "LOOP-PASS-TEST",
    "owner_terminal": "SPINE-CONTROL-01",
    "execution_mode": "code",
    "transport": "git",
    "stub_matrix": [],
    "lane_outcomes": []
  },
  "workspace": {
    "repo": "$controller_root",
    "branch": "codex/WAVE-PASS-TEST"
  }
}
EOF
pass_out="$(
  invoke_preflight "$func_file" "$pass_state" "execution" "$controller_root" "$runtime_pass/state" 2>&1
)"
assert_contains "$pass_out" "dispatch pushability preflight: PASS" "git mode pass emits pass output"
python3 - <<'PY' "$pass_state"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
gate = state["packet"]["cross_repo_pushability_gate"]
assert gate["status"] == "PASS", gate
preflight = state["preflight"]
assert preflight["verdict"] == "go", preflight
assert preflight["blockers"] == [], preflight
assert preflight["domain"] == "dispatch-pushability", preflight
PY
pass "git mode pass writes a recognized go preflight record"

echo "════════════════════════════════════════"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
