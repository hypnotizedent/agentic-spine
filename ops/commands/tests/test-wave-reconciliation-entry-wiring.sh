#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WAVE_SCRIPT="$ROOT/ops/commands/wave.sh"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"

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

make_fake_repo() {
  local repo="$1"
  local remote="${repo}-remote.git"
  mkdir -p \
    "$repo/ops/commands" \
    "$repo/ops/lib" \
    "$repo/ops/bindings"

  cp "$WAVE_SCRIPT" "$repo/ops/commands/wave.sh"
  cp "$ROLE_CONTRACT" "$repo/ops/bindings/role.runtime.control.contract.yaml"

  cat > "$repo/ops/lib/runtime-paths.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
spine_runtime_resolve_paths() {
  local runtime_root="${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine}"
  export SPINE_REPO="${SPINE_REPO:-$PWD}"
  export SPINE_RUNTIME_ROOT="$runtime_root"
  export SPINE_STATE="${SPINE_STATE:-$runtime_root/state}"
  export SPINE_OUTBOX="${SPINE_OUTBOX:-$runtime_root/outbox}"
  export SPINE_TMP="${SPINE_TMP:-$runtime_root/tmp}"
  export SPINE_LOCKS="${SPINE_LOCKS:-$runtime_root/locks}"
  export SPINE_LOGS="${SPINE_LOGS:-$runtime_root/logs}"
  export SPINE_RECEIPTS="${SPINE_RECEIPTS:-$runtime_root/receipts}"
  export SPINE_VERIFY_ROOT="${SPINE_VERIFY_ROOT:-$runtime_root/verify}"
  export SPINE_DOMAIN_STATE="${SPINE_DOMAIN_STATE:-$runtime_root/domain-state}"
}
spine_resolve_mailroom_path() {
  local rel="${1:?mailroom path required}"
  printf '%s\n' "${SPINE_RUNTIME_ROOT:-$HOME/code/.runtime/spine}/${rel}"
}
SH

  cat > "$repo/ops/lib/git-lock.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
wave_lock_guard() { return 0; }
SH

  chmod +x \
    "$repo/ops/commands/wave.sh" \
    "$repo/ops/lib/runtime-paths.sh" \
    "$repo/ops/lib/git-lock.sh"

  git init -b main "$repo" >/dev/null
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" add .
  git -C "$repo" commit -m "fixture" >/dev/null
  git init --bare "$remote" >/dev/null
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -u origin main >/dev/null
}

echo "wave reconciliation entry wiring tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
runtime="$tmpdir/.runtime/spine"
state_root="$runtime/state"
make_fake_repo "$repo"
mkdir -p "$state_root/loop-scopes" "$runtime/waves"

scope_path="$state_root/loop-scopes/LOOP-RECON.scope.md"
printf '# loop scope\n' > "$scope_path"

execution_run_key="CAP-20260402-120000__verify.run__Rfixture01"
expected_receipt="$tmpdir/.evidence/spine/sessions/R${execution_run_key}/receipt.md"

audit_wave="WAVE-20260402-90"
mkdir -p "$runtime/waves/$audit_wave"
cat > "$runtime/waves/$audit_wave/state.json" <<EOF
{
  "wave_id": "$audit_wave",
  "status": "active",
  "created_at": "2026-04-02T12:00:00Z",
  "objective": "audit wiring fixture",
  "lifecycle_state": "implemented",
  "workspace": {
    "repo": "$repo",
    "branch": "main",
    "worktree": "$repo"
  },
  "packet": {
    "wave_id": "$audit_wave",
    "loop_id": "LOOP-RECON",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "worker",
    "next_role": "qc",
    "deadline_utc": "2026-04-03T12:00:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "lane_outcomes": []
  },
  "role_flow": {
    "current_role": "worker",
    "next_role": "qc"
  },
  "dispatches": [
    {
      "task_id": "D1",
      "lane": "execution",
      "task": "fixture execution",
      "status": "done",
      "from_role": "researcher",
      "to_role": "worker",
      "expected_output_refs": {
        "execution_plan_ref": "$scope_path",
        "acceptance_criteria_ref": "$scope_path"
      },
      "run_key": "$execution_run_key",
      "completed_at": "2026-04-02T12:01:00Z"
    }
  ],
  "watcher_checks": [],
  "preflight": {
    "domain": "dispatch-pushability",
    "started_at": "2026-04-02T12:00:01Z",
    "finished_at": "2026-04-02T12:00:01Z",
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch."
  }
}
EOF

audit_out="$(
  env HOME="$tmpdir" SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$state_root" \
    bash "$repo/ops/commands/wave.sh" dispatch "$audit_wave" --lane audit --task "fixture audit" 2>&1
)"
assert_contains "$audit_out" "Dispatched task #2 to lane 'audit':" "audit dispatch succeeds without manual refs"
python3 - <<'PY' "$runtime/waves/$audit_wave/state.json" "$expected_receipt"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
dispatch = state["dispatches"][-1]
assert dispatch["transition_gate"] == "worker_to_qc", dispatch
assert dispatch["input_refs"]["execution_plan_ref"].endswith("LOOP-RECON.scope.md"), dispatch
assert dispatch["input_refs"]["acceptance_criteria_ref"] == sys.argv[2], dispatch
assert dispatch["expected_output_refs"]["implementation_ref"].endswith("_AUDIT.md"), dispatch
assert dispatch["expected_output_refs"]["verify_ref"] == "CAP-20260402-120000__verify.run__Rfixture01", dispatch
assert dispatch["expected_output_refs"]["cleanup_ref"].endswith("_CLEANUP.md"), dispatch
PY
pass "audit dispatch auto-populates worker_to_qc refs"

