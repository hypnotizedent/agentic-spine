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


def db_parity_snapshot(conn, gaps_yaml):
    return {
        "match": False,
        "db_count": 20,
        "yaml_count": 1,
        "in_db_not_yaml": ["GAP-OPEN-1"],
        "in_yaml_not_db": [],
    }


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
echo "── T2b: wave-finish auto-cleans safe residue before landed finish ──"
T2B_ROOT="$(make_tmpdir)"
T2B_REPO="$T2B_ROOT/repo"
T2B_STATE="$T2B_REPO/state"
mkdir -p \
  "$T2B_REPO/ops/plugins/core/orchestration/bin" \
  "$T2B_REPO/ops/plugins/core/loops/bin" \
  "$T2B_REPO/ops/plugins/core/lifecycle/bin" \
  "$T2B_REPO/ops/plugins/core/lifecycle/lib" \
  "$T2B_REPO/ops/bindings" \
  "$T2B_STATE/loop-scopes"
copy_runtime_libs "$T2B_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/wave-finish" "$T2B_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T2B_REPO/ops/plugins/core/orchestration/bin/wave-finish"

cat > "$T2B_REPO/ops/plugins/core/loops/bin/loop-closeout-finalize" <<'EOF'
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
chmod +x "$T2B_REPO/ops/plugins/core/loops/bin/loop-closeout-finalize"

cat > "$T2B_REPO/ops/plugins/core/lifecycle/bin/gaps-authority-bridge" <<'EOF'
#!/usr/bin/env python3
print("ok")
EOF
chmod +x "$T2B_REPO/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

cat > "$T2B_REPO/ops/plugins/core/lifecycle/lib/gaps_sql_authority.py" <<'EOF'
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
    return []


def gap_count(conn):
    return 1


def db_parity_snapshot(conn, gaps_yaml):
    return {
        "match": True,
        "db_count": 1,
        "yaml_count": 1,
        "in_db_not_yaml": [],
        "in_yaml_not_db": [],
    }


def load_yaml(path):
    return {"gaps": [{"id": "only-one"}]}
EOF

cat > "$T2B_REPO/ops/bindings/operational.gaps.yaml" <<'EOF'
gaps:
  - id: only-one
EOF

cat > "$T2B_STATE/loop-scopes/LOOP-T-CLEAN.scope.md" <<'EOF'
---
loop_id: LOOP-T-CLEAN
status: active
owner: '@test'
execution_mode: orchestrator_subagents
execution_readiness: runnable
objective: fixture residue cleanup
---
EOF

cat > "$T2B_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-cleanup" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="report-only"
manifest=""
json_mode=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) mode="$2"; shift 2 ;;
    --manifest) manifest="$2"; shift 2 ;;
    --json) json_mode=1; shift ;;
    *) shift ;;
  esac
done

log="${SPINE_ROOT}/cleanup.log"
touch "$log"
echo "$mode" >> "$log"

case "$mode" in
  report-only)
    if [[ "$json_mode" -eq 1 ]]; then
      cat <<JSON
{
  "delete_candidates": [
    {"path": "${SPINE_ROOT}/fake-worktree", "branch": "keep-LOOP-T-CLEAN-residue"}
  ],
  "blocked": [],
  "temp_clone_delete_candidates": [],
  "temp_clone_blocked": [],
  "stash_delete_candidates": [],
  "stash_blocked": [],
  "root_normalization": {"candidate": null, "blocked": null},
  "summary": {
    "delete_candidate_count": 1,
    "blocked_count": 0,
    "temp_clone_delete_candidate_count": 0,
    "temp_clone_blocked_count": 0,
    "stash_delete_candidate_count": 0,
    "stash_blocked_count": 0
  }
}
JSON
    else
      echo "artifact.report_json=${SPINE_ROOT}/cleanup-report.json"
    fi
    ;;
  archive-only)
    manifest="${SPINE_ROOT}/cleanup-manifest.json"
    printf '{\"items\":[]}\n' > "$manifest"
    echo "artifact.archive_manifest=$manifest"
    ;;
  delete)
    [[ "${OPS_WORKTREE_DELETE_TOKEN:-}" == "RELEASE_MAIN_CLEANUP_WINDOW" ]]
    git -C "$SPINE_ROOT" branch -D keep-LOOP-T-CLEAN-residue >/dev/null 2>&1 || true
    echo "artifact.actions=${SPINE_ROOT}/cleanup-actions.log"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x "$T2B_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-cleanup"

init_fixture_repo "$T2B_REPO"
git -C "$T2B_REPO" branch keep-LOOP-T-CLEAN-residue >/dev/null

