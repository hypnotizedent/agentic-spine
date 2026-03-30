#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

PASS=0
FAIL=0
TMP_DIRS=()

cleanup() {
  for dir in "${TMP_DIRS[@]:-}"; do
    rm -rf "$dir" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT INT TERM

pass() {
  PASS=$((PASS + 1))
  echo "PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "FAIL: $1" >&2
}

assert_file_contains() {
  local file="$1" needle="$2" label="$3"
  if rg -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_cmd() {
  local label="$1"
  shift
  if "$@"; then
    pass "$label"
  else
    fail "$label"
  fi
}

make_tmpdir() {
  local dir
  dir="$(mktemp -d)"
  TMP_DIRS+=("$dir")
  printf '%s\n' "$dir"
}

init_fixture_repo() {
  local repo="$1"
  git init -q -b main "$repo"
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  printf 'seed\n' > "$repo/README.md"
  git -C "$repo" add .
  git -C "$repo" commit -q -m "init"
}

copy_runtime_libs() {
  local repo="$1"
  mkdir -p "$repo/ops/lib"
  cp "$ROOT/ops/lib/spine-paths.sh" "$repo/ops/lib/"
  cp "$ROOT/ops/lib/runtime-paths.sh" "$repo/ops/lib/"
}

echo "wave control-plane governance tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: authority-resolve allows active loop over WIP cap ──"
T1_ROOT="$(make_tmpdir)"
T1_REPO="$T1_ROOT/repo"
T1_STATE="$T1_ROOT/state"
mkdir -p "$T1_REPO/ops/plugins/core/orchestration/bin" "$T1_STATE/loop-scopes"
copy_runtime_libs "$T1_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/authority-resolve" "$T1_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T1_REPO/ops/plugins/core/orchestration/bin/authority-resolve"
init_fixture_repo "$T1_REPO"

for i in 1 2 3 4 5; do
  cat > "$T1_STATE/loop-scopes/LOOP-ACTIVE-$i.scope.md" <<EOF
---
loop_id: LOOP-ACTIVE-$i
status: active
owner: '@test'
execution_mode: single_worker
execution_readiness: runnable
objective: fixture
---
EOF
done

cat > "$T1_STATE/loop-scopes/LOOP-TARGET.scope.md" <<'EOF'
---
loop_id: LOOP-TARGET
status: active
owner: '@test'
execution_mode: single_worker
execution_readiness: runnable
objective: fixture
---
EOF

T1_JSON="$T1_ROOT/authority.json"
if env SPINE_ROOT="$T1_REPO" SPINE_STATE="$T1_STATE" \
  bash "$T1_REPO/ops/plugins/core/orchestration/bin/authority-resolve" \
    --loop-id LOOP-TARGET --json > "$T1_JSON"; then
  pass "authority-resolve exits 0 for active loop over cap"
else
  fail "authority-resolve exits 0 for active loop over cap"
fi

if python3 - "$T1_JSON" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["ready_for_dispatch"] is True
assert payload["wip_state"] == "over_cap_active_loop_allowed"
assert payload["wip_note"] == "estate already over cap; active loop allowed to continue"
PY
then
  pass "authority-resolve reports active-loop over-cap allowance in JSON"
else
  fail "authority-resolve reports active-loop over-cap allowance in JSON"
fi

echo ""
echo "── T2: wave-finish records WARN truthfully and blocks landed overclaim ──"
T2_ROOT="$(make_tmpdir)"
T2_REPO="$T2_ROOT/repo"
T2_STATE="$T2_REPO/state"
mkdir -p \
  "$T2_REPO/ops/plugins/core/orchestration/bin" \
  "$T2_REPO/ops/plugins/core/loops/bin" \
  "$T2_REPO/ops/plugins/core/lifecycle/bin" \
  "$T2_REPO/ops/plugins/core/lifecycle/lib" \
  "$T2_REPO/ops/bindings" \
  "$T2_STATE/loop-scopes"
copy_runtime_libs "$T2_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/wave-finish" "$T2_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T2_REPO/ops/plugins/core/orchestration/bin/wave-finish"

cat > "$T2_REPO/ops/plugins/core/loops/bin/loop-closeout-finalize" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
matrix=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --acceptance-matrix) matrix="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$matrix" "${SPINE_ROOT}/captured-matrix.md"
printf 'loop.closeout.finalize stub\n'
EOF
chmod +x "$T2_REPO/ops/plugins/core/loops/bin/loop-closeout-finalize"

cat > "$T2_REPO/ops/plugins/core/lifecycle/bin/gaps-authority-bridge" <<'EOF'
#!/usr/bin/env python3
print("ok")
EOF
chmod +x "$T2_REPO/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

cat > "$T2_REPO/ops/plugins/core/lifecycle/lib/gaps_sql_authority.py" <<'EOF'
from pathlib import Path


class Conn:
    def close(self):
        pass


def resolve_paths(root):
    root = Path(root)
    return root / "state" / "shared_authority.db", root / "ops" / "bindings" / "operational.gaps.yaml"


def connect(db):
    return Conn()


def ensure_schema(conn):
    return None


def bootstrap_from_yaml(conn, gaps_yaml):
    return None


def fetch_gaps(conn):
    return [
        {"id": "GAP-OPEN-1", "parent_loop": "LOOP-T-WARN", "status": "open", "severity": "critical"},
        {"id": "GAP-CLOSED-1", "parent_loop": "LOOP-T-WARN", "status": "fixed", "severity": "low"},
    ]


def gap_count(conn):
    return 20


def load_yaml(path):
    return {"gaps": [{"id": "only-one"}]}
EOF

cat > "$T2_REPO/ops/bindings/operational.gaps.yaml" <<'EOF'
gaps:
  - id: only-one
EOF

cat > "$T2_STATE/loop-scopes/LOOP-T-WARN.scope.md" <<'EOF'
---
loop_id: LOOP-T-WARN
status: active
owner: '@test'
execution_mode: orchestrator_subagents
execution_readiness: runnable
objective: fixture wave finish
---
EOF

cat > "$T2_REPO/ops/bindings/dirty.contract.yaml" <<'EOF'
status: dirty
EOF

init_fixture_repo "$T2_REPO"
printf 'dirty\n' >> "$T2_REPO/ops/bindings/dirty.contract.yaml"
git -C "$T2_REPO" branch keep-LOOP-T-WARN-residue >/dev/null

if env SPINE_ROOT="$T2_REPO" SPINE_STATE="$T2_STATE" \
  bash "$T2_REPO/ops/plugins/core/orchestration/bin/wave-finish" \
    --loop-id LOOP-T-WARN --disposition deferred > "$T2_ROOT/deferred.out"; then
  pass "wave-finish deferred succeeds with WARN surfaces"
else
  fail "wave-finish deferred succeeds with WARN surfaces"
fi

assert_file_contains "$T2_REPO/captured-matrix.md" "| runtime_agreement | runtime | WARN |" "wave-finish matrix records runtime WARN"
assert_file_contains "$T2_REPO/captured-matrix.md" "| control_plane_agreement | control-plane | WARN |" "wave-finish matrix records control-plane WARN"
assert_file_contains "$T2_REPO/captured-matrix.md" "| projection_agreement | projections | WARN |" "wave-finish matrix records projection WARN"
assert_file_contains "$T2_REPO/captured-matrix.md" "| residue_check | residue | WARN |" "wave-finish matrix records residue WARN"

set +e
env SPINE_ROOT="$T2_REPO" SPINE_STATE="$T2_STATE" \
  bash "$T2_REPO/ops/plugins/core/orchestration/bin/wave-finish" \
    --loop-id LOOP-T-WARN --disposition landed --completion-level slice_complete \
    > "$T2_ROOT/landed.out" 2>&1
T2_RC=$?
set -e
if [[ "$T2_RC" -ne 0 ]]; then
  pass "wave-finish blocks landed disposition when surfaces are not PASS"
else
  fail "wave-finish blocks landed disposition when surfaces are not PASS"
fi
assert_file_contains "$T2_ROOT/landed.out" "requires PASS on all four surfaces" "wave-finish explains landed overclaim block"

echo ""
echo "── T3: wave-execute close auto-runs wave-finish ──"
T3_ROOT="$(make_tmpdir)"
T3_REPO="$T3_ROOT/repo"
T3_RUNTIME="$T3_REPO/runtime"
mkdir -p \
  "$T3_REPO/ops/plugins/core/orchestration/bin" \
  "$T3_REPO/ops/commands" \
  "$T3_RUNTIME/waves/WAVE-20260323-01"
copy_runtime_libs "$T3_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/wave-execute" "$T3_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T3_REPO/ops/plugins/core/orchestration/bin/wave-execute"

cat > "$T3_REPO/ops/commands/wave.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="$1"; shift
case "$cmd" in
  collect) exit 0 ;;
  close) printf '%s\n' "$@" > "${SPINE_RUNTIME_ROOT}/close.args"; echo "closed $1"; exit 0 ;;
  *) echo "unsupported" >&2; exit 1 ;;
