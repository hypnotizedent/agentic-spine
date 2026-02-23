#!/usr/bin/env bash
# TRIAGE: Rebuild receipt index with receipts.index.build, then validate domain metadata contract and read-surface filters.
# D161: Receipt memory domain+time lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INDEX_FILE="$ROOT/ops/plugins/evidence/state/receipt-index.yaml"

fail() {
  echo "D161 FAIL: $*" >&2
  exit 1
}

[[ -f "$INDEX_FILE" ]] || fail "missing receipt index: $INDEX_FILE"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

index_contract_json=""
if ! index_contract_json="$(python3 - "$INDEX_FILE" 2>&1 <<'PY'
import json
import sys
from pathlib import Path

import yaml

index_path = Path(sys.argv[1])
with index_path.open("r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

entries = data.get("entries")
if not isinstance(entries, list):
    raise SystemExit("entries is missing or not a list")

if not entries:
    raise SystemExit("entries list is empty")

missing_domain = 0
missing_plane = 0
for row in entries:
    if not isinstance(row, dict):
        missing_domain += 1
        missing_plane += 1
        continue
    domain = str(row.get("domain") or "").strip()
    plane = str(row.get("plane") or "").strip()
    if not domain:
        missing_domain += 1
    if not plane:
        missing_plane += 1

if missing_domain or missing_plane:
    raise SystemExit(
        f"index entry contract violation (missing_domain={missing_domain} missing_plane={missing_plane})"
    )

print(json.dumps({"entries": len(entries), "missing_domain": missing_domain, "missing_plane": missing_plane}))
PY
)"; then
  fail "receipt index contract invalid: ${index_contract_json:-unknown parser error}"
fi

search_output=""
if ! search_output="$(cd "$ROOT" && ./bin/ops cap run receipts.search -- --domain none --days 7 --limit 1 2>&1)"; then
  fail "smoke-check failed: receipts.search --domain none --days 7 --limit 1"
fi

summary_output=""
if ! summary_output="$(cd "$ROOT" && ./bin/ops cap run receipts.summary -- --domain none --days 7 2>&1)"; then
  fail "smoke-check failed: receipts.summary --domain none --days 7"
fi

trends_output=""
if ! trends_output="$(cd "$ROOT" && ./bin/ops cap run receipts.trends -- --domain none --days 7 2>&1)"; then
  fail "smoke-check failed: receipts.trends --domain none --days 7"
fi

session_fast_output=""
if ! session_fast_output="$("$ROOT/ops/plugins/session/bin/session-start" --mode fast 2>&1)"; then
  fail "session-start fast check failed"
fi

if ! grep -Eq '^receipt_memory_hint: \./bin/ops cap run receipts\.summary -- --domain [^ ]+ --days 7$' <<< "$session_fast_output"; then
  fail "session.start fast output missing receipt_memory_hint command"
fi

search_count="$(grep -E '^count:' <<< "$search_output" | tail -n1 | awk '{print $2}' || true)"
summary_total="$(grep -E '^total:' <<< "$summary_output" | tail -n1 | awk '{print $2}' || true)"
trends_rows="$(grep -Ec '^  - [0-9]{4}-[0-9]{2}-[0-9]{2}:' <<< "$trends_output" || true)"

[[ -n "$search_count" ]] || search_count="unknown"
[[ -n "$summary_total" ]] || summary_total="unknown"
[[ -n "$trends_rows" ]] || trends_rows="unknown"

entries_total="$(python3 - "$index_contract_json" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
print(payload.get("entries", "unknown"))
PY
)"

echo "D161 PASS: receipt memory domain+time lock valid (entries=$entries_total search_count=$search_count summary_total=$summary_total trends_days=$trends_rows)"