if env SPINE_ROOT="$T2B_REPO" SPINE_STATE="$T2B_STATE" \
  bash "$T2B_REPO/ops/plugins/core/orchestration/bin/wave-finish" \
    --loop-id LOOP-T-CLEAN --disposition landed --completion-level slice_complete > "$T2B_ROOT/landed.out"; then
  pass "wave-finish lands after auto-cleaning safe residue"
else
  fail "wave-finish lands after auto-cleaning safe residue"
fi

assert_file_contains "$T2B_ROOT/landed.out" "auto-cleaned 1 lifecycle candidate" "wave-finish reports residue auto-cleanup"
assert_file_contains "$T2B_ROOT/landed.out" "Preserving parent loop continuity" "wave-finish keeps slice_complete parent loop active"
assert_file_contains "$T2B_ROOT/landed.out" "Loop Status:      active (slice_complete retains parent loop)" "wave-finish summary reports active parent loop for slice_complete"
assert_file_contains "$T2B_REPO/cleanup.log" "report-only" "wave-finish requests cleanup classification"
assert_file_contains "$T2B_REPO/cleanup.log" "archive-only" "wave-finish archives cleanup candidates before delete"
assert_file_contains "$T2B_REPO/cleanup.log" "delete" "wave-finish deletes cleanup candidates after archive"
if [[ -f "$T2B_REPO/captured-matrix.md" ]]; then
  fail "wave-finish does not invoke loop-closeout-finalize for slice_complete"
else
  pass "wave-finish skips loop-closeout-finalize for slice_complete"
fi
if git -C "$T2B_REPO" branch --list "keep-LOOP-T-CLEAN-residue" | grep -q .; then
  fail "cleanup stub removes loop residue branch"
else
  pass "cleanup stub removes loop residue branch"
fi

echo ""
echo "── T2c: wave-finish accepts archive-split gap projection parity ──"
T2C_ROOT="$(make_tmpdir)"
T2C_REPO="$T2C_ROOT/repo"
T2C_STATE="$T2C_REPO/state"
mkdir -p \
  "$T2C_REPO/ops/plugins/core/orchestration/bin" \
  "$T2C_REPO/ops/plugins/core/loops/bin" \
  "$T2C_REPO/ops/plugins/core/lifecycle/bin" \
  "$T2C_REPO/ops/plugins/core/lifecycle/lib" \
  "$T2C_REPO/ops/bindings" \
  "$T2C_REPO/ops/archive" \
  "$T2C_STATE/loop-scopes"
copy_runtime_libs "$T2C_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/wave-finish" "$T2C_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T2C_REPO/ops/plugins/core/orchestration/bin/wave-finish"

cat > "$T2C_REPO/ops/plugins/core/loops/bin/loop-closeout-finalize" <<'EOF'
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
chmod +x "$T2C_REPO/ops/plugins/core/loops/bin/loop-closeout-finalize"

cat > "$T2C_REPO/ops/plugins/core/lifecycle/bin/gaps-authority-bridge" <<'EOF'
#!/usr/bin/env python3
print("ok")
EOF
chmod +x "$T2C_REPO/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

cat > "$T2C_REPO/ops/plugins/core/lifecycle/lib/gaps_sql_authority.py" <<'EOF'
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
    return []


def gap_count(conn):
    return 6


def db_parity_snapshot(conn, gaps_yaml):
    return {
        "match": True,
        "db_count": 1,
        "yaml_count": 1,
        "in_db_not_yaml": [],
        "in_yaml_not_db": [],
        "archive_ref": "ops/archive/operational.gaps.archive.yaml",
        "archived_in_db": 5,
    }


def load_yaml(path):
    return {
        "archive_ref": "ops/archive/operational.gaps.archive.yaml",
        "gaps": [{"id": "GAP-ACTIVE-1"}],
    }
EOF

cat > "$T2C_REPO/ops/bindings/operational.gaps.yaml" <<'EOF'
archive_ref: ops/archive/operational.gaps.archive.yaml
gaps:
  - id: GAP-ACTIVE-1
EOF

cat > "$T2C_STATE/loop-scopes/LOOP-T-ARCHIVE.scope.md" <<'EOF'
---
loop_id: LOOP-T-ARCHIVE
status: active
owner: '@test'
execution_mode: orchestrator_subagents
execution_readiness: runnable
objective: fixture archive split
---
EOF

init_fixture_repo "$T2C_REPO"

