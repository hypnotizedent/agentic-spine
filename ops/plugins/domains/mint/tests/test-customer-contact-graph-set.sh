#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SET_GRAPH="$ROOT/ops/plugins/domains/mint/bin/customer-contact-graph-set"
SNAPSHOT="$ROOT/ops/plugins/domains/mint/bin/customer-record-snapshot"
GRAPH_CONTRACT="$ROOT/ops/bindings/mint.customer.contact.graph.contract.yaml"
QUOTE_CONTEXT_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.context.contract.yaml"
QUOTE_POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$SET_GRAPH" ]] || fail "missing customer-contact-graph-set executable"
[[ -x "$SNAPSHOT" ]] || fail "missing customer-record-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_CONTACT_GRAPH_CONTRACT="$GRAPH_CONTRACT"
export MINT_CUSTOMER_QUOTE_CONTEXT_CONTRACT="$QUOTE_CONTEXT_CONTRACT"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$QUOTE_POLICY_CONTRACT"
fixture="$tmp/customers.json"
cat >"$fixture" <<'JSON'
[
  {
    "record_id": "cust-cove",
    "email": "marketing@covebrewery.com",
    "name": "Spencer Todd",
    "company": "Cove Brewery",
    "metadata": {}
  }
]
JSON
export MINT_CUSTOMER_RECORD_FIXTURE_FILE="$fixture"

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
  mint.seeds.query)
    printf '{"rows":[]}\n'
    ;;
  mint.payment.record.snapshot)
    printf '{"capability":"mint.payment.record.snapshot","state":"no_payment_found","match_count":0,"latest":null,"matches":[]}\n'
    ;;
  mint.artifact.record.snapshot)
    printf '{"capability":"mint.artifact.record.snapshot","state":"no_artifact_found","match_count":0,"active_count":0,"latest":null,"artifacts":[]}\n'
    ;;
  mint.artwork.intelligence.snapshot)
    printf '{"capability":"mint.artwork.intelligence.snapshot","state":"no_analysis_found","match_count":0,"latest":null,"matches":[]}\n'
    ;;
  mint.printavo.bridge.snapshot)
    printf '{"capability":"mint.printavo.bridge.snapshot","state":"no_bridge_found","match_count":0,"latest":null,"matches":[]}\n'
    ;;
  *)
    echo "unsupported capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$SPINE_ROOT/bin/ops"

json_set="$("$SET_GRAPH" \
  --company "Cove Brewery" \
  --domain "covebrewery.com" \
  --domain "whelchelpartners.com" \
  --contact "email=marketing@covebrewery.com,name=Spencer Todd,greeting_name=Spencer,role=marketing,role=buyer,status=active,confidence=high" \
  --contact "email=khartofilis@whelchelpartners.com,name=Kristy Hartofilis,greeting_name=Kristy,role=owner,role=approver,status=historical,confidence=high" \
  --relationship-note "Spencer drives current quote traffic; Kristy remains a historical owner/approver." \
  --json)"

[[ "$(echo "$json_set" | jq -r '.data.account.company_name')" == "Cove Brewery" ]] || fail "company should persist"
[[ "$(echo "$json_set" | jq -r '.data.contacts[0].greeting_name')" == "Spencer" ]] || fail "contact greeting should persist"
[[ "$(echo "$json_set" | jq -r '.data.contacts[1].roles | join(",")')" == "owner,approver" ]] || fail "roles should persist"

json_snapshot="$("$SNAPSHOT" --email "marketing@covebrewery.com" --json)"

[[ "$(echo "$json_snapshot" | jq -r '.company_contact_graph.match_mode')" == "contact_email_exact" ]] || fail "snapshot should match the company contact graph by contact email"
[[ "$(echo "$json_snapshot" | jq -r '.company_contact_graph.account.company_name')" == "Cove Brewery" ]] || fail "snapshot should surface the company account"
[[ "$(echo "$json_snapshot" | jq -r '.company_contact_graph.contacts | length')" == "2" ]] || fail "snapshot should surface both Spencer and Kristy under the same company"
[[ "$(echo "$json_snapshot" | jq -r '.company_contact_graph.summary.contact_names | join(",")')" == "Spencer,Kristy" ]] || fail "snapshot should summarize the related contact names"

pass "customer-contact-graph-set persists a governed company/contact graph that customer-record-snapshot can query"
