#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SETTER="$ROOT/ops/plugins/domains/mint/bin/customer-identity-set"
SNAPSHOT="$ROOT/ops/plugins/domains/mint/bin/customer-record-snapshot"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$SETTER" ]] || fail "missing customer-identity-set executable"
[[ -x "$SNAPSHOT" ]] || fail "missing customer-record-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fixture="$tmp/customers.json"
cat >"$fixture" <<'JSON'
[
  {
    "record_id": "68083fbb-8af4-4f06-85bb-5067b4d06e25",
    "email": "fredofrancis1@gmail.com",
    "name": "Alfred Francis",
    "first_name": "Alfred",
    "last_name": "Francis",
    "company": "Fredo Paints",
    "metadata": {
      "legacy_row": {
        "printavo_id": "7697259"
      }
    }
  }
]
JSON

export MINT_CUSTOMER_RECORD_FIXTURE_FILE="$fixture"
export SPINE_STATE="$tmp/state"

json_set="$("$SETTER" --email fredofrancis1@gmail.com --preferred-name Fredo --greeting-name Fredo --alias Fredo --set-by ronny --source operator_confirmed --confidence high --json)"
record_file="$(echo "$json_set" | jq -r '.data.record_file')"

[[ -f "$record_file" ]] || fail "identity update record should exist"
[[ "$(echo "$json_set" | jq -r '.data.identity.legal_name')" == "Alfred Francis" ]] || fail "legal name should remain preserved"
[[ "$(echo "$json_set" | jq -r '.data.identity.preferred_name')" == "Fredo" ]] || fail "preferred name should persist"
[[ "$(echo "$json_set" | jq -r '.data.identity.greeting_name')" == "Fredo" ]] || fail "greeting name should persist"
[[ "$(echo "$json_set" | jq -r '.data.identity.display_name')" == "Fredo" ]] || fail "display name should default to customer-facing truth"
[[ "$(echo "$json_set" | jq -r '.data.identity.provenance.set_by')" == "ronny" ]] || fail "provenance should persist operator"

[[ "$(jq -r '.[0].metadata.customer_identity.preferred_name' "$fixture")" == "Fredo" ]] || fail "fixture should persist preferred name in metadata.customer_identity"
[[ "$(jq -r '.[0].metadata.customer_identity.greeting_name' "$fixture")" == "Fredo" ]] || fail "fixture should persist greeting name"

json_snapshot_email="$("$SNAPSHOT" --email fredofrancis1@gmail.com --json)"
json_snapshot_name="$("$SNAPSHOT" --name 'Alfred Francis' --json)"

[[ "$(echo "$json_snapshot_email" | jq -r '.fresh_slate.identity.greeting_name')" == "Fredo" ]] || fail "snapshot email lookup should surface greeting name"
[[ "$(echo "$json_snapshot_name" | jq -r '.fresh_slate.identity.preferred_name')" == "Fredo" ]] || fail "snapshot name lookup should surface preferred name"
[[ "$(echo "$json_snapshot_name" | jq -r '.fresh_slate.customer.record_id')" == "68083fbb-8af4-4f06-85bb-5067b4d06e25" ]] || fail "snapshot name lookup should resolve the canonical customer record"

pass "customer-identity-set persists governed customer-facing identity and customer-record-snapshot reads it back"