if env SPINE_ROOT="$T2C_REPO" SPINE_STATE="$T2C_STATE" \
  bash "$T2C_REPO/ops/plugins/core/orchestration/bin/wave-finish" \
    --loop-id LOOP-T-ARCHIVE --disposition landed --completion-level slice_complete > "$T2C_ROOT/landed.out"; then
  pass "wave-finish lands when archive-split parity matches"
else
  fail "wave-finish lands when archive-split parity matches"
fi

assert_file_contains "$T2C_ROOT/landed.out" "Projections:    PASS" "wave-finish reports PASS for archive-split projection parity"
assert_file_contains "$T2C_ROOT/landed.out" "split=ops/archive/operational.gaps.archive.yaml" "wave-finish explains archive-split parity source"

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
    close --wave-id WAVE-20260323-01 --disposition landed --completion-level slice \
      --fixed-in abc1234 --verify-receipt /tmp/controller-verify.md --controller-only > "$T3_ROOT/out.txt"; then
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
assert_file_contains "$T3_RUNTIME/close.args" "--fixed-in" "wave-execute forwards fixed-in to wave.sh close"
assert_file_contains "$T3_RUNTIME/close.args" "--verify-receipt" "wave-execute forwards verify receipt to wave.sh close"
assert_file_contains "$T3_RUNTIME/close.args" "--controller-only" "wave-execute forwards controller-only to wave.sh close"
assert_file_contains "$T3_RUNTIME/finish.args" "--controller-only" "wave-execute forwards controller-only to wave-finish"
assert_file_contains "$T3_RUNTIME/finish.auto_approve" "yes" "wave-execute auto-approves governed wave-finish in agent batches"
assert_file_contains "$T3_ROOT/out.txt" "Running wave.finish" "wave-execute announces auto-finish"

echo ""
echo "── T3b: wave close accepts controller-only proof without force ──"
T3B_ROOT="$(make_tmpdir)"
T3B_REPO="$T3B_ROOT/repo"
T3B_RUNTIME="$T3B_ROOT/runtime"
T3B_STATE="$T3B_ROOT/state"
T3B_RECEIPTS="$T3B_ROOT/receipts"
mkdir -p \
  "$T3B_REPO/ops/lib" \
  "$T3B_REPO/ops/plugins/core/lifecycle/bin" \
  "$T3B_STATE" \
  "$T3B_RUNTIME/waves/WAVE-TEST-CTRL-01" \
  "$T3B_RECEIPTS/RCAP-20260403-TEST__verify.run__Rctrl123"
copy_runtime_libs "$T3B_REPO"
init_fixture_repo "$T3B_REPO"

cat > "$T3B_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-reconcile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{
  "summary": {},
  "worktrees": [],
  "local_branches": [],
  "temp_clones": [],
  "stashes": [],
  "root_checkout": {
    "issues": []
  }
}
JSON
EOF
chmod +x "$T3B_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-reconcile"

cat > "$T3B_RUNTIME/waves/WAVE-TEST-CTRL-01/state.json" <<EOF
{
  "wave_id": "WAVE-TEST-CTRL-01",
  "status": "active",
  "lifecycle_state": "active",
  "objective": "controller-only close proof",
  "created_at": "2026-04-03T12:00:00Z",
  "dispatches": [],
  "watcher_checks": [],
  "preflight": null,
  "results": [],
  "workspace": {
    "enabled": true,
    "repo": "$T3B_REPO",
    "worktree": "$T3B_ROOT/current-wave",
    "branch": "codex/WAVE-TEST-CTRL-01",
    "lifecycle_state": "active"
  },
  "role_flow": {
    "current_role": "researcher",
    "next_role": "worker",
    "last_transition": null
  },
  "packet": {
    "schema_version": "1.0",
    "wave_id": "WAVE-TEST-CTRL-01",
    "loop_id": "LOOP-T-CONTROLLER",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2026-04-04T12:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/"],
    "lane_outcomes": []
  }
}
EOF

CTRL_SHA="$(git -C "$T3B_REPO" rev-parse --short HEAD)"

cat > "$T3B_RECEIPTS/RCAP-20260403-TEST__verify.run__Rctrl123/receipt.exec.json" <<'EOF'
{
  "task_id": "verify.run",
  "status": "done",
  "run_keys": [
    "CAP-20260403-120000__verify.run__Rctrl123"
  ]
}
EOF

cat > "$T3B_RECEIPTS/RCAP-20260403-TEST__verify.run__Rctrl123/output.txt" <<'EOF'
{
  "scope": "fast",
  "wrapper": {
    "total": 3,
    "pass": 3,
    "fail": 0,
    "warn": 0
  },
  "blocking_fail_ids": [],
  "warning_gate_ids": []
}
EOF