esac
EOF
chmod +x "$T3_REPO/ops/commands/wave.sh"

cat > "$T3_REPO/ops/commands/cap.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="$1"; shift
if [[ "$cmd" != "run" ]]; then
  echo "unsupported" >&2
  exit 1
fi
cap="$1"; shift
if [[ "$cap" != "wave.finish" ]]; then
  echo "unsupported cap" >&2
  exit 1
fi
printf '%s\n' "${OPS_CAP_AUTO_APPROVE:-missing}" > "${SPINE_RUNTIME_ROOT}/finish.auto_approve"
printf '%s\n' "$@" > "${SPINE_RUNTIME_ROOT}/finish.args"
echo "wave.finish stub"
EOF
chmod +x "$T3_REPO/ops/commands/cap.sh"

cat > "$T3_RUNTIME/waves/WAVE-20260323-01/authority.json" <<'EOF'
{"loop_id":"LOOP-T-CLOSE","execution_mode":"orchestrator_subagents"}
EOF

cat > "$T3_RUNTIME/waves/WAVE-20260323-01/state.json" <<'EOF'
{"status":"active","dispatches":[]}
EOF

if env SPINE_ROOT="$T3_REPO" SPINE_RUNTIME_ROOT="$T3_RUNTIME" SPINE_STATE="$T3_RUNTIME/state" \
  bash "$T3_REPO/ops/plugins/core/orchestration/bin/wave-execute" \
    close --wave-id WAVE-20260323-01 --disposition landed --completion-level slice > "$T3_ROOT/out.txt"; then
  pass "wave-execute close succeeds when auto-running wave-finish"
