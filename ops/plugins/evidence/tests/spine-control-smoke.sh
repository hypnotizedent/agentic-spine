#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
BIN="$ROOT/ops/plugins/evidence/bin/spine-control"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BIN" ]] || fail "spine-control script missing or not executable"

tick_json="$("$BIN" tick --json)"
jq -e '.capability=="spine.control.tick"' <<<"$tick_json" >/dev/null || fail "tick capability envelope"
jq -e '.data.summary.graph_nodes >= 0 and .data.summary.graph_edges >= 0' <<<"$tick_json" >/dev/null || fail "tick graph summary"
pass "tick emits graph-aware summary envelope"

plan_json="$("$BIN" plan --json)"
jq -e '.capability=="spine.control.plan"' <<<"$plan_json" >/dev/null || fail "plan capability envelope"
jq -e '(.data.actions | type)=="array"' <<<"$plan_json" >/dev/null || fail "plan actions array"
pass "plan emits actions array"

set +e
exec_json="$("$BIN" execute --action-id DOES-NOT-EXIST --json 2>/dev/null)"
exec_rc=$?
set -e
[[ "$exec_rc" -ne 0 ]] || fail "execute unknown action should fail"
jq -e '.data.results[0].error_code=="action_not_found"' <<<"$exec_json" >/dev/null || fail "execute action_not_found error code"
pass "execute handles unknown action deterministically"

cycle_json="$("$BIN" cycle --dry-run --max-actions 1 --max-priority P1 --no-agent-tools --json)"
jq -e '.capability=="spine.control.cycle"' <<<"$cycle_json" >/dev/null || fail "cycle capability envelope"
jq -e '(.data.selected_action_ids | type)=="array"' <<<"$cycle_json" >/dev/null || fail "cycle selected actions array"
pass "cycle dry-run envelope is valid"

echo "spine-control smoke tests"
