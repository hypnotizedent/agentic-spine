#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
REPLY="$ROOT/ops/plugins/domains/mint/bin/customer-reply-draft"
REPLY_POLICY_CONTRACT="$ROOT/ops/bindings/mint.customer.reply.draft.policy.contract.yaml"
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
export MINT_CUSTOMER_REPLY_DRAFT_POLICY_CONTRACT="$REPLY_POLICY_CONTRACT"
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
    cat <<'JSON'
{"id":"MSG-REORDER","subject":"TowMaxx Towing shirts","conversationId":"CONV-REORDER","internetMessageId":"<reorder@example.com>","from":{"emailAddress":{"address":"george@towmaxxtowing.com","name":"George Mouakar"}},"bodyPreview":"I want to do the same shirts as my last order but black this time.","body":{"contentType":"HTML","content":"<div>I need to order:</div><div>5 M, 4 L, 5 XL, 4 XXL, 2 XXXL</div><div>I want to do the same shirts as my last order but black this time.</div>"}} 
JSON
    ;;
  mint.customer.quote.intake)
    printf 'unexpected quote intake\n' >>"${SPINE_STATE}/quote-intake.log"
    cat <<'JSON'
{"data":{"record_file":"/tmp/bad-intake.json"}}
JSON
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

mkdir -p "$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13"
cat >"$SPINE_STATE/mint/customer-quote-intakes/index.ndjson" <<EOF
{"message_id":"MSG-REORDER","record_file":"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/bad.json"}
EOF
cat >"$SPINE_STATE/mint/customer-quote-intakes/records/2026/03/13/bad.json" <<'EOF'
{"intake_quality":{"classification":"headache"},"handoff":{"packet_file":"/tmp/missing.yaml"}}
EOF

set +e
out="$("$REPLY" MSG-REORDER --mailbox team@mintprints.com --quote-subject "13842 TowMaxx towing polos" --json 2>&1)"
status=$?
set -e

[[ "$status" == "2" ]] || fail "reorder/live-quote guard should fail closed instead of auto-drafting from quote intake"
echo "$out" | grep -F "reorder/live-quote thread detected" >/dev/null || fail "guard should explain why auto quote generation was blocked"
[[ ! -f "$SPINE_STATE/quote-intake.log" ]] || fail "reorder/live-quote guard should not call mint.customer.quote.intake"

pass "customer-reply-draft blocks generic quote-intake auto-generation for reorder/live-quote threads"
