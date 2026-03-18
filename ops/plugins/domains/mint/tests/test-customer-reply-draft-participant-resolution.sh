#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
OPERATOR_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.operator.policy.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$REPLY" ]] || fail "missing customer-reply-draft executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$POLICY_CONTRACT"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
export MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT="$OPERATOR_POLICY_CONTRACT"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
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
      MSG-FWD)
        cat <<'JSON'
{"id":"MSG-FWD","subject":"FW: papapalooza","conversationId":"CONV-INTERNAL","internetMessageId":"<fwd@example.com>","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Prints Team"}},"bodyPreview":"Forwarded vendor proof thread for papapalooza.","body":{"contentType":"HTML","content":"<html><body><div>Please reply to the customer, not the vendor.</div><br><div><b>From:</b> Sheikh Amaan &lt;digitrace54@gmail.com&gt;</div><div><b>Subject:</b> Re: papapalooza</div></body></html>"}} 
JSON
        ;;
      MSG-FWD-ONLYVENDOR)
        cat <<'JSON'
{"id":"MSG-FWD-ONLYVENDOR","subject":"FW: vendor proof correction pass","conversationId":"CONV-INTERNAL-VENDOR","internetMessageId":"<fwd-vendor@example.com>","from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Prints Team"}},"bodyPreview":"Forwarded vendor proof thread only.","body":{"contentType":"HTML","content":"<html><body><div><b>From:</b> Sheikh Amaan &lt;digitrace54@gmail.com&gt;</div><div><b>Subject:</b> Re: papapalooza</div><div>Here you go sir.</div></body></html>"}} 
JSON
        ;;
      MSG-CUST)
        cat <<'JSON'
{"id":"MSG-CUST","subject":"Papapalooza","conversationId":"CONV-CUSTOMER","internetMessageId":"<cust@example.com>","receivedDateTime":"2026-03-13T10:53:22Z","from":{"emailAddress":{"address":"troy@papasrawbar.com","name":"Troy Ganter"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Hey brother, we need this by April 18th.</div>"}} 
JSON
        ;;
      MSG-VENDOR)
        cat <<'JSON'
{"id":"MSG-VENDOR","subject":"Re: papapalooza","conversationId":"CONV-VENDOR","internetMessageId":"<vendor@example.com>","receivedDateTime":"2026-03-13T09:12:00Z","from":{"emailAddress":{"address":"digitrace54@gmail.com","name":"Sheikh Amaan"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Here you go Sir.</div><div>Let me know if this looks good.</div>"}} 
JSON
        ;;
      DRAFT-P)
        draft_subject="$(cat "${SPINE_STATE}/draft-subject.txt" 2>/dev/null || printf '13823 PapaPalooza')"
        draft_to="$(cat "${SPINE_STATE}/draft-to.txt" 2>/dev/null || printf 'troy@papasrawbar.com')"
        draft_cc="$(cat "${SPINE_STATE}/draft-cc.txt" 2>/dev/null || printf '')"
        draft_body="$(cat "${SPINE_STATE}/draft-body.html" 2>/dev/null || printf '<div>Quoted thread</div>')"
        python3 - <<'PY' "$draft_subject" "$draft_to" "$draft_cc" "$draft_body"
import json
import sys

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

payload = {
    "id": "DRAFT-P",
    "subject": sys.argv[1],
    "conversationId": "CONV-CUSTOMER",
    "toRecipients": parse_csv(sys.argv[2]),
    "ccRecipients": parse_csv(sys.argv[3]),
    "body": {"contentType": "HTML", "content": sys.argv[4]},
}
print(json.dumps(payload))
PY
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  communications.mail.search)
    query=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --query) query="$2"; shift 2 ;;
        --top) shift 2 ;;
        --mailbox) shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    printf '%s\n' "$query" >>"${SPINE_STATE}/search-queries.log"
    case "$query" in
      papapalooza)
        cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-VENDOR","subject":"Re: papapalooza","conversationId":"CONV-VENDOR","internetMessageId":"<vendor@example.com>","receivedDateTime":"2026-03-13T09:12:00Z","from":{"emailAddress":{"address":"digitrace54@gmail.com","name":"Sheikh Amaan"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"Here you go Sir. Let me know if this looks good."},
  {"id":"MSG-CUST","subject":"Papapalooza","conversationId":"CONV-CUSTOMER","internetMessageId":"<cust@example.com>","receivedDateTime":"2026-03-13T10:53:22Z","from":{"emailAddress":{"address":"troy@papasrawbar.com","name":"Troy Ganter"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"We need this by April 18th."}
]}}}
JSON
        ;;
      "vendor proof correction pass")
        cat <<'JSON'
{"data":{"microsoft":{"value":[
  {"id":"MSG-VENDOR","subject":"Re: papapalooza","conversationId":"CONV-VENDOR","internetMessageId":"<vendor@example.com>","receivedDateTime":"2026-03-13T09:12:00Z","from":{"emailAddress":{"address":"digitrace54@gmail.com","name":"Sheikh Amaan"}},"toRecipients":[{"emailAddress":{"address":"team@mintprints.com"}}],"ccRecipients":[],"bodyPreview":"Here you go Sir. Let me know if this looks good."}
]}}}
JSON
        ;;
      *)
        cat <<'JSON'
{"data":{"microsoft":{"value":[]}}}
JSON
        ;;
    esac
    ;;
  microsoft.mail.reply.draft)
    message_id=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s\n' "$message_id" >>"${SPINE_STATE}/reply-draft-calls.log"
    case "$message_id" in
      MSG-CUST)
        cat <<'JSON'
{"id":"DRAFT-P","subject":"Re: Papapalooza","conversationId":"CONV-CUSTOMER","toRecipients":[{"emailAddress":{"address":"troy@papasrawbar.com"}}],"ccRecipients":[],"body":{"contentType":"HTML","content":"<div>Quoted thread</div>"}} 
JSON
        ;;
      *)
        echo "reply draft targeted unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  microsoft.mail.draft.update)
    message_id=""
    body=""
    subject=""
    to_csv=""
    cc_csv=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --body) body="$2"; shift 2 ;;
        --subject) subject="$2"; shift 2 ;;
        --to) to_csv="$2"; shift 2 ;;
        --cc) cc_csv="$2"; shift 2 ;;
        --content-type) shift 2 ;;
        --mailbox) shift 2 ;;
        *) shift ;;
      esac
    done
    printf '%s' "$message_id" >"${SPINE_STATE}/last-update-draft-id.txt"
    printf '%s' "$subject" >"${SPINE_STATE}/draft-subject.txt"
    printf '%s' "$to_csv" >"${SPINE_STATE}/draft-to.txt"
    printf '%s' "$cc_csv" >"${SPINE_STATE}/draft-cc.txt"
    printf '%s' "$body" >"${SPINE_STATE}/draft-body.html"
    python3 - <<'PY' "$message_id" "$subject" "$to_csv" "$cc_csv"