cat > "$T3B_RECEIPTS/RCAP-20260403-TEST__verify.run__Rctrl123/receipt.md" <<'EOF'
# Receipt: CAP-20260403-TEST__verify.run__Rctrl123

| Field | Value |
|-------|-------|
| Capability | `verify.run` |
EOF

if env \
  SPINE_TARGET_REPO="$T3B_REPO" \
  SPINE_CODE="$T3B_REPO" \
  SPINE_REPO="$T3B_REPO" \
  SPINE_RUNTIME_ROOT="$T3B_RUNTIME" \
  SPINE_STATE="$T3B_STATE" \
  SPINE_RECEIPTS="$T3B_RECEIPTS" \
  bash "$ROOT/ops/commands/wave.sh" \
    close WAVE-TEST-CTRL-01 --disposition landed --controller-only \
    --fixed-in "$CTRL_SHA" \
    --verify-receipt "$T3B_RECEIPTS/RCAP-20260403-TEST__verify.run__Rctrl123/receipt.md" \
    > "$T3B_ROOT/out.txt"; then
  pass "wave close accepts controller-only proof without force"
else
  fail "wave close accepts controller-only proof without force"
fi

assert_file_contains "$T3B_ROOT/out.txt" "Wave 'WAVE-TEST-CTRL-01' closed." "wave close reports landed controller-only close"
assert_file_contains "$T3B_RUNTIME/waves/WAVE-TEST-CTRL-01/close-receipt.json" "\"controller_only\": true" "controller-only close receipt records lightweight mode"
assert_file_contains "$T3B_RUNTIME/waves/WAVE-TEST-CTRL-01/close-receipt.json" "\"force_closed\": false" "controller-only close avoids force-close"
assert_file_contains "$T3B_RUNTIME/waves/WAVE-TEST-CTRL-01/close-receipt.json" "\"dod_overridden\": false" "controller-only close avoids DoD override"
assert_file_contains "$T3B_RUNTIME/waves/WAVE-TEST-CTRL-01/controller-close-precheck.json" "\"eligible\": true" "controller-only close writes passing precheck proof"

echo ""
echo "── T3c: wave close still blocks controller-only slices missing proof ──"
T3C_ROOT="$(make_tmpdir)"
T3C_REPO="$T3C_ROOT/repo"
T3C_RUNTIME="$T3C_ROOT/runtime"
T3C_STATE="$T3C_ROOT/state"
mkdir -p \
  "$T3C_REPO/ops/lib" \
  "$T3C_REPO/ops/plugins/core/lifecycle/bin" \
  "$T3C_STATE" \
  "$T3C_RUNTIME/waves/WAVE-TEST-CTRL-02"
copy_runtime_libs "$T3C_REPO"
init_fixture_repo "$T3C_REPO"

cat > "$T3C_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-reconcile" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{
  "summary": {},
  "worktrees": [
    {
      "path": "/tmp/fixture-wave",
      "branch": "codex/WAVE-TEST-CTRL-02",
      "owner_id": "",
      "issues": [
        "merged_branch_past_grace"
      ]
    }
  ],
  "local_branches": [],
  "temp_clones": [],
  "stashes": [],
  "root_checkout": {
    "issues": []
  }
}
JSON
EOF
chmod +x "$T3C_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-reconcile"

cat > "$T3C_RUNTIME/waves/WAVE-TEST-CTRL-02/state.json" <<EOF
{
  "wave_id": "WAVE-TEST-CTRL-02",
  "status": "active",
  "lifecycle_state": "active",
  "objective": "controller-only close should block honestly",
  "created_at": "2026-04-03T12:00:00Z",
  "dispatches": [],
  "watcher_checks": [],
  "preflight": null,
  "results": [],
  "workspace": {
    "enabled": true,
    "repo": "$T3C_REPO",
    "worktree": "/tmp/fixture-wave",
    "branch": "codex/WAVE-TEST-CTRL-02",
    "lifecycle_state": "active"
  },
  "role_flow": {
    "current_role": "researcher",
    "next_role": "worker",
    "last_transition": null
  },
  "packet": {
    "schema_version": "1.0",
    "wave_id": "WAVE-TEST-CTRL-02",
    "loop_id": "LOOP-T-CONTROLLER",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2026-04-04T12:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/"],
    "lane_outcomes": []
  }
}
EOF

CTRL_SHA_MISSING="$(git -C "$T3C_REPO" rev-parse --short HEAD)"