else
  fail "wave-execute close succeeds when auto-running wave-finish"
fi

assert_file_contains "$T3_RUNTIME/close.args" "--disposition" "wave-execute forwards disposition to wave.sh close"
assert_file_contains "$T3_RUNTIME/close.args" "landed" "wave-execute forwards landed disposition value"
assert_file_contains "$T3_RUNTIME/finish.args" "--loop-id" "wave-execute passes loop-id to wave-finish"
assert_file_contains "$T3_RUNTIME/finish.args" "LOOP-T-CLOSE" "wave-execute passes resolved loop-id to wave-finish"
assert_file_contains "$T3_RUNTIME/finish.args" "WAVE-20260323-01" "wave-execute passes wave-id to wave-finish"
assert_file_contains "$T3_RUNTIME/finish.args" "slice_complete" "wave-execute normalizes completion-level aliases for wave-finish"
assert_file_contains "$T3_RUNTIME/finish.auto_approve" "yes" "wave-execute auto-approves governed wave-finish in agent batches"
assert_file_contains "$T3_ROOT/out.txt" "Running wave.finish" "wave-execute announces auto-finish"

echo ""
echo "── T4: wave-execute start fallback rehydrates workspace metadata for dispatch ──"
T4_ROOT="$(make_tmpdir)"
T4_REPO="$T4_ROOT/repo"
T4_RUNTIME="$T4_REPO/runtime"
mkdir -p \
  "$T4_REPO/ops/plugins/core/orchestration/bin" \
  "$T4_REPO/ops/plugins/core/ops/bin" \
  "$T4_REPO/ops/commands" \
  "$T4_RUNTIME"
copy_runtime_libs "$T4_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/wave-execute" "$T4_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T4_REPO/ops/plugins/core/orchestration/bin/wave-execute"

cat > "$T4_REPO/ops/plugins/core/orchestration/bin/authority-resolve" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"loop_id":"LOOP-T-DISPATCH","status":"active","owner":"@test","execution_mode":"single_worker","objective":"fixture dispatch","ready_for_dispatch": true,"blockers":[],"linked_gaps":[]}
JSON
EOF
chmod +x "$T4_REPO/ops/plugins/core/orchestration/bin/authority-resolve"

cat > "$T4_REPO/ops/plugins/core/ops/bin/worktree-lifecycle-rehydrate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
branch=""
lane=""
repo=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) branch="$2"; shift 2 ;;
    --lane) lane="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    *) shift ;;
  esac
done
target="$repo/.wt/$lane"
mkdir -p "$target"
printf 'worktree.lifecycle.rehydrate done\n'
printf 'repo=%s\n' "$repo"
printf 'branch=%s\n' "$branch"
printf 'lane=%s\n' "$lane"
printf 'worktree=%s\n' "$target"
EOF
chmod +x "$T4_REPO/ops/plugins/core/ops/bin/worktree-lifecycle-rehydrate"

