#!/usr/bin/env bash
# TRIAGE: replay plans SQLite authority migration/reconcile fix twice and enforce stable end-state.
# D346: migration-idempotency-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RECONCILE_BIN="$ROOT/ops/plugins/lifecycle/bin/planning-plans-reconcile"

fail() {
  echo "D346 FAIL: $*" >&2
  exit 1
}

[[ -x "$RECONCILE_BIN" ]] || fail "missing reconcile runner: $RECONCILE_BIN"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

run_reconcile() {
  local mode="$1"
  set +e
  local payload
  payload="$($RECONCILE_BIN --"$mode" --json 2>/dev/null)"
  local rc=$?
  set -e
  printf '%s\n%s' "$rc" "$payload"
}

first_result="$(run_reconcile fix)"
first_rc="$(head -n 1 <<<"$first_result")"
first_payload="$(tail -n +2 <<<"$first_result")"
[[ -n "$first_payload" ]] || fail "first reconcile payload is empty"

second_result="$(run_reconcile fix)"
second_rc="$(head -n 1 <<<"$second_result")"
second_payload="$(tail -n +2 <<<"$second_result")"
[[ -n "$second_payload" ]] || fail "second reconcile payload is empty"

check_result="$(run_reconcile check)"
check_rc="$(head -n 1 <<<"$check_result")"
check_payload="$(tail -n +2 <<<"$check_result")"
[[ -n "$check_payload" ]] || fail "final check payload is empty"

(( first_rc == 0 )) || fail "first reconcile --fix returned rc=$first_rc"
(( second_rc == 0 )) || fail "second reconcile --fix returned rc=$second_rc"
(( check_rc == 0 )) || fail "final reconcile --check returned rc=$check_rc"

second_updated="$(jq -r '.summary.updated_rows // -1' <<<"$second_payload")"
second_actions="$(jq -r '.summary.actions_applied // -1' <<<"$second_payload")"
second_created="$(jq -r '.summary.created_docs // -1' <<<"$second_payload")"
second_archived="$(jq -r '.summary.archived_docs // -1' <<<"$second_payload")"

if [[ "$second_updated" != "0" || "$second_actions" != "0" || "$second_created" != "0" || "$second_archived" != "0" ]]; then
  fail "second reconcile is not idempotent updated_rows=$second_updated actions_applied=$second_actions created_docs=$second_created archived_docs=$second_archived"
fi

first_hash="$(jq -r '.summary.expected_plans_hash // ""' <<<"$first_payload")"
second_hash="$(jq -r '.summary.expected_plans_hash // ""' <<<"$second_payload")"
check_hash="$(jq -r '.summary.expected_plans_hash // ""' <<<"$check_payload")"
check_actual_hash="$(jq -r '.summary.actual_plans_hash // ""' <<<"$check_payload")"
check_parity="$(jq -r '.summary.projection_parity_mismatch // 1' <<<"$check_payload")"
check_watermark="$(jq -r '.summary.watermark_mismatch // 1' <<<"$check_payload")"
check_sqlite_ok="$(jq -r '.summary.sqlite_integrity_ok // 0' <<<"$check_payload")"

[[ -n "$first_hash" && -n "$second_hash" && -n "$check_hash" ]] || fail "missing expected_plans_hash in reconcile payloads"
[[ "$first_hash" == "$second_hash" ]] || fail "hash drift between first/second fix runs"
[[ "$second_hash" == "$check_hash" ]] || fail "hash drift between second fix and check runs"
[[ "$check_hash" == "$check_actual_hash" ]] || fail "expected/actual projection hash mismatch after replay"
[[ "$check_parity" == "0" ]] || fail "projection parity mismatch after replay"
[[ "$check_watermark" == "0" ]] || fail "watermark mismatch after replay"
[[ "$check_sqlite_ok" == "1" ]] || fail "sqlite integrity check failed after replay"

echo "D346 PASS: plans migration/reconcile replay is idempotent (hash=$check_hash)"