import json
import sys

def parse_csv(text):
    out = []
    for item in text.split(","):
        cleaned = item.strip()
        if cleaned:
            out.append({"emailAddress": {"address": cleaned}})
    return out

payload = {
    "id": sys.argv[1],
    "subject": sys.argv[2],
    "toRecipients": parse_csv(sys.argv[3]),
    "ccRecipients": parse_csv(sys.argv[4]),
}
print(json.dumps(payload))
PY
    ;;
  mint.customer.record.snapshot)
    cat <<'JSON'
{"data":{"query_mode":"fallback","fresh_slate":{"customers":[],"customer_match_count":0},"legacy_hold":{"orders":[]}}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

mkdir -p \
  "$SPINE_STATE/mint/customer-reply-drafts" \
  "$SPINE_STATE/mint/customer-seed-ensures/records/2026/03/13" \
  "$SPINE_STATE/mint/sheik-revision-handoffs" \
  "$tmp/packets"

cat >"$tmp/packets/quote_packet_poisoned.yaml" <<'EOF'
quote_packet_id: packet-poisoned
customer_ref:
  resolved_email: digitrace54@gmail.com
  resolved_name: Sheikh Amaan
EOF

cat >"$SPINE_STATE/mint/customer-reply-drafts/index.ndjson" <<'EOF'
{"reply_draft_id":"MRD-HISTORY-1","source_message_id":"MSG-FWD","source_conversation_id":"CONV-INTERNAL","customer":"Papa's Raw Bar","job":"13823 PapaPalooza","stored_at_utc":"2026-03-12T16:10:13Z","mailbox":"team@mintprints.com","thread_mode":"reply_chain"}
EOF

cat >"$SPINE_STATE/mint/customer-seed-ensures/records/2026/03/13/MSE-BAD.json" <<'EOF'
{
  "ensure_id": "MSE-BAD",
  "customer_email": "digitrace54@gmail.com",
  "customer_display_name": "Sheikh Amaan",
  "source_message_id": "MSG-FWD",
  "source_subject": "FW: papapalooza",
  "summary": "From: Sheikh Amaan <digitrace54@gmail.com> Re: papapalooza",
  "work_type": "ambiguous"
}
EOF

cat >"$SPINE_STATE/mint/customer-seed-ensures/records/2026/03/13/MSE-GOOD.json" <<'EOF'
{
  "ensure_id": "MSE-GOOD",
  "customer_email": "troy@papasrawbar.com",
  "customer_display_name": "Papa's Raw Bar",
  "source_message_id": "MSG-CUST",
  "source_subject": "Papapalooza",
  "summary": "Troy from Papa's Raw Bar needs this by April 18th.",
  "work_type": "proof_review"
}
EOF

cat >"$SPINE_STATE/mint/customer-seed-ensures/index.ndjson" <<'EOF'
{"ensure_id":"MSE-BAD","customer_email":"digitrace54@gmail.com","source_message_id":"MSG-FWD","stored_at_utc":"2026-03-13T22:29:48Z","work_type":"ambiguous"}
{"ensure_id":"MSE-GOOD","customer_email":"troy@papasrawbar.com","source_message_id":"MSG-CUST","stored_at_utc":"2026-03-13T21:50:04Z","work_type":"proof_review"}
EOF

cat >"$SPINE_STATE/mint/sheik-revision-handoffs/index.ndjson" <<'EOF'
{"customer_identity":"Papa's Raw Bar","job_identity":"13823","vendor_identity":"Sheik","record_file":"/tmp/sheik-runtime.json"}
EOF

json_ok="$("$REPLY" MSG-FWD \
  --mailbox team@mintprints.com \
  --body "Reviewing the next revision with art dept now." \
  --job-number 13823 \
  --job-nickname "PapaPalooza" \
  --packet-file "$tmp/packets/quote_packet_poisoned.yaml" \
  --json)"

[[ "$(echo "$json_ok" | jq -r '.data.participant_resolution.reply_target_role')" == "customer" ]] || fail "customer-facing reply should only continue when the resolver selects a customer thread"
[[ "$(echo "$json_ok" | jq -r '.data.participant_resolution.canonical_customer_thread.message_id')" == "MSG-CUST" ]] || fail "resolver should select the canonical customer thread"
[[ "$(echo "$json_ok" | jq -r '.data.participant_resolution.canonical_vendor_thread.message_id')" == "MSG-VENDOR" ]] || fail "resolver should preserve the vendor thread separately"
[[ "$(echo "$json_ok" | jq -r '.data.canonical_thread.message_id')" == "MSG-CUST" ]] || fail "canonical outbound thread should point at the customer message"
[[ "$(echo "$json_ok" | jq -r '.data.canonical_thread.reply_target_role')" == "customer" ]] || fail "canonical thread record should persist the customer target role"
[[ "$(echo "$json_ok" | jq -r '.data.draft_to')" == "troy@papasrawbar.com" ]] || fail "draft recipients should resolve from the customer thread"
[[ "$(cat "$SPINE_STATE/reply-draft-calls.log")" == "MSG-CUST" ]] || fail "reply draft provider call should target the customer thread, not the vendor thread"
grep -F 'papapalooza' "$SPINE_STATE/search-queries.log" >/dev/null || fail "resolver should search the governed thread history when the source message is internal"
binding_record="$(echo "$json_ok" | jq -r '.data.outbound_binding.record_file')"
[[ "$(jq -r '.participant_resolution.reply_target_role' "$binding_record")" == "customer" ]] || fail "binding record should persist the participant-role decision"
[[ "$(jq -r '.participant_resolution.canonical_vendor_thread.message_id' "$binding_record")" == "MSG-VENDOR" ]] || fail "binding record should keep the vendor thread separately"

if "$REPLY" MSG-FWD-ONLYVENDOR \
  --mailbox team@mintprints.com \
  --body "Reviewing the next revision with art dept now." \
  --job-number 13823 \
  --job-nickname "PapaPalooza" \
  --packet-file "$tmp/packets/quote_packet_poisoned.yaml" >/dev/null 2>"$tmp/vendor-only-error.log"; then
  fail "vendor-only evidence should block customer-facing draft creation"
fi
grep -F 'Need the real customer thread before I can draft customer-facing mail. Best known thread role: vendor (digitrace54@gmail.com).' "$tmp/vendor-only-error.log" >/dev/null || fail "vendor-only blocker should stay concise and explicit"

pass "customer-reply-draft resolves customer vs vendor participant roles and refuses customer-facing drafts without a canonical customer thread"