cat > "$T4_REPO/ops/commands/wave.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="$1"; shift
case "$cmd" in
  start)
    wave_id="$1"; shift
    loop_id=""
    objective=""
    worktree_mode="auto"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --loop-id) loop_id="$2"; shift 2 ;;
        --objective) objective="$2"; shift 2 ;;
        --worktree) worktree_mode="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    if [[ "$worktree_mode" != "off" ]]; then
      echo "WORKTREE PATH POLICY BLOCK: target '/tmp/forbidden' is outside enforced prefix '/tmp/allowed'" >&2
      exit 1
    fi
    wave_dir="$SPINE_RUNTIME_ROOT/waves/$wave_id"
    mkdir -p "$wave_dir"
    cat > "$wave_dir/state.json" <<JSON
{
  "wave_id": "$wave_id",
  "status": "active",
  "lifecycle_state": "active",
  "objective": "$objective",
  "dispatches": [],
  "watcher_checks": [],
  "preflight": null,
  "results": [],
  "workspace": {
    "enabled": false,
    "repo": null,
    "worktree": null,
    "branch": null,
    "lifecycle_state": "disabled",
    "note": "worktree auto-provision disabled (--worktree off)"
  },
  "packet": {
    "wave_id": "$wave_id",
    "loop_id": "$loop_id",
    "current_role": "researcher",
    "next_role": "worker",
    "cross_repo_pushability_gate": {
      "status": "PENDING",
      "repo": "",
      "branch": "",
      "failure": ""
    }
  },
  "wave_packet": {
    "wave_id": "$wave_id",
    "loop_id": "$loop_id",
    "current_role": "researcher",
    "next_role": "worker",
    "cross_repo_pushability_gate": {
      "status": "PENDING",
      "repo": "",
      "branch": "",
      "failure": ""
    }
  }
}
JSON
    echo "Wave '$wave_id' created."
    ;;
  dispatch)
    wave_id="$1"; shift
    state_file="$SPINE_RUNTIME_ROOT/waves/$wave_id/state.json"
    python3 - <<'PY' "$state_file"
import json
import sys

state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
workspace = state["workspace"]
packet = state["packet"]
assert workspace["enabled"] is True, workspace
assert workspace["repo"], workspace
assert workspace["branch"], workspace
assert workspace["worktree"], workspace
assert packet["execution_mode"] == "single_worker", packet
assert packet["transport"] == "git", packet
PY
    printf '%s\n' "$@" > "${SPINE_RUNTIME_ROOT}/dispatch.args"
    exit 0
    ;;
  collect|close|status) exit 0 ;;
  *) echo "unsupported" >&2; exit 1 ;;
esac
EOF
chmod +x "$T4_REPO/ops/commands/wave.sh"
init_fixture_repo "$T4_REPO"

if env SPINE_ROOT="$T4_REPO" SPINE_RUNTIME_ROOT="$T4_RUNTIME" SPINE_STATE="$T4_RUNTIME/state" \
  bash "$T4_REPO/ops/plugins/core/orchestration/bin/wave-execute" \
    start --loop-id LOOP-T-DISPATCH --wave-id WAVE-20260329-77 --objective "fixture fallback start" > "$T4_ROOT/start.out"; then
  pass "wave-execute start succeeds via wrapper-managed fallback"
else
  fail "wave-execute start succeeds via wrapper-managed fallback"
fi

assert_file_contains "$T4_ROOT/start.out" "wrapper-managed worktree rehydrate" "wave-execute reports wrapper-managed start fallback"

python3 - <<'PY' "$T4_RUNTIME/waves/WAVE-20260329-77/state.json" "$T4_REPO"
import json
import sys
from pathlib import Path

state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
repo = Path(sys.argv[2]).resolve()
workspace = state["workspace"]
packet = state["packet"]

assert workspace["enabled"] is True, workspace
assert Path(workspace["repo"]).resolve() == repo, workspace
assert workspace["branch"] == "codex/WAVE-20260329-77", workspace
assert Path(workspace["worktree"]).resolve() == (repo / ".wt" / "WAVE-20260329-77").resolve(), workspace
assert packet["execution_mode"] == "single_worker", packet
assert packet["transport"] == "git", packet
assert state["execution_mode"] == "single_worker", state
assert state["transport"] == "git", state
PY
pass "wave-execute fallback start stamps workspace and packet metadata"

if env SPINE_ROOT="$T4_REPO" SPINE_RUNTIME_ROOT="$T4_RUNTIME" SPINE_STATE="$T4_RUNTIME/state" \
  bash "$T4_REPO/ops/plugins/core/orchestration/bin/wave-execute" \
    dispatch --wave-id WAVE-20260329-77 --lane execution --task "repair fixture" > "$T4_ROOT/dispatch.out"; then
  pass "wave-execute dispatch succeeds after wrapper metadata sync"
else
  fail "wave-execute dispatch succeeds after wrapper metadata sync"
fi

assert_file_contains "$T4_RUNTIME/dispatch.args" "--lane" "wave-execute forwards lane to dispatch"
assert_file_contains "$T4_ROOT/dispatch.out" "DISPATCH RECORDED" "wave-execute reports successful dispatch after fallback"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
