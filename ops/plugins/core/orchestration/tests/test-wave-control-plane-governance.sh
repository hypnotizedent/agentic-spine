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
  close) echo "closed $1"; exit 0 ;;
  *) echo "unsupported" >&2; exit 1 ;;
esac
EOF
chmod +x "$T3_REPO/ops/commands/wave.sh"

cat > "$T3_REPO/ops/plugins/core/orchestration/bin/wave-finish" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${SPINE_RUNTIME_ROOT}/finish.args"
echo "wave.finish stub"
EOF
chmod +x "$T3_REPO/ops/plugins/core/orchestration/bin/wave-finish"

cat > "$T3_RUNTIME/waves/WAVE-20260323-01/authority.json" <<'EOF'
{"loop_id":"LOOP-T-CLOSE","execution_mode":"orchestrator_subagents"}
EOF

cat > "$T3_RUNTIME/waves/WAVE-20260323-01/state.json" <<'EOF'
{"status":"active","dispatches":[]}
EOF

if env SPINE_ROOT="$T3_REPO" SPINE_RUNTIME_ROOT="$T3_RUNTIME" SPINE_STATE="$T3_RUNTIME/state" \
  bash "$T3_REPO/ops/plugins/core/orchestration/bin/wave-execute" \
    close --wave-id WAVE-20260323-01 --disposition deferred > "$T3_ROOT/out.txt"; then
  pass "wave-execute close succeeds when auto-running wave-finish"
else
  fail "wave-execute close succeeds when auto-running wave-finish"
fi

assert_file_contains "$T3_RUNTIME/finish.args" "--loop-id" "wave-execute passes loop-id to wave-finish"
assert_file_contains "$T3_RUNTIME/finish.args" "LOOP-T-CLOSE" "wave-execute passes resolved loop-id to wave-finish"
assert_file_contains "$T3_RUNTIME/finish.args" "WAVE-20260323-01" "wave-execute passes wave-id to wave-finish"
assert_file_contains "$T3_ROOT/out.txt" "Running wave.finish" "wave-execute announces auto-finish"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
