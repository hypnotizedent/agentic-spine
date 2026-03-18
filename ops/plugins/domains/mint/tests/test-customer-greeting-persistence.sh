#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
CONTEXT_SET="$ROOT/ops/plugins/domains/mint/bin/customer-quote-context-set"
SNAPSHOT="$ROOT/ops/plugins/domains/mint/bin/customer-record-snapshot"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
REPLY_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"
CONTEXT_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.context.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$CONTEXT_SET" ]] || fail "missing customer-quote-context-set executable"
[[ -x "$SNAPSHOT" ]] || fail "missing customer-record-snapshot executable"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fixture="$tmp/customers.json"
printf '[]\n' >"$fixture"

export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_RECORD_FIXTURE_FILE="$fixture"
export MINT_CUSTOMER_QUOTE_CONTEXT_CONTRACT="$CONTEXT_CONTRACT"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"

json_context="$("$CONTEXT_SET" \
  --email emilioacolon18@gmail.com \
  --customer-name Emilio \
  --company "EC" \
  --relationship-note "Use Emilio in customer-facing greetings." \
  --source operator_confirmed \
  --set-by ronny \
  --confidence high \
  --json)"
context_record="$(echo "$json_context" | jq -r '.data.record_file')"

[[ -f "$context_record" ]] || fail "quote context record should exist"
[[ "$(echo "$json_context" | jq -r '.data.selector.customer_name')" == "Emilio" ]] || fail "context selector should persist guided customer name"

json_snapshot="$("$SNAPSHOT" --name 'Emilio' --json)"

[[ "$(echo "$json_snapshot" | jq -r '.quote_intelligence.customer_context_match.match_mode')" == "name_exact" ]] || fail "snapshot should resolve governed quote context by guided customer name"
[[ "$(echo "$json_snapshot" | jq -r '.fresh_slate.identity.greeting_name')" == "Emilio" ]] || fail "snapshot should surface the governed customer-facing greeting"
[[ "$(echo "$json_snapshot" | jq -r '.fresh_slate.identity.display_name')" == "Emilio" ]] || fail "snapshot should surface the governed customer-facing display name"

stub_root="$tmp/spine"
mkdir -p "$stub_root/bin"
export EMILIO_CONTEXT_RECORD="$context_record"
export STUB_STATE_ROOT="$SPINE_STATE"

cat >"$stub_root/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  microsoft.mail.get)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    case "$message_id" in
      MSG-EC)
        cat <<'JSON'
{"id":"MSG-EC","subject":"Re: 13839 Respect march","conversationId":"CONV-EC","internetMessageId":"<ec@example.com>","from":{"emailAddress":{"address":"emilioacolon18@gmail.com","name":"Emilio Colon"}},"body":{"contentType":"Text","content":"Payment sent. Text me when they are ready."},"bodyPreview":"Payment sent. Text me when they are ready."}
JSON
        ;;
      DRAFT-1)
        draft_subject="$(cat "${STUB_STATE_ROOT}/last-draft-subject.txt" 2>/dev/null || printf '13839 Respect march')"
        draft_content_type="$(cat "${STUB_STATE_ROOT}/last-draft-content-type.txt" 2>/dev/null || printf 'HTML')"
        draft_body="$(cat "${STUB_STATE_ROOT}/last-draft-body.txt" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "${STUB_STATE_ROOT}/mail-get-draft.json" "$draft_subject" "$draft_content_type" "$draft_body"
from pathlib import Path
import json
import sys

