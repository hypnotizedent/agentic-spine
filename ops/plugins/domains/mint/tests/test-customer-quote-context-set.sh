#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
SETTER="$ROOT/ops/plugins/domains/mint/bin/customer-quote-context-set"
SNAPSHOT="$ROOT/ops/plugins/domains/mint/bin/customer-record-snapshot"
POLICY_CONTRACT="$ROOT/ops/bindings/mint.quote.intelligence.policy.contract.yaml"
CONTEXT_CONTRACT="$ROOT/ops/bindings/mint.customer.quote.context.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$SETTER" ]] || fail "missing customer-quote-context-set executable"
[[ -x "$SNAPSHOT" ]] || fail "missing customer-record-snapshot executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fixture="$tmp/customers.json"
printf '[]\n' >"$fixture"

export SPINE_ROOT="$ROOT"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_RECORD_FIXTURE_FILE="$fixture"
export MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT="$POLICY_CONTRACT"
export MINT_CUSTOMER_QUOTE_CONTEXT_CONTRACT="$CONTEXT_CONTRACT"

json_set="$("$SETTER" \
  --email jon@ptpuniversal.com \
  --customer-name "Jonathan Lieberman" \
  --company "PTP Universal" \
  --segment middleman_printer \
  --segment contract_printer \
  --segment broker_printer \
  --volume-expectation expected_volume \
  --relationship-note "Expected volume partner; judge differently from standard retail one-offs." \
  --job-type memorial \
  --default-posture discouraged \
  --allow-goodwill-exception \
  --flat-rate-each-usd 25 \
  --exception-note "We are willing to do this memorial run for Jon out of appreciation." \
  --set-by ronny \
  --json)"

record_file="$(echo "$json_set" | jq -r '.data.record_file')"
[[ -f "$record_file" ]] || fail "quote context record should exist"
[[ "$(echo "$json_set" | jq -r '.data.quote_context.segments | length')" == "3" ]] || fail "three governed segments should persist"
[[ "$(echo "$json_set" | jq -r '.data.quote_context.relationship.volume_expectation')" == "expected_volume" ]] || fail "volume expectation should persist"
[[ "$(echo "$json_set" | jq -r '.data.quote_context.exception_rule.job_type')" == "memorial" ]] || fail "job type exception should persist"
[[ "$(echo "$json_set" | jq -r '.data.quote_context.exception_rule.pricing_override.unit_price_usd')" == "25.0" ]] || fail "flat-rate override should persist"

json_snapshot="$("$SNAPSHOT" --name 'Jonathan Lieberman' --json)"

[[ "$(echo "$json_snapshot" | jq -r '.quote_intelligence.customer_context_match.match_mode')" == "name_exact" ]] || fail "snapshot should resolve the quote context by name"
[[ "$(echo "$json_snapshot" | jq -r '.quote_intelligence.customer_context.segments[0].label')" == "middleman printer" ]] || fail "snapshot should surface segments"
[[ "$(echo "$json_snapshot" | jq -r '.quote_intelligence.customer_context.exception_rule.pricing_override.unit_price_usd')" == "25.0" ]] || fail "snapshot should surface pricing override"
[[ "$(echo "$json_snapshot" | jq -r '.quote_intelligence.terminology.replacement_phrase')" == "print-ready artwork (PNG or PDF)" ]] || fail "snapshot should surface house terminology"

pass "customer-quote-context-set persists governed quote context and customer-record-snapshot surfaces it"
