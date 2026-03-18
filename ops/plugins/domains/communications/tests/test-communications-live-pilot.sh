#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
STACK_STATUS="$ROOT/ops/plugins/domains/communications/bin/communications-stack-status"
MAIL_SEARCH="$ROOT/ops/plugins/domains/communications/bin/communications-mail-search"
MAIL_SEND="$ROOT/ops/plugins/domains/communications/bin/communications-mail-send-test"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "yq required"
command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$STACK_STATUS" ]] || fail "missing stack status script"
[[ -x "$MAIL_SEARCH" ]] || fail "missing mail search script"
[[ -x "$MAIL_SEND" ]] || fail "missing mail send script"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/outbox" "$tmp/fake"

contract="$tmp/communications.contract.yaml"
cat >"$contract" <<'YAML'
version: 1
updated_at: "2026-02-21"
owner: "@ronny"
scope: communications-stack-ws1
pilot:
  stage: ws1-live-pilot
  provider: stalwart
  execution_backend: microsoft
  microsoft:
    cap_exec: "fake"
    live_probe_query: "*"
    search_default_top: 5
    default_mailbox: team@mintprints.com
  vm_target:
    hostname: communications-stack
    vm_id: "214"
    profile: spine-ready-v1
    proxmox_host: pve
  send_test:
    mode: live-pilot
    manual_approval_required: true
    default_sender: ronny@mintprints.com
    default_recipient: ronny@mintprints.com
    allowed_recipient_domains:
      - mintprints.com
      - communications.local
  mailboxes:
    - id: team
      address: team@mintprints.com
      role: customer-service
      status: active
    - id: ops
      address: ronny@mintprints.com
      role: operations
      status: active
YAML

microsoft_exec="$tmp/fake/microsoft-cap-exec"
cat >"$microsoft_exec" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
action="${1:-}"
shift || true
if [[ "$action" == "mail_search" ]]; then
  [[ " $* " == *" --mailbox team@mintprints.com "* ]] || {
    echo "expected --mailbox team@mintprints.com" >&2
    exit 2
  }
  cat <<'OUT'
=== secrets.exec ===
provider: infisical
{"value":[{"id":"msg-1","receivedDateTime":"2026-02-21T04:00:00Z","from":{"emailAddress":{"address":"noreply@promo.example"}},"subject":"Limited time sale","isRead":false,"bodyPreview":"Manage preferences or unsubscribe for this special offer"},{"id":"msg-2","receivedDateTime":"2026-02-21T04:02:00Z","from":{"emailAddress":{"address":"ronny@mintprints.com"}},"subject":"FW: papapalooza","isRead":true,"bodyPreview":"Use the attached papapalooza.pdf for Troy."},{"id":"msg-3","receivedDateTime":"2026-02-21T04:01:00Z","from":{"emailAddress":{"address":"customer@example.com"}},"subject":"Need quote","isRead":false,"bodyPreview":"Need 24 shirts for the event."},{"id":"msg-4","receivedDateTime":"2026-02-21T04:03:00Z","from":{"emailAddress":{"address":"jackson.simmons@boardsi.com"}},"subject":"Advisors Needed","isRead":false,"bodyPreview":"Your profile is a good fit for current companies we are helping fill open board and advisory opportunities. Free for a quick conversation to learn more? See our calendar below: https://calendly.com/boardsi/board-opportunities"}]}
OUT
  exit 0
fi
if [[ "$action" == "mail_send" ]]; then
  cat <<'OUT'
=== secrets.exec ===
provider: infisical
{}
OUT
  exit 0
fi
echo "unsupported action: $action" >&2
exit 2
SH
chmod +x "$microsoft_exec"

export COMMUNICATIONS_STACK_CONTRACT="$contract"
export COMMUNICATIONS_MICROSOFT_EXEC_LEGACY="$microsoft_exec"
export SPINE_OUTBOX="$tmp/outbox"

# stack status must parse mixed-output microsoft payload and report live probe OK
stack_out="$("$STACK_STATUS")"
echo "$stack_out" | grep "status: OK" >/dev/null || fail "stack status should pass in live-pilot"
echo "$stack_out" | grep "live_probe_status: ok" >/dev/null || fail "stack live probe should be ok"
pass "communications-stack-status live probe"

# live mail search should parse messages from mixed output
search_out="$("$MAIL_SEARCH" --query "*" --top 4)"
echo "$search_out" | grep "matches: 4" >/dev/null || fail "mail search should show four parsed messages"
echo "$search_out" | grep "mailbox: team@mintprints.com" >/dev/null || fail "mail search should show team mailbox"
echo "$search_out" | grep "FW: papapalooza" >/dev/null || fail "mail search should include parsed subject"
pass "communications-mail-search live parsing"

triage_out="$(COMMUNICATIONS_MAIL_SEARCH_CAPABILITY_NAME=mint.customer.inbox.triage "$MAIL_SEARCH" --triage --top 4)"
echo "$triage_out" | grep "^mint.customer.inbox.triage$" >/dev/null || fail "triage should emit capability override label"
echo "$triage_out" | grep "message_id: msg-2" >/dev/null || fail "triage should list message ids"
echo "$triage_out" | grep "read_state: read" >/dev/null || fail "triage should surface read state"
echo "$triage_out" | grep "triage_class: internal_forwarded" >/dev/null || fail "triage should classify internal forwarded mail"
echo "$triage_out" | grep "recommended_action: review_in_customer_lane" >/dev/null || fail "triage should surface customer-lane recommendation"
echo "$triage_out" | grep "triage_class: promotional" >/dev/null || fail "triage should classify promotional mail without opening it"
echo "$triage_out" | grep "recommended_action: hide_from_primary_lane_keep_recoverable" >/dev/null || fail "triage should keep promotional mail recoverable"
echo "$triage_out" | grep "message_id: msg-4" >/dev/null || fail "triage should include outreach proving-case message"
echo "$triage_out" | grep "from: jackson.simmons@boardsi.com" >/dev/null || fail "triage should surface Boardsi sender"
echo "$triage_out" | grep "subject: Advisors Needed" >/dev/null || fail "triage should surface Boardsi subject"
echo "$triage_out" | grep "classification_basis: known_outreach_sender, advisors needed, advisory opportunities" >/dev/null || fail "triage should classify recruiter outreach by sender plus advisory markers"
echo "$triage_out" | grep "link_policy: do_not_open_body_links" >/dev/null || fail "triage should surface the no-link-opening policy"
echo "$triage_out" | grep "preview: Use the attached papapalooza.pdf for Troy." >/dev/null || fail "triage should surface preview text"
pass "communications-mail-search triage rendering"

# execute is now blocked for email even in live-pilot mode
set +e
send_out="$("$MAIL_SEND" --subject "test subject" --body "test body" --execute 2>&1)"
send_rc=$?
set -e
[[ "$send_rc" -ne 0 ]] || fail "mail send execute should be blocked"
echo "$send_out" | grep "Drafts only" >/dev/null || fail "mail send execute block should explain drafts-only policy"
pass "communications-mail-send-test execute block"

# dry-run preview still works
dry_out="$("$MAIL_SEND" --subject "sim subject" --body "sim body")"
echo "$dry_out" | grep "to: ronny@mintprints.com" >/dev/null || fail "mail send dry-run should use contract default recipient"
echo "$dry_out" | grep "DRY-RUN" >/dev/null || fail "mail send dry-run should remain available"
pass "communications-mail-send-test dry-run"

echo "communications live pilot tests"
