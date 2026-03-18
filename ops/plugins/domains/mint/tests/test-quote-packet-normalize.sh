#!/usr/bin/env bash
# test-quote-packet-normalize.sh - Fixture-driven runtime checks for quote_packet normalization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_PREPARE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-prepare"
QUOTE_SHOW="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-show"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-packet-normalize"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
INDEX_FILE="$TMP_ROOT/quote-packets-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"

run_fixture() {
  local fixture_name="$1"
  local output
  output="$(
    MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
    MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
    MINT_QUOTE_PACKET_CAPABILITY_NAME="mint.quote.packet.normalize" \
    "$QUOTE_PREPARE" \
      --evidence-file "$FIXTURES_DIR/$fixture_name" \
      --skip-customer-resolve
  )"
  echo "$output"
}

packet_id_from_output() {
  awk '/^quote_packet_id:/ {print $2}' <<<"$1"
}

packet_file_from_output() {
  awk '/^packet_file:/ {print $2}' <<<"$1"
}

section "Kennedy fixture"
kennedy_output="$(run_fixture "kennedy.evidence.yaml")"
kennedy_packet_id="$(packet_id_from_output "$kennedy_output")"
kennedy_packet_file="$(packet_file_from_output "$kennedy_output")"
[[ -n "$kennedy_packet_id" ]] || fail "Kennedy fixture did not emit quote_packet_id"
[[ -f "$kennedy_packet_file" ]] || fail "Kennedy packet file missing"
[[ "$(yq '.state' "$kennedy_packet_file")" == "needs_input" ]] || fail "Kennedy state must be needs_input"
[[ "$(yq '.line_items | length' "$kennedy_packet_file")" == "1" ]] || fail "Kennedy must normalize one concrete line item"
[[ "$(yq '.line_items[0].quantity' "$kennedy_packet_file")" == "20" ]] || fail "Kennedy quantity must remain 20"
[[ "$(yq '.open_gaps | map(select(.gap_type == "supplier_unresolved")) | length' "$kennedy_packet_file")" == "1" ]] || fail "Kennedy must carry supplier_unresolved"
[[ "$(yq '.open_gaps | map(select(.gap_type == "artwork_inadequate")) | length' "$kennedy_packet_file")" == "1" ]] || fail "Kennedy must carry artwork_inadequate"
[[ "$(yq '.open_gaps | map(select(.gap_type == "clarification_required" and .severity == "warning")) | length' "$kennedy_packet_file")" == "1" ]] || fail "Kennedy clarification gap must be warning severity"
[[ "$(yq '.quote_readiness.state' "$kennedy_packet_file")" == "needs_customer_input" ]] || fail "Kennedy must surface quote readiness directly on the packet"
[[ "$(yq '.quote_readiness.missing_for_build[] | select(.code == "blank_source") | .code' "$kennedy_packet_file")" == "blank_source" ]] || fail "Kennedy build blockers should include blank_source"
[[ "$(yq '.quote_readiness.missing_for_send[] | select(.code == "customer_identity") | .code' "$kennedy_packet_file")" == "customer_identity" ]] || fail "Kennedy send blockers should include unresolved customer identity"
pass "Kennedy fixture normalizes into a governed packet with honest blockers"

section "Kennedy idempotent update"
kennedy_line_item_id_before="$(yq -r '.line_items[0].line_item_id' "$kennedy_packet_file")"
kennedy_rerun_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$INDEX_FILE" \
  MINT_QUOTE_PACKET_CAPABILITY_NAME="mint.quote.packet.normalize" \
  "$QUOTE_PREPARE" \
    --packet-id "$kennedy_packet_id" \
    --evidence-file "$FIXTURES_DIR/kennedy.evidence.yaml" \
    --skip-customer-resolve
)"
[[ "$(packet_id_from_output "$kennedy_rerun_output")" == "$kennedy_packet_id" ]] || fail "Kennedy rerun must reuse the packet id"
[[ "$(yq '.line_items | length' "$kennedy_packet_file")" == "1" ]] || fail "Kennedy rerun must not duplicate line items"
[[ "$(yq -r '.line_items[0].line_item_id' "$kennedy_packet_file")" == "$kennedy_line_item_id_before" ]] || fail "Kennedy rerun must preserve the existing line_item_id"
pass "quote-prepare merges repeated evidence into the existing line item instead of duplicating packet work"

