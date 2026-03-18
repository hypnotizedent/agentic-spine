#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
ENSURE="$ROOT/ops/plugins/domains/mint/bin/customer-seed-ensure"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.intake.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v curl >/dev/null 2>&1 || fail "curl required"
[[ -x "$ENSURE" ]] || fail "missing customer-seed-ensure executable"

tmp="$(mktemp -d)"
trap '[[ -n "${server_pid:-}" ]] && kill "$server_pid" >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT="$DISPOSITION_CONTRACT"
export MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT="$QUOTE_INTAKE_CONTRACT"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"
snapshot_counter_file="$tmp/snapshot.counter"
echo "0" >"$snapshot_counter_file"

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
    mailbox=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --message-id) message_id="$2"; shift 2 ;;
        --mailbox) mailbox="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [[ "$mailbox" == "team@mintprints.com" ]] || {
      echo "unexpected mailbox: $mailbox" >&2
      exit 1
    }
    case "$message_id" in
      MSG-1)
        cat <<'JSON'
{"id":"MSG-1","conversationId":"conv-1","internetMessageId":"<msg-1@mintprints.com>","subject":"TowMaxx polos","receivedDateTime":"2026-03-12T15:00:00Z","bodyPreview":"Same as last time, but black instead of navy.","body":{"contentType":"Text","content":"Same as last time, but black instead of navy. Need this for next week."},"from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}}
JSON
        ;;
      MSG-2)
        cat <<'JSON'
{"id":"MSG-2","conversationId":"conv-1","internetMessageId":"<msg-2@mintprints.com>","subject":"Re: TowMaxx polos","receivedDateTime":"2026-03-12T15:05:00Z","bodyPreview":"Need 24 this time.","body":{"contentType":"Text","content":"Need 24 this time. Same polos as last order, black instead of navy."},"from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}}}
JSON
        ;;
      MSG-VENDOR)
        cat <<'JSON'
{"id":"MSG-VENDOR","conversationId":"conv-vendor","internetMessageId":"<vendor-1@mintprints.com>","subject":"FW: Sheik revision for PapaPalooza","receivedDateTime":"2026-03-12T15:10:00Z","bodyPreview":"Latest vendor revision is attached.","body":{"contentType":"Text","content":"Latest vendor revision is attached for the PapaPalooza correction pass from Sheik."},"from":{"emailAddress":{"address":"team@mintprints.com","name":"Mint Team"}}}
JSON
        ;;
      *)
        echo "unexpected message id: $message_id" >&2
        exit 1
        ;;
    esac
    ;;
  mint.customer.record.snapshot)
    email=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --email) email="$2"; shift 2 ;;
        --json) shift ;;
        *) shift ;;
      esac
    done
    [[ "$email" == "george@towmaxxtowing.com" ]] || {
      echo "unexpected snapshot email: $email" >&2
      exit 1
    }
    count="$(cat "$SNAPSHOT_COUNTER_FILE")"
    count="$((count + 1))"
    echo "$count" >"$SNAPSHOT_COUNTER_FILE"
    if [[ "$count" -eq 1 ]]; then
      cat <<'JSON'
{"data":{"agent_state":{"state":"existing_customer_legacy_history_only"},"fresh_slate":{"customers":[{"record_id":"cust-1","legacy_customer_id":"27949","metadata":{"printavo_customer_id":"10077020"}}],"latest_seed":null},"legacy_hold":{"orders":[{"order_number":"13623","nickname":"TowMaxx towing polos","status":"COMPLETE","due_date":"2025-11-05"}]}}}
JSON
    else
      cat <<'JSON'
{"data":{"agent_state":{"state":"existing_customer_seed_truth_present"},"fresh_slate":{"customers":[{"record_id":"cust-1","legacy_customer_id":"27949","metadata":{"printavo_customer_id":"10077020"}}],"latest_seed":{"seed_id":"seed-0001"}},"legacy_hold":{"orders":[{"order_number":"13623","nickname":"TowMaxx towing polos","status":"COMPLETE","due_date":"2025-11-05"}]}}}
JSON
    fi
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

