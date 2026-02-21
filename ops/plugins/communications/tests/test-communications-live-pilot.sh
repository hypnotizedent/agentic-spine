#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}"
STACK_STATUS="$ROOT/ops/plugins/communications/bin/communications-stack-status"
MAIL_SEARCH="$ROOT/ops/plugins/communications/bin/communications-mail-search"
MAIL_SEND="$ROOT/ops/plugins/communications/bin/communications-mail-send-test"

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
  execution_backend: microsoft-graph
  graph:
    cap_exec: "fake"
    live_probe_query: "*"
    search_default_top: 5
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
    - id: ops
      address: ronny@mintprints.com
      role: operations
      status: active
YAML

graph_exec="$tmp/fake/graph-cap-exec"
cat >"$graph_exec" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
action="${1:-}"
shift || true
if [[ "$action" == "mail_search" ]]; then
  cat <<'OUT'
=== secrets.exec ===
provider: infisical
{"value":[{"receivedDateTime":"2026-02-21T04:00:00Z","from":{"emailAddress":{"address":"a@example.com"}},"subject":"Alpha"},{"receivedDateTime":"2026-02-21T04:01:00Z","from":{"emailAddress":{"address":"b@example.com"}},"subject":"Beta"}]}
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
chmod +x "$graph_exec"

export COMMUNICATIONS_STACK_CONTRACT="$contract"
export COMMUNICATIONS_GRAPH_EXEC="$graph_exec"
export SPINE_OUTBOX="$tmp/outbox"

# stack status must parse mixed-output graph payload and report live probe OK
stack_out="$("$STACK_STATUS")"
echo "$stack_out" | grep "status: OK" >/dev/null || fail "stack status should pass in live-pilot"
echo "$stack_out" | grep "live_probe_status: ok" >/dev/null || fail "stack live probe should be ok"
pass "communications-stack-status live probe"

# live mail search should parse messages from mixed output
search_out="$("$MAIL_SEARCH" --query "*" --top 2)"
echo "$search_out" | grep "matches: 2" >/dev/null || fail "mail search should show two parsed messages"
echo "$search_out" | grep "Alpha" >/dev/null || fail "mail search should include parsed subject"
pass "communications-mail-search live parsing"

# live send test execute should use contract default recipient and write record under SPINE_OUTBOX
send_out="$("$MAIL_SEND" --subject "test subject" --body "test body" --execute)"
echo "$send_out" | grep "to: ronny@mintprints.com" >/dev/null || fail "mail send should use contract default recipient"
echo "$send_out" | grep "status: sent" >/dev/null || fail "mail send live mode should report sent"
record_path="$(echo "$send_out" | awk -F': ' '/^record:/ {print $2}')"
[[ -n "$record_path" && -f "$record_path" ]] || fail "mail send should write record file"
pass "communications-mail-send-test live execute"

# simulation fallback still works
yq e -i '.pilot.send_test.mode = "simulation-only"' "$contract"
sim_out="$("$MAIL_SEND" --subject "sim subject" --body "sim body" --execute)"
echo "$sim_out" | grep "to: ronny@mintprints.com" >/dev/null || fail "mail send simulation should use contract default recipient"
echo "$sim_out" | grep "status: simulated" >/dev/null || fail "mail send simulation mode should report simulated"
pass "communications-mail-send-test simulation execute"

echo "communications live pilot tests"
