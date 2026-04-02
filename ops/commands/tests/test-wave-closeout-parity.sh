#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WAVE_SCRIPT="$ROOT/ops/commands/wave.sh"
RECEIPT_EMIT="$ROOT/ops/plugins/core/evidence/bin/receipts-exec-emit"
SCHEMA_PATH="$ROOT/ops/bindings/orchestration.exec_receipt.schema.json"
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
  mkdir -p \
    "$repo/ops/commands" \
    "$repo/ops/lib" \
    "$repo/ops/bindings" \
    "$repo/ops/plugins/core/evidence/bin"

  cp "$WAVE_SCRIPT" "$repo/ops/commands/wave.sh"
  cp "$RECEIPT_EMIT" "$repo/ops/plugins/core/evidence/bin/receipts-exec-emit"
  cp "$SCHEMA_PATH" "$repo/ops/bindings/orchestration.exec_receipt.schema.json"
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
    "$repo/ops/plugins/core/evidence/bin/receipts-exec-emit" \
    "$repo/ops/lib/runtime-paths.sh" \
    "$repo/ops/lib/git-lock.sh"
}

echo "wave closeout parity tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/repo"
runtime="$tmpdir/runtime"
wave_id="WAVE-20260329-99"
loop_id="LOOP-CLOSEOUT-PARITY-TEST"
receipt_path="$runtime/waves/$wave_id/evidence/EXEC_RECEIPT_D1.json"
cleanup_ref="$runtime/cleanup-proof.md"
close_wave_id="WAVE-20260329-98"
close_loop_id="LOOP-CLOSEOUT-PARITY-CLOSE"
close_receipt_path="$runtime/waves/$close_wave_id/evidence/EXEC_RECEIPT_D9.json"

make_fake_repo "$repo"
mkdir -p "$runtime/waves/$wave_id/evidence" "$runtime/waves/$close_wave_id/evidence" "$runtime/state"
printf 'cleanup proof\n' > "$cleanup_ref"

cat > "$runtime/waves/$wave_id/state.json" <<EOF
{
  "wave_id": "$wave_id",
  "status": "active",
  "created_at": "2026-03-29T22:00:00Z",
  "objective": "fixture closeout parity",
  "lifecycle_state": "validated",
  "packet": {
    "wave_id": "$wave_id",
    "loop_id": "$loop_id",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2026-03-30T22:00:00Z",
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
      "lane": "execution",
      "task": "fixture mutate",
      "status": "done",
      "from_role": "researcher",
      "to_role": "worker",
      "expected_output_refs": {
        "cleanup_ref": "$cleanup_ref"
      }
    }
  ],
  "watcher_checks": [],
  "preflight": {
    "domain": "dispatch-pushability",
    "started_at": "2026-03-29T22:00:01Z",
    "finished_at": "2026-03-29T22:00:01Z",
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch."
  }
}
EOF

env SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$runtime/state" \
  bash "$repo/ops/plugins/core/evidence/bin/receipts-exec-emit" \
    --task-id D1 \
    --terminal-id SPINE-CONTROL-01 \
    --lane execution \
    --status done \
    --files-changed "ops/commands/wave.sh" \
    --run-keys "S20260329-220000__engine.closeout__Rfixture01" \
    --ready-for-verify true \
    --timestamp-utc "2026-03-29T22:00:02Z" \
    --wave-id "$wave_id" \
    --loop-id "$loop_id" \
    --commit-hashes "abcdef1" \
    --prompt-set-id spine-controller-context \
    --prompt-version "2026-03-24.1" \
    --prompt-source-refs "ops/bindings/controller.boundary.contract.yaml,ops/plugins/core/session/templates/execution.context.yaml" \
    --prompt-source-hash none \
    --prompt-source-hashes "ops/bindings/controller.boundary.contract.yaml=missing,ops/plugins/core/session/templates/execution.context.yaml=missing" \
    --prompt-registry-path ops/bindings/prompt.registry.yaml \
    --prompt-resolution defaults \
    --json-out "$receipt_path" >/dev/null