set +e
env \
  SPINE_TARGET_REPO="$T3C_REPO" \
  SPINE_CODE="$T3C_REPO" \
  SPINE_REPO="$T3C_REPO" \
  SPINE_RUNTIME_ROOT="$T3C_RUNTIME" \
  SPINE_STATE="$T3C_STATE" \
  bash "$ROOT/ops/commands/wave.sh" \
    close WAVE-TEST-CTRL-02 --disposition landed --controller-only --fixed-in "$CTRL_SHA_MISSING" \
    > "$T3C_ROOT/out.txt" 2>&1
T3C_RC=$?
set -e

if [[ "$T3C_RC" -ne 0 ]]; then
  pass "wave close blocks controller-only when verify/cleanup proof is missing"
else
  fail "wave close blocks controller-only when verify/cleanup proof is missing"
fi
assert_file_contains "$T3C_ROOT/out.txt" "controller-only requires --verify-receipt" "controller-only close explains missing verify proof"
assert_file_contains "$T3C_ROOT/out.txt" "controller-only cleanup residue unresolved" "controller-only close explains cleanup residue block"

echo ""
echo "── T4: wave-execute start fallback rehydrates workspace metadata for dispatch ──"
T4_ROOT="$(make_tmpdir)"
T4_REPO="$T4_ROOT/repo"
T4_RUNTIME="$T4_REPO/runtime"
mkdir -p \
  "$T4_REPO/ops/plugins/core/orchestration/bin" \
  "$T4_REPO/ops/plugins/core/lifecycle/bin" \
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

cat > "$T4_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-rehydrate" <<'EOF'
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
chmod +x "$T4_REPO/ops/plugins/core/lifecycle/bin/worktree-lifecycle-rehydrate"

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
echo "── T5: wave-execute land stages deleted allowlisted files ──"
T5_ROOT="$(make_tmpdir)"
T5_REMOTE="$T5_ROOT/remote.git"
T5_REPO="$T5_ROOT/repo"
T5_RUNTIME="$T5_REPO/runtime"
mkdir -p \
  "$T5_REPO/ops/plugins/core/orchestration/bin" \
  "$T5_REPO/ops/plugins/core/verify/bin" \
  "$T5_RUNTIME/waves/WAVE-20260331-02"
copy_runtime_libs "$T5_REPO"
cp "$ROOT/ops/plugins/core/orchestration/bin/wave-execute" "$T5_REPO/ops/plugins/core/orchestration/bin/"
chmod +x "$T5_REPO/ops/plugins/core/orchestration/bin/wave-execute"

git init -q --bare "$T5_REMOTE"
git init -q -b main "$T5_REPO"
git -C "$T5_REPO" config user.name "Test User"
git -C "$T5_REPO" config user.email "test@example.com"
git -C "$T5_REPO" remote add origin "$T5_REMOTE"

cat > "$T5_REPO/ops/plugins/core/verify/bin/verify-run" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "wrapper: pass=1 fail=0 warn=0"
EOF
chmod +x "$T5_REPO/ops/plugins/core/verify/bin/verify-run"

printf 'keep\n' > "$T5_REPO/README.md"
mkdir -p "$T5_REPO/ops/plugins/core/conflicts"
printf 'legacy\n' > "$T5_REPO/ops/plugins/core/conflicts/README.md"
git -C "$T5_REPO" add .
git -C "$T5_REPO" commit -q -m "init"
git -C "$T5_REPO" push -q -u origin main

cat > "$T5_RUNTIME/waves/WAVE-20260331-02/authority.json" <<'EOF'
{"loop_id":"LOOP-T-LAND","execution_mode":"orchestrator_subagents"}
EOF

rm "$T5_REPO/ops/plugins/core/conflicts/README.md"

if env SPINE_ROOT="$T5_REPO" SPINE_RUNTIME_ROOT="$T5_RUNTIME" SPINE_STATE="$T5_RUNTIME/state" OPS_GOVERNED_MAIN_OVERRIDE=1 \
  bash "$T5_REPO/ops/plugins/core/orchestration/bin/wave-execute" \
    land --wave-id WAVE-20260331-02 \
    --files ops/plugins/core/conflicts/README.md \
    --summary "remove dormant conflicts fixture" > "$T5_ROOT/land.out"; then
  pass "wave-execute land accepts deleted allowlisted file"
else
  fail "wave-execute land accepts deleted allowlisted file"
fi

assert_file_contains "$T5_ROOT/land.out" "Staged 1 file(s)" "wave-execute land stages deleted allowlisted file"
git -C "$T5_REPO" show --pretty=format: --name-status HEAD > "$T5_ROOT/show.txt"
assert_file_contains "$T5_ROOT/show.txt" $'D\tops/plugins/core/conflicts/README.md' "wave-execute land commit records deleted file only"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