payload = {
    "id": "DRAFT-1",
    "subject": sys.argv[2],
    "conversationId": "CONV-EC",
    "toRecipients": [{"emailAddress": {"address": "emilioacolon18@gmail.com"}}],
    "body": {
        "contentType": sys.argv[3],
        "content": sys.argv[4],
    },
}
Path(sys.argv[1]).write_text(json.dumps(payload), encoding="utf-8")
PY
        cat "${STUB_STATE_ROOT}/mail-get-draft.json"
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.reply.draft)
    cat <<'JSON'
{"id":"DRAFT-1","subject":"Re: 13839 Respect march","conversationId":"CONV-EC","toRecipients":[{"emailAddress":{"address":"emilioacolon18@gmail.com"}}],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}}
JSON
    ;;
  microsoft.mail.draft.update)
    body=""
    subject=""
    mailbox=""
    content_type=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) shift 2 ;;
        --to) shift 2 ;;
        --cc) shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --content-type) content_type="$2"; shift 2 ;;
        --mailbox) mailbox="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$body" >"${STUB_STATE_ROOT}/last-draft-body.txt"
    printf '%s' "$mailbox" >"${STUB_STATE_ROOT}/last-draft-mailbox.txt"
    printf '%s' "$subject" >"${STUB_STATE_ROOT}/last-draft-subject.txt"
    printf '%s' "$content_type" >"${STUB_STATE_ROOT}/last-draft-content-type.txt"
    printf '{"id":"DRAFT-1","subject":"%s","toRecipients":[{"emailAddress":{"address":"emilioacolon18@gmail.com"}}]}\n' "$subject"
    ;;
  mint.customer.record.snapshot)
    email=""
    name=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --email) email="$2"; shift 2 ;;
        --name) name="$2"; shift 2 ;;
        --record-id) shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    if [[ "$email" != "emilioacolon18@gmail.com" && "$name" != "Emilio" ]]; then
      echo "unexpected snapshot lookup: email=$email name=$name" >&2
      exit 1
    fi
    python3 - <<'PY' "$EMILIO_CONTEXT_RECORD" "$email" "$name"
from pathlib import Path
import json
import sys

record = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
selector = dict(record.get("selector") or {})
context = dict(record.get("quote_context") or {})
match_mode = "email_exact" if sys.argv[2] else "name_exact"
payload = {
    "data": {
        "query_mode": "email" if sys.argv[2] else "name",
        "fresh_slate": {
            "customer": None,
            "customers": [],
            "identity": None,
            "customer_match_count": 0,
            "seed_count": 0,
            "latest_seed": None,
            "fresh_order_count": 0,
            "fresh_orders": [],
        },
        "legacy_hold": {
            "orders": [],
        },
        "quote_intelligence": {
            "house_policy": {
                "minimum_pieces": 0,
                "preferred_order_floor_usd": 0,
            },
            "terminology": {},
            "customer_context_match": {
                "matched": True,
                "match_mode": match_mode,
                "record_file": sys.argv[1],
                "selector": selector,
                "context": context,
                "summary": {
                    "segments": [],
                    "exception": None,
                },
            },
            "customer_context": context,
        },
    }
}
print(json.dumps(payload))
PY
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$stub_root/bin/ops"

export SPINE_ROOT="$stub_root"
json_reply="$("$REPLY" MSG-EC --body "Payment received, we are on it." --mailbox team@mintprints.com --job-number 13839 --job-nickname "Respect march" --json)"
reply_record="$(echo "$json_reply" | jq -r '.data.record_file')"
reply_body="$SPINE_STATE/last-draft-body.txt"

[[ -f "$reply_record" ]] || fail "reply draft record should exist"
grep -F 'Greetings Emilio,' "$reply_body" >/dev/null || fail "reply draft should reuse the governed Emilio greeting"
grep -F 'Emilio Colon' "$reply_body" >/dev/null && fail "reply draft should not fall back to the raw display name when governed greeting truth exists"
[[ "$(jq -r '.customer_identity_lookup_mode' "$reply_record")" == "email_exact" ]] || fail "reply record should persist governed quote-context email lookup"
[[ "$(jq -r '.customer_identity.greeting_name' "$reply_record")" == "Emilio" ]] || fail "reply record should persist Emilio as the effective greeting name"
[[ "$(jq -r '.customer_quote_intelligence.customer_context_match.selector.customer_name' "$reply_record")" == "Emilio" ]] || fail "reply record should keep governed quote-context greeting truth"

pass "guided customer greeting truth persists and overrides fallback display-name greetings for future replies"