server_script="$tmp/mock_files_api.py"
cat >"$server_script" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

seeds = {}
counter = 0

def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

class Handler(BaseHTTPRequestHandler):
    def _json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/v1/seeds":
            query = parse_qs(parsed.query)
            from_email = (query.get("from_email") or [""])[0].lower()
            rows = []
            for seed in seeds.values():
                if from_email and (seed.get("from_email") or "").lower() != from_email:
                    continue
                rows.append(seed)
            rows.sort(key=lambda row: row.get("updated_at") or "", reverse=True)
            self._json(200, {"seeds": rows, "count": len(rows), "required_metadata_keys": ["product", "quantity", "decoration_type"]})
            return
        if parsed.path.startswith("/api/v1/seeds/"):
            seed_id = parsed.path.rsplit("/", 1)[-1]
            seed = seeds.get(seed_id)
            if not seed:
                self._json(404, {"error": "Seed not found"})
                return
            self._json(200, seed)
            return
        self._json(404, {"error": "Not found"})

    def do_POST(self):
        global counter
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length else "{}"
        payload = json.loads(raw or "{}")
        if parsed.path == "/api/v1/seeds":
            counter += 1
            seed_id = f"seed-{counter:04d}"
            timestamp = now()
            seed = {
                "id": seed_id,
                "status": "new",
                "source": payload.get("source") or "email",
                "from_email": payload.get("from_email"),
                "contact_email": payload.get("contact_email"),
                "subject": payload.get("subject"),
                "request_text": payload.get("request_text"),
                "metadata": payload.get("metadata") or {},
                "has_line_item": False,
                "created_at": timestamp,
                "updated_at": timestamp,
            }
            seeds[seed_id] = seed
            self._json(201, {
                "id": seed["id"],
                "status": seed["status"],
                "source": seed["source"],
                "from_email": seed["from_email"],
                "subject": seed["subject"],
                "metadata": seed["metadata"],
                "has_line_item": seed["has_line_item"],
                "merged": False,
                "created_at": seed["created_at"],
                "updated_at": seed["updated_at"],
            })
            return
        if parsed.path.startswith("/api/v1/seeds/") and parsed.path.endswith("/metadata"):
            seed_id = parsed.path.split("/")[-2]
            seed = seeds.get(seed_id)
            if not seed:
                self._json(404, {"error": "Seed not found"})
                return
            seed["metadata"] = payload
            seed["updated_at"] = now()
            self._json(200, {
                "id": seed_id,
                "metadata": seed["metadata"],
                "has_line_item": False,
                "updated_at": seed["updated_at"],
            })
            return
        self._json(404, {"error": "Not found"})

    def log_message(self, format, *args):
        return

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(os.environ["PORT_FILE"], "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PY

port_file="$tmp/files-api.port"
PORT_FILE="$port_file" python3 "$server_script" &
server_pid=$!

for _ in $(seq 1 50); do
  [[ -f "$port_file" ]] && break
  sleep 0.1
done
[[ -f "$port_file" ]] || fail "mock files-api did not start"

port="$(cat "$port_file")"
export MINT_CUSTOMER_SEED_ENSURE_FILES_API_URL="http://127.0.0.1:$port"
export MINT_CUSTOMER_SEED_ENSURE_FILES_API_KEY=""
export SNAPSHOT_COUNTER_FILE="$snapshot_counter_file"

json_one="$("$ENSURE" MSG-1 --mailbox team@mintprints.com --json)"
json_two="$("$ENSURE" MSG-2 --mailbox team@mintprints.com --json)"
json_three="$("$ENSURE" MSG-2 --mailbox team@mintprints.com --json)"

seed_one="$(echo "$json_one" | jq -r '.seed.id')"
seed_two="$(echo "$json_two" | jq -r '.seed.id')"
seed_three="$(echo "$json_three" | jq -r '.seed.id')"

[[ "$(echo "$json_one" | jq -r '.action')" == "created" ]] || fail "first ensure should create the seed"
[[ "$(echo "$json_two" | jq -r '.action')" == "updated" ]] || fail "second ensure should update the existing thread seed"
[[ "$(echo "$json_three" | jq -r '.action')" == "idempotent" ]] || fail "third ensure should be idempotent for the same message even if snapshot state changes"
[[ "$seed_one" == "$seed_two" && "$seed_two" == "$seed_three" ]] || fail "all ensures should resolve to the same seed"

record_one="$(echo "$json_one" | jq -r '.record_file')"
record_two="$(echo "$json_two" | jq -r '.record_file')"
record_three="$(echo "$json_three" | jq -r '.record_file')"
index_file="$(echo "$json_three" | jq -r '.index_file')"

[[ -f "$record_one" ]] || fail "first ensure record should exist"
[[ -f "$record_two" ]] || fail "second ensure record should exist"
[[ -f "$record_three" ]] || fail "third ensure record should exist"
[[ -f "$index_file" ]] || fail "ensure index should exist"
[[ "$(wc -l < "$index_file" | tr -d ' ')" == "3" ]] || fail "ensure index should record all three runs"

seed_list="$(curl -fsS "http://127.0.0.1:$port/api/v1/seeds?from_email=george@towmaxxtowing.com")"
[[ "$(echo "$seed_list" | jq -r '.count')" == "1" ]] || fail "mock files-api should hold one seed"
message_count="$(echo "$seed_list" | jq -r '.seeds[0].metadata.spine_context.thread.message_ids | length')"
event_count="$(echo "$seed_list" | jq -r '.seeds[0].metadata.spine_context.thread.event_count')"
conversation_id="$(echo "$seed_list" | jq -r '.seeds[0].metadata.spine_context.thread.conversation_ids[0]')"
customer_state="$(jq -r '.agent_state.state' "$record_two")"
work_type="$(echo "$seed_list" | jq -r '.seeds[0].metadata.work_type')"

[[ "$message_count" == "2" ]] || fail "thread metadata should retain both message ids"
[[ "$event_count" == "2" ]] || fail "thread metadata should retain two events"
[[ "$conversation_id" == "conv-1" ]] || fail "thread metadata should keep the conversation id"
[[ "$customer_state" == "existing_customer_seed_truth_present" ]] || fail "record should keep the updated customer snapshot state without forcing a metadata rewrite"
[[ "$work_type" == "reorder" ]] || fail "seed metadata should keep inferred work type"
[[ "$(echo "$json_three" | jq -r '.receipts.mail_get_receipt')" == "/tmp/microsoft.mail.get.receipt.md" ]] || fail "output should keep mail get receipt"
[[ "$(echo "$json_three" | jq -r '.receipts.customer_snapshot_receipt')" == "/tmp/mint.customer.record.snapshot.receipt.md" ]] || fail "output should keep customer snapshot receipt"

set +e
vendor_out="$("$ENSURE" MSG-VENDOR --mailbox team@mintprints.com 2>&1)"
vendor_rc=$?
set -e
[[ "$vendor_rc" -ne 0 ]] || fail "vendor/internal revision thread must not create or mutate a customer seed"
echo "$vendor_out" | grep -F "customer-seed-ensure only allows customer_actionable mail" >/dev/null || fail "vendor refusal should explain the customer_actionable gate"
seed_list_after_vendor="$(curl -fsS "http://127.0.0.1:$port/api/v1/seeds?from_email=george@towmaxxtowing.com")"
[[ "$(echo "$seed_list_after_vendor" | jq -r '.count')" == "1" ]] || fail "vendor refusal must not create extra customer seeds"

pass "customer-seed-ensure creates, updates, and idempotently reuses inbox-driven seeds while blocking non-actionable vendor threads"
