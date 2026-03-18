#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
BIN="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-startup"
CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.startup.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$BIN" ]] || fail "missing customer-inbox-startup executable"
[[ -f "$CONTRACT" ]] || fail "missing startup contract"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fake_spine="$tmp/spine"
fake_state="$tmp/state"
ops_log="$tmp/ops.log"
mkdir -p "$fake_spine/bin" "$fake_state/sessions/SES-STARTUP-001"

cat >"$fake_state/sessions/SES-STARTUP-001/session.yaml" <<EOF
id: SES-STARTUP-001
pid: $$
EOF

cat >"$fake_spine/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAKE_OPS_LOG:?}"
capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

printf '%s' "$capability" >>"$log_file"
for arg in "$@"; do
  printf ' %s' "$arg" >>"$log_file"
done
printf '\n' >>"$log_file"

echo "Receipt: /tmp/${capability}.receipt.md"

case "$capability" in
  mint.modules.health)
    cat <<'OUT'
files-api  OK  reachable  baseline healthy
OUT
    ;;
  mint.customer.inbox.work_items)
    cat <<'JSON'
{"mailbox":"team@mintprints.com","backlog_count":3,"hydration_mode":"preview_only","selection_order":"oldest_first","record_file":"/tmp/work-items.json","work_items":[{"thread_id":"C-OLD","subject":"Oldest customer ask"},{"thread_id":"C-MID","subject":"Middle ask"},{"thread_id":"C-NEW","subject":"Newest ask"}]}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_spine/bin/ops"

json_out="$(
  env \
    SPINE_ROOT="$fake_spine" \
    SPINE_STATE="$fake_state" \
    SPINE_SESSION_ID="SES-STARTUP-001" \
    OPS_TERMINAL_ROLE="MINT-MORPHEUS-01" \
    FAKE_OPS_LOG="$ops_log" \
    MINT_CUSTOMER_INBOX_STARTUP_CONTRACT="$CONTRACT" \
    "$BIN" --mailbox team@mintprints.com --json
)"

record_file="$(echo "$json_out" | jq -r '.record_file')"

[[ "$(echo "$json_out" | jq -r '.mode')" == "canonical_inbox_work_items" ]] || fail "startup mode should be canonical_inbox_work_items"
[[ "$(echo "$json_out" | jq -r '.selection_order')" == "oldest_first" ]] || fail "selection order should be oldest_first"
[[ "$(echo "$json_out" | jq -r '.health_check.status')" == "OK" ]] || fail "health check should parse OK"
[[ "$(echo "$json_out" | jq -r '.work_items.first_thread_id')" == "C-OLD" ]] || fail "startup should expose the oldest thread first"
[[ "$(echo "$json_out" | jq -r '.work_items.hydration_mode')" == "preview_only" ]] || fail "startup should expose preview-only work-item hydration"
[[ "$(echo "$json_out" | jq -r '.first_action_command')" == "mintctl morpheus inbox work-next" ]] || fail "startup should publish the work-next action"
[[ "$(echo "$json_out" | jq -r '.scope_lock')" == "Mint Prints customer email inbox only" ]] || fail "startup should carry the Morpheus scope lock"
[[ "$(echo "$json_out" | jq -r '.queue_cursor.current_claim_message_id')" == "" ]] || fail "startup should not create a queue claim"
[[ -f "$record_file" ]] || fail "startup record file should exist"
grep '^mint.customer.inbox.work_items --mailbox team@mintprints.com --top 10 --json --preview-only$' "$ops_log" >/dev/null || fail "startup should request preview-only work items by default"

pass "customer-inbox-startup composes health + work-items + oldest-first launch defaults"

echo "customer-inbox-startup tests"
