#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
CAPTURE="$ROOT/ops/plugins/domains/mint/bin/customer-thread-delta-capture"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -x "$CAPTURE" ]] || fail "missing capture script"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_STATE="$tmp/state"

json_out="$("$CAPTURE" \
  --thread-id "team@mintprints.com::TowMaxx Towing shirts::2026-03-11" \
  --customer-ask "Customer wants a black reorder using the prior shirt design with updated size counts." \
  --morpheus-produced "Inbox triage summary plus prior-thread context." \
  --ronny-did "Stayed in Printavo and manually reconstructed the reorder from the historical order." \
  --ronny-disliked "No structured reorder capture for prior-order reference plus changed quantities/color." \
  --classification form \
  --severity medium \
  --confidence high \
  --next-action "Add a governed reorder delta form keyed by prior order reference for repeat jobs." \
  --evidence-ref "/tmp/example-receipt.md" \
  --json)"

delta_id="$(echo "$json_out" | jq -r '.data.delta_id // ""')"
record_file="$(echo "$json_out" | jq -r '.data.record_file // ""')"
index_file="$(echo "$json_out" | jq -r '.data.index_file // ""')"
classification="$(echo "$json_out" | jq -r '.data.classification // ""')"
classification_label="$(echo "$json_out" | jq -r '.data.classification_label // ""')"

[[ -n "$delta_id" ]] || fail "delta_id should be populated"
[[ -n "$record_file" && -f "$record_file" ]] || fail "record_file should exist"
[[ -n "$index_file" && -f "$index_file" ]] || fail "index_file should exist"
[[ "$classification" == "form_gap" ]] || fail "classification should normalize to form_gap"
[[ "$classification_label" == "form gap" ]] || fail "classification label should be form gap"
[[ "$(yq e -r '.thread_customer_identifier // ""' "$record_file")" == "team@mintprints.com::TowMaxx Towing shirts::2026-03-11" ]] || fail "record should persist thread identifier"
[[ "$(yq e -r '.classification // ""' "$record_file")" == "form_gap" ]] || fail "record should persist canonical classification"
[[ "$(yq e -r '.classification_label // ""' "$record_file")" == "form gap" ]] || fail "record should persist classification label"
[[ "$(yq e -r '.evidence_refs[0] // ""' "$record_file")" == "/tmp/example-receipt.md" ]] || fail "record should persist evidence refs"
grep -F "\"delta_id\":\"$delta_id\"" "$index_file" >/dev/null || fail "index should include delta id"
grep -F "\"classification\":\"form_gap\"" "$index_file" >/dev/null || fail "index should include canonical classification"
pass "customer-thread-delta-capture persists record and index"