control_wave="WAVE-20260402-91"
mkdir -p "$runtime/waves/$control_wave"
cat > "$runtime/waves/$control_wave/state.json" <<EOF
{
  "wave_id": "$control_wave",
  "status": "active",
  "created_at": "2026-04-02T12:05:00Z",
  "objective": "control wiring fixture",
  "lifecycle_state": "implemented",
  "workspace": {
    "repo": "$repo",
    "branch": "main",
    "worktree": "$repo"
  },
  "packet": {
    "wave_id": "$control_wave",
    "loop_id": "LOOP-RECON",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "worker",
    "next_role": "close",
    "deadline_utc": "2026-04-03T12:05:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "lane_outcomes": []
  },
  "role_flow": {
    "current_role": "worker",
    "next_role": "close"
  },
  "dispatches": [
    {
      "task_id": "D1",
      "lane": "execution",
      "task": "fixture execution",
      "status": "done",
      "from_role": "researcher",
      "to_role": "worker",
      "expected_output_refs": {
        "execution_plan_ref": "$scope_path",
        "acceptance_criteria_ref": "$scope_path"
      },
      "run_key": "$execution_run_key",
      "completed_at": "2026-04-02T12:06:00Z"
    }
  ],
  "watcher_checks": [],
  "preflight": {
    "domain": "dispatch-pushability",
    "started_at": "2026-04-02T12:05:01Z",
    "finished_at": "2026-04-02T12:05:01Z",
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch."
  }
}
EOF

control_out="$(
  env HOME="$tmpdir" SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$state_root" \
    bash "$repo/ops/commands/wave.sh" dispatch "$control_wave" --lane control --task "fixture control" 2>&1
)"
assert_contains "$control_out" "Dispatched task #2 to lane 'control':" "control dispatch succeeds without manual refs"
python3 - <<'PY' "$runtime/waves/$control_wave/state.json"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
dispatch = state["dispatches"][-1]
assert dispatch["transition_gate"] == "worker_to_close", dispatch
assert dispatch["input_refs"]["implementation_ref"].endswith("_EXECUTION.md"), dispatch
assert dispatch["input_refs"]["verify_ref"] == "CAP-20260402-120000__verify.run__Rfixture01", dispatch
assert dispatch["input_refs"]["cleanup_ref"].endswith("_CLEANUP.md"), dispatch
assert dispatch["expected_output_refs"]["closeout_ref"].endswith("_CLOSEOUT.md"), dispatch
assert dispatch["expected_output_refs"]["linkage_ref"].endswith("_LINKAGE.md"), dispatch
PY
pass "control dispatch auto-populates worker_to_close refs"

close_wave="WAVE-20260402-92"
mkdir -p "$runtime/waves/$close_wave"
cleanup_ref="$runtime/cleanup-proof.md"
printf 'cleanup proof\n' > "$cleanup_ref"
cat > "$runtime/waves/$close_wave/state.json" <<EOF
{
  "wave_id": "$close_wave",
  "status": "active",
  "created_at": "2026-04-02T12:10:00Z",
  "objective": "close state fixture",
  "lifecycle_state": "implemented",
  "workspace": {
    "repo": "$repo",
    "branch": "main",
    "worktree": "$repo"
  },
  "packet": {
    "wave_id": "$close_wave",
    "loop_id": "LOOP-RECON",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2026-04-03T12:10:00Z",
    "horizon": "now",
    "execution_readiness": "runnable",
    "claimed_paths": ["ops/commands/wave.sh"],
    "lane_outcomes": []
  },
  "role_flow": {
    "current_role": "close",
    "next_role": ""
  },
  "dispatches": [
    {
      "task_id": "D1",
      "lane": "control",
      "task": "fixture closeout handoff",
      "status": "done",
      "from_role": "worker",
      "to_role": "close",
      "expected_output_refs": {
        "verify_ref": "$execution_run_key",
        "cleanup_ref": "$cleanup_ref",
        "closeout_ref": "$runtime/closeout.md",
        "linkage_ref": "$runtime/linkage.md"
      }
    }
  ],
  "watcher_checks": [],
  "preflight": {
    "domain": "dispatch-pushability",
    "started_at": "2026-04-02T12:10:01Z",
    "finished_at": "2026-04-02T12:10:01Z",
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch."
  }
}
EOF

close_out="$(
  env HOME="$tmpdir" SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$state_root" \
    bash "$repo/ops/commands/wave.sh" close "$close_wave" --disposition deferred 2>&1
)"
assert_contains "$close_out" "Wave '$close_wave' closed." "close succeeds from implemented state when role is close"

echo "════════════════════════════════════════"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
