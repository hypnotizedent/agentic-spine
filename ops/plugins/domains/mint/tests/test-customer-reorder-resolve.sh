#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$SPINE_ROOT/ops/lib/spine-paths.sh"
spine_paths_init

SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-reorder-resolve"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_ops="$tmpdir/ops"
cat >"$fake_ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"microsoft.mail.get"* ]]; then
  cat <<'JSON'
{
  "id": "msg-reorder",
  "conversationId": "c1",
  "receivedDateTime": "2026-03-21T09:00:00Z",
  "isRead": false,
  "subject": "Need the same as last time",
  "bodyPreview": "Can we reorder 24 navy tees again?",
  "from": {"emailAddress": {"address": "towmaxx@example.com", "name": "TowMaxx"}}
}
JSON
else
  echo "unexpected ops call: $*" >&2
  exit 1
fi
EOF
chmod +x "$fake_ops"

fake_customer="$tmpdir/customer-resolve"
cat >"$fake_customer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{"state":"exact_match","reason":"exact_email","confidence":"high","resolved_customer":{"id":"cust-1","name":"TowMaxx","email":"towmaxx@example.com"},"candidates":[]}
JSON
EOF
chmod +x "$fake_customer"

fake_trace="$tmpdir/contact-trace"
cat >"$fake_trace" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat <<'JSON'
{
  "archive_lane": {
    "status": "healthy",
    "seed_query_status": "done",
    "seed_count": 2,
    "linked_job_count": 1,
    "seed_ids": ["seed-1","seed-2"],
    "seeds": [
      {"seed_id":"seed-1","job_number":"13825","source":"email","status":"attached","created_at":"2026-03-20T10:00:00Z"},
      {"seed_id":"seed-2","job_number":"-","source":"email","status":"new","created_at":"2026-03-21T10:00:00Z"}
    ]
  }
}
JSON
EOF
chmod +x "$fake_trace"

json_out="$(
  SPINE_STATE="$tmpdir/state" \
  OPS_BIN="$fake_ops" \
  MINT_CUSTOMER_RESOLVE_EXEC="$fake_customer" \
  MINT_CONTACT_TRACE_EXEC="$fake_trace" \
  python3 "$SCRIPT" --message-id msg-reorder --json
)"
assert_contains "$json_out" "\"status\": \"ok\"" "resolver returns ok"
assert_contains "$json_out" "\"anchor_job_number\": \"13825\"" "resolver selects anchor job"
assert_contains "$json_out" "\"next_business_step\": \"review_anchor_job 13825 and confirm quantity_or_changes\"" "resolver derives concrete next step"
assert_contains "$json_out" "\"reused_fields\"" "resolver includes reordered field summary"
record_path="$(printf '%s' "$json_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["record_path"])')"
[[ -f "$record_path" ]] && pass "resolver writes runtime record" || fail "resolver writes runtime record"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
