#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$SPINE_ROOT/ops/lib/spine-paths.sh"
spine_paths_init

SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-work-items"

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
          "id": "msg-reorder",
          "conversationId": "c1",
          "receivedDateTime": "2026-03-21T09:00:00Z",
          "isRead": false,
          "subject": "Need the same as last time",
          "bodyPreview": "Can we reorder the navy tees again?",
          "from": {"emailAddress": {"address": "towmaxx@example.com", "name": "TowMaxx"}}
        },
        {
          "id": "msg-revision",
          "conversationId": "c2",
          "receivedDateTime": "2026-03-21T10:00:00Z",
          "isRead": false,
          "subject": "small revision on artwork",
          "bodyPreview": "Please update the artwork proof.",
          "from": {"emailAddress": {"address": "art@example.com", "name": "Art Client"}}
        },
        {
          "id": "msg-spam",
          "conversationId": "c3",
          "receivedDateTime": "2026-03-21T11:00:00Z",
          "isRead": false,
          "subject": "Advisors Needed",
          "bodyPreview": "Calendly link enclosed. unsubscribe any time.",
          "from": {"emailAddress": {"address": "spam@example.com", "name": "SpamCo"}}
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
query="${*: -1}"
if [[ "$query" == "towmaxx@example.com" ]]; then
  cat <<'JSON'
{"query":"towmaxx@example.com","state":"exact_match","reason":"exact_email","confidence":"high","resolved_customer":{"id":"cust-1","name":"TowMaxx","email":"towmaxx@example.com","match_reason":"exact_email","confidence":"high"},"candidates":[]}
JSON
else
  cat <<'JSON'
{"query":"other","state":"new_customer","reason":"no_match","confidence":"none","candidates":[]}
JSON
fi
exit 0
EOF
chmod +x "$fake_customer"

fake_trace="$tmpdir/contact-trace"
cat >"$fake_trace" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
email=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) email="${2:-}"; shift 2 ;;
    --json) shift ;;
    *) shift ;;
  esac
done
if [[ "$email" == "towmaxx@example.com" ]]; then
  cat <<'JSON'
{
  "mailbox": {"status":"done","hit_count":2,"hits":[]},
  "archive_lane": {"status":"healthy","seed_query_status":"done","seed_count":1,"linked_job_count":1,"seed_ids":["seed-1"],"seeds":[]},
  "quote_packet_runtime": {"status":"ok","packet_count":1,"packets":[{"quote_packet_id":"qp-1","state":"priced","blocking_gap_count":0}]},
  "next_operator_step":"Continue on quote_packet qp-1 in state priced."
}
JSON
elif [[ "$email" == "art@example.com" ]]; then
  cat <<'JSON'
{
  "mailbox": {"status":"done","hit_count":1,"hits":[]},
  "archive_lane": {"status":"healthy","seed_query_status":"done","seed_count":1,"linked_job_count":0,"seed_ids":["seed-r"],"seeds":[]},
  "quote_packet_runtime": {"status":"ok","packet_count":0,"packets":[]},
  "next_operator_step":"Seed exists, but no local quote_packet references it yet."
}
JSON
else
  cat <<'JSON'
{
  "mailbox": {"status":"skipped","hit_count":0,"hits":[]},
  "archive_lane": {"status":"skipped","seed_query_status":"skipped","seed_count":0,"linked_job_count":0,"seed_ids":[],"seeds":[]},
  "quote_packet_runtime": {"status":"skipped","packet_count":0,"packets":[]},
  "next_operator_step":"keep_recoverable_and_do_not_open_body_links"
}
JSON
fi
EOF
chmod +x "$fake_trace"

json_out="$(
  OPS_BIN="$fake_ops" \
  MINT_CUSTOMER_RESOLVE_EXEC="$fake_customer" \
  MINT_CONTACT_TRACE_EXEC="$fake_trace" \
  python3 "$SCRIPT" --json
)"
assert_contains "$json_out" "\"capability\": \"mint.customer.inbox.work_items\"" "json output includes capability id"
assert_contains "$json_out" "\"work_type\": \"reorder_candidate\"" "reorder work item classified"
assert_contains "$json_out" "\"next_business_step\": \"mintctl morpheus inbox reorder --message-id msg-reorder\"" "reorder next step derived"
assert_contains "$json_out" "\"quote_ready\": true" "quote readiness surfaces from trace"
assert_contains "$json_out" "\"next_business_step\": \"prepare_artwork_revision_handoff\"" "revision work item routes to artwork prep"
assert_contains "$json_out" "\"state\": \"skipped_promotional\"" "promotional mail skips heavy lookups"

text_out="$(
  OPS_BIN="$fake_ops" \
  MINT_CUSTOMER_RESOLVE_EXEC="$fake_customer" \
  MINT_CONTACT_TRACE_EXEC="$fake_trace" \
  python3 "$SCRIPT"
)"
assert_contains "$text_out" "mint.customer.inbox.work_items" "text output header"
assert_contains "$text_out" "work_type: reorder_candidate" "text output shows reorder classification"

home_tmp="$tmpdir/home"
mkdir -p "$home_tmp/.wt/agentic-spine/lane" "$home_tmp/code/agentic-spine" "$home_tmp/code/mint-modules"
resolved_root="$(
  HOME="$home_tmp" \
  SPINE_ROOT="$home_tmp/.wt/agentic-spine/lane" \
  python3 - <<'PY'
from ops.plugins.domains.mint.lib.customer_inbox_common import mint_modules_root
print(mint_modules_root())
PY
)"
assert_contains "$resolved_root" "$home_tmp/code/mint-modules" "stable worktree root resolves mint-modules from ~/code"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
