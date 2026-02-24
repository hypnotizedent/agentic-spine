#!/usr/bin/env bash
# TRIAGE: Validate receipt index contract and direct read-surface domain/time filters.
# D161: Receipt memory domain+time lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INDEX_FILE="$ROOT/ops/plugins/evidence/state/receipt-index.yaml"
SESSION_START_SCRIPT="$ROOT/ops/plugins/session/bin/session-start"
RECEIPTS_SEARCH_BIN="$ROOT/ops/plugins/evidence/bin/receipts-search"
RECEIPTS_SUMMARY_BIN="$ROOT/ops/plugins/evidence/bin/receipts-summary"
RECEIPTS_TRENDS_BIN="$ROOT/ops/plugins/evidence/bin/receipts-trends"

fail() {
  echo "D161 FAIL: $*" >&2
  exit 1
}

[[ -f "$INDEX_FILE" ]] || fail "missing receipt index: $INDEX_FILE"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"
[[ -x "$SESSION_START_SCRIPT" ]] || fail "missing session-start script: $SESSION_START_SCRIPT"
[[ -x "$RECEIPTS_SEARCH_BIN" ]] || fail "missing receipts-search binary: $RECEIPTS_SEARCH_BIN"
[[ -x "$RECEIPTS_SUMMARY_BIN" ]] || fail "missing receipts-summary binary: $RECEIPTS_SUMMARY_BIN"
[[ -x "$RECEIPTS_TRENDS_BIN" ]] || fail "missing receipts-trends binary: $RECEIPTS_TRENDS_BIN"

index_contract_tsv="$(yq e -r '[.entries | length, ([.entries[] | select((.domain // "") == "")] | length), ([.entries[] | select((.plane // "") == "")] | length)] | @tsv' "$INDEX_FILE" 2>/dev/null || true)"
IFS=$'\t' read -r entries_total missing_domain missing_plane <<< "$index_contract_tsv"

[[ "$entries_total" =~ ^[0-9]+$ ]] || fail "receipt index contract invalid: entries is missing or non-numeric"
[[ "$missing_domain" =~ ^[0-9]+$ ]] || fail "receipt index contract invalid: missing_domain is non-numeric"
[[ "$missing_plane" =~ ^[0-9]+$ ]] || fail "receipt index contract invalid: missing_plane is non-numeric"
(( entries_total > 0 )) || fail "receipt index contract invalid: entries list is empty"
if (( missing_domain > 0 || missing_plane > 0 )); then
  fail "receipt index contract invalid: index entry contract violation (missing_domain=$missing_domain missing_plane=$missing_plane)"
fi

search_tmp="$(mktemp)"
summary_tmp="$(mktemp)"
trends_tmp="$(mktemp)"
trap 'rm -f "$search_tmp" "$summary_tmp" "$trends_tmp"' EXIT

"$RECEIPTS_SEARCH_BIN" --domain none --days 7 --limit 1 >"$search_tmp" 2>&1 &
search_pid=$!
"$RECEIPTS_SUMMARY_BIN" --domain none --days 7 >"$summary_tmp" 2>&1 &
summary_pid=$!
"$RECEIPTS_TRENDS_BIN" --domain none --days 7 >"$trends_tmp" 2>&1 &
trends_pid=$!

wait "$search_pid" || fail "smoke-check failed: receipts-search --domain none --days 7 --limit 1"
wait "$summary_pid" || fail "smoke-check failed: receipts-summary --domain none --days 7"
wait "$trends_pid" || fail "smoke-check failed: receipts-trends --domain none --days 7"

search_output="$(cat "$search_tmp")"
summary_output="$(cat "$summary_tmp")"
trends_output="$(cat "$trends_tmp")"

# Avoid running full session.start inside D161; verify the default hint contract statically.
if ! grep -Eq 'local receipt_memory_hint="\./bin/ops cap run receipts\.summary -- --domain none --days 7"' "$SESSION_START_SCRIPT"; then
  fail "session-start missing default receipt_memory_hint contract (--domain none --days 7)"
fi

search_count="$(grep -E '^count:' <<< "$search_output" | tail -n1 | awk '{print $2}' || true)"
summary_total="$(grep -E '^total:' <<< "$summary_output" | tail -n1 | awk '{print $2}' || true)"
trends_rows="$(grep -Ec '^  - [0-9]{4}-[0-9]{2}-[0-9]{2}:' <<< "$trends_output" || true)"

[[ -n "$search_count" ]] || search_count="unknown"
[[ -n "$summary_total" ]] || summary_total="unknown"
[[ -n "$trends_rows" ]] || trends_rows="unknown"

echo "D161 PASS: receipt memory domain+time lock valid (entries=$entries_total search_count=$search_count summary_total=$summary_total trends_days=$trends_rows)"
