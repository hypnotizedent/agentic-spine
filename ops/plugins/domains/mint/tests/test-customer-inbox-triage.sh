#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$SPINE_ROOT/ops/lib/spine-paths.sh"
spine_paths_init

SCRIPT="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-triage"

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
          "id": "msg-quote",
          "conversationId": "c1",
          "receivedDateTime": "2026-03-21T10:00:00Z",
          "isRead": false,
          "subject": "Need quote for hoodies",
          "bodyPreview": "Can you price 24 hoodies?",
          "from": {"emailAddress": {"address": "jane@example.com", "name": "Jane"}}
        },
        {
          "id": "msg-spam",
          "conversationId": "c2",
          "receivedDateTime": "2026-03-21T11:00:00Z",
          "isRead": false,
          "subject": "Advisors Needed",
          "bodyPreview": "Book a call on Calendly and unsubscribe any time.",
          "from": {"emailAddress": {"address": "jackson@boardsi.com", "name": "Boardsi"}}
        }
      ]
    }
  }
}
JSON
EOF
chmod +x "$fake_ops"

json_out="$(OPS_BIN="$fake_ops" python3 "$SCRIPT" --json)"
assert_contains "$json_out" "\"capability\": \"mint.customer.inbox.triage\"" "json output includes capability id"
assert_contains "$json_out" "\"work_type\": \"quote_request\"" "quote request classified"
assert_contains "$json_out" "\"work_type\": \"promotional_or_risky\"" "promotional mail classified"
assert_contains "$json_out" "\"safe_to_open_body_links\": false" "promotional mail blocks body links"

text_out="$(OPS_BIN="$fake_ops" python3 "$SCRIPT")"
assert_contains "$text_out" "mint.customer.inbox.triage" "text output header"
assert_contains "$text_out" "lane_disposition: hide_from_primary_lane_keep_recoverable" "text output shows risky disposition"

echo "tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
