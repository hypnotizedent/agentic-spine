#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$SPINE_ROOT/ops/lib/spine-paths.sh"
spine_paths_init

SCRIPT="$ROOT/ops/plugins/domains/mint/bin/mint-morpheus-launch"

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
cat <<'JSON'
{
  "data": {
    "microsoft": {
      "value": [
        {
          "id": "msg-late",
          "conversationId": "c2",
          "receivedDateTime": "2026-03-21T19:00:00Z",
          "isRead": false,
          "subject": "Need quote",
          "bodyPreview": "Need pricing for 24 tees",
          "from": {"emailAddress": {"address": "new@example.com", "name": "New Customer"}}
        },
        {
          "id": "msg-early",
          "conversationId": "c1",
          "receivedDateTime": "2026-03-21T09:00:00Z",
          "isRead": false,
          "subject": "same as last time",
          "bodyPreview": "Need the same as last time for 24 navy tees",
          "from": {"emailAddress": {"address": "towmaxx@example.com", "name": "TowMaxx"}}
        }
      ]
    }
  }
}
JSON
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
    "seed_count": 1,
    "linked_job_count": 1,
    "seed_ids": ["seed-1"],
    "seeds": []
  },
  "quote_packet_runtime": {"status":"ok","packet_count":0,"packets":[]},
  "mailbox": {"status":"done","hit_count":2,"hits":[]},
  "next_operator_step":"review anchor job"
}
JSON
EOF
chmod +x "$fake_trace"

json_out="$(OPS_BIN="$fake_ops" MINT_CUSTOMER_RESOLVE_EXEC="$fake_customer" MINT_CONTACT_TRACE_EXEC="$fake_trace" python3 "$SCRIPT" --json)"
assert_contains "$json_out" "\"launch_mode\": \"customer_inbox_queue\"" "launch reports queue mode"
assert_contains "$json_out" "\"queue_order\": \"oldest_first\"" "launch advertises oldest-first queue"
assert_contains "$json_out" "\"message_id\": \"msg-early\"" "launch selects oldest actionable item"
assert_contains "$json_out" "\"recommended_command\": \"mintctl morpheus inbox reorder --message-id msg-early\"" "launch recommends reorder resolver"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