section "Lisa Peirce fixture"
lisa_output="$(run_fixture "lisa-peirce.evidence.yaml")"
lisa_packet_file="$(packet_file_from_output "$lisa_output")"
[[ -f "$lisa_packet_file" ]] || fail "Lisa packet file missing"
[[ "$(yq '.state' "$lisa_packet_file")" == "needs_input" ]] || fail "Lisa state must be needs_input"
[[ "$(yq '.line_items | length' "$lisa_packet_file")" == "5" ]] || fail "Lisa must normalize five line item candidates"
[[ "$(yq '.confidence.artwork_confidence' "$lisa_packet_file")" == "medium" ]] || fail "Lisa artwork confidence must be medium"
[[ "$(yq '.open_gaps | map(select(.gap_type == "product_unresolved")) | length' "$lisa_packet_file")" -ge "1" ]] || fail "Lisa must carry product_unresolved"
[[ "$(yq '.open_gaps | map(select(.gap_type == "clarification_required")) | length' "$lisa_packet_file")" -ge "1" ]] || fail "Lisa must carry clarification_required"
[[ "$(yq '.open_gaps | map(select(.gap_type == "decoration_unresolved")) | length' "$lisa_packet_file")" -ge "1" ]] || fail "Lisa must carry decoration_unresolved"
pass "Lisa fixture preserves multi-revision ambiguity instead of flattening it"

section "Moe fixture"
moe_output="$(run_fixture "moe-humble-religion.evidence.yaml")"
moe_packet_id="$(packet_id_from_output "$moe_output")"
moe_packet_file="$(packet_file_from_output "$moe_output")"
[[ -f "$moe_packet_file" ]] || fail "Moe packet file missing"
[[ "$(yq '.state' "$moe_packet_file")" == "needs_input" ]] || fail "Moe state must be needs_input"
[[ "$(yq '.line_items | length' "$moe_packet_file")" == "1" ]] || fail "Moe must normalize one translated line item candidate"
[[ "$(yq '.open_gaps | map(select(.gap_type == "quantity_unresolved")) | length' "$moe_packet_file")" == "1" ]] || fail "Moe must carry quantity_unresolved"
[[ "$(yq '.open_gaps | map(select(.gap_type == "shipping_ambiguity")) | length' "$moe_packet_file")" == "1" ]] || fail "Moe must carry shipping_ambiguity"
[[ "$(yq '.open_gaps | map(select(.gap_type == "pricing_policy_review" and .severity == "warning")) | length' "$moe_packet_file")" == "1" ]] || fail "Moe must carry warning-level pricing_policy_review"
[[ "$(yq '.open_gaps | map(select(.gap_type == "decoration_unresolved")) | length' "$moe_packet_file")" == "0" ]] || fail "Moe should not invent a decoration blocker when translation is still pre-pricing"
pass "Moe fixture preserves VIP shorthand as low-confidence packet truth"

section "Phuse greeting fixture"
phuse_output="$(run_fixture "phuse-cream.evidence.yaml")"
phuse_packet_file="$(packet_file_from_output "$phuse_output")"
[[ -f "$phuse_packet_file" ]] || fail "Phuse packet file missing"
[[ "$(yq '.customer_ref.resolved_name' "$phuse_packet_file")" == "Phuse Cream" ]] || fail "Phuse packet should preserve the company alias as resolved_name"
[[ "$(yq '.customer_ref.greeting_name' "$phuse_packet_file")" == "Catherine" ]] || fail "Phuse packet should carry the human greeting name separately from the company alias"
grep -Fq "Hi Catherine," "$phuse_packet_file" || fail "customer_message_draft should greet the human contact, not the company alias"
pass "Phuse fixture preserves a stable human greeting name from quoted-thread evidence"

section "Read surface"
show_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_SHOW" "$moe_packet_id"
)"
grep -Fq "quote_packet:" <<<"$show_output" || fail "quote-show must emit quote_packet header"
grep -Fq "Go Shimmy concert merch ribbed tank candidate" <<<"$show_output" || fail "quote-show must render persisted packet content"
pass "quote-show reads normalized packets from the governed storage surface"

section "Summary"
echo "Fixture-driven quote_packet normalization checks passed"