receipt_out="$(
  env SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$runtime/state" \
    bash "$repo/ops/commands/wave.sh" receipt-validate "$receipt_path" 2>&1
)"
assert_contains "$receipt_out" "OK: EXEC_RECEIPT_D1.json is a valid EXEC_RECEIPT" "receipt-validate accepts prompt_lineage receipts"

collect_out="$(
  env SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$runtime/state" \
    bash "$repo/ops/commands/wave.sh" collect "$wave_id" 2>&1
)"
assert_contains "$collect_out" "1 valid, 0 invalid" "collect accepts prompt_lineage receipt artifacts"
python3 - <<'PY' "$runtime/waves/$wave_id/state.json"
import json, sys
state = json.load(open(sys.argv[1], "r", encoding="utf-8"))
dispatch = state["dispatches"][0]
assert dispatch["receipt_validated"] is True, dispatch
PY
pass "collect marks dispatch receipt as validated"

cat > "$runtime/waves/$close_wave_id/state.json" <<EOF
{
  "wave_id": "$close_wave_id",
  "status": "active",
  "created_at": "2026-03-29T22:10:00Z",
  "objective": "fixture close parity",
  "lifecycle_state": "validated",
  "packet": {
    "wave_id": "$close_wave_id",
    "loop_id": "$close_loop_id",
    "owner_terminal": "SPINE-CONTROL-01",
    "current_role": "researcher",
    "next_role": "worker",
    "deadline_utc": "2026-03-30T22:10:00Z",
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
      "task_id": "D9",
      "lane": "control",
      "task": "fixture closeout handoff",
      "status": "done",
      "from_role": "qc",
      "to_role": "close",
      "expected_output_refs": {
        "cleanup_ref": "$cleanup_ref"
      }
    }
  ],
  "watcher_checks": [],
  "preflight": {
    "domain": "dispatch-pushability",
    "started_at": "2026-03-29T22:10:01Z",
    "finished_at": "2026-03-29T22:10:01Z",
    "duration_s": 0,
    "verdict": "go",
    "blockers": [],
    "next_action": "Proceed with dispatch."
  }
}
EOF

env SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$runtime/state" \
  bash "$repo/ops/plugins/core/evidence/bin/receipts-exec-emit" \
    --task-id D9 \
    --terminal-id SPINE-CONTROL-01 \
    --lane control \
    --status done \
    --files-changed "ops/commands/wave.sh" \
    --run-keys "S20260329-221000__engine.closeout.close__Rfixture01" \
    --ready-for-verify true \
    --timestamp-utc "2026-03-29T22:10:02Z" \
    --wave-id "$close_wave_id" \
    --loop-id "$close_loop_id" \
    --commit-hashes "abcdef1" \
    --prompt-set-id spine-controller-context \
    --prompt-version "2026-03-24.1" \
    --prompt-source-refs "ops/bindings/controller.boundary.contract.yaml,ops/plugins/core/session/templates/verification.context.yaml" \
    --prompt-source-hash none \
    --prompt-source-hashes "ops/bindings/controller.boundary.contract.yaml=missing,ops/plugins/core/session/templates/verification.context.yaml=missing" \
    --prompt-registry-path ops/bindings/prompt.registry.yaml \
    --prompt-resolution defaults \
    --json-out "$close_receipt_path" >/dev/null

close_out="$(
  env SPINE_REPO="$repo" SPINE_RUNTIME_ROOT="$runtime" SPINE_STATE="$runtime/state" \
    bash "$repo/ops/commands/wave.sh" close "$close_wave_id" --disposition deferred 2>&1
)"
assert_contains "$close_out" "Wave '$close_wave_id' closed." "close succeeds with evidence directory receipts"
python3 - <<'PY' "$runtime/waves/$close_wave_id/close-receipt.json"
import json, sys
receipt = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert receipt["valid_receipts"] == 1, receipt
assert receipt["invalid_receipts"] == 0, receipt
dod = receipt["dod"]
assert "S20260329-221000__engine.closeout.close__Rfixture01" in dod["verify_results"], dod
assert len(dod["cleanup_proof"]) == 1, dod
PY
pass "close receipt records verify and cleanup evidence from evidence dir"

echo "════════════════════════════════════════"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
