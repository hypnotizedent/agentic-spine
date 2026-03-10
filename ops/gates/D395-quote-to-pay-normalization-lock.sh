#!/usr/bin/env bash
# TRIAGE: D395 Quote-to-Pay Normalization Lock
# Ring: standard
# Description: Enforces quote line item normalization contract and payment bridge authority
# Pack: mint
# Status: active

set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT"

NORMALIZATION_CONTRACT="ops/bindings/mint.quote.line_item.normalization.contract.yaml"
PAYMENT_BRIDGE="ops/bindings/mint.quote.payment_bridge.authority.yaml"
QUOTE_PACKET_AUTHORITY="ops/bindings/mint.quote.packet.authority.yaml"
MINT_AGENT_CONTRACT="ops/agents/mint-agent.contract.md"
CAPABILITIES="ops/capabilities.yaml"
CAPABILITY_MAP="ops/bindings/capability_map.yaml"
QUOTE_PREPARE_BIN="ops/plugins/mint/bin/quote-prepare"
QUOTE_PACKET_NORMALIZER="ops/plugins/mint/lib/quote_packet_normalize.py"
QUOTE_SOURCE_BIN="ops/plugins/mint/bin/quote-source"
QUOTE_PACKET_SOURCER="ops/plugins/mint/lib/quote_packet_source.py"
QUOTE_PRICE_BIN="ops/plugins/mint/bin/quote-price"
QUOTE_PACKET_PRICER="ops/plugins/mint/lib/quote_packet_price.py"
QUOTE_RENDER_BIN="ops/plugins/mint/bin/quote-render"
QUOTE_PACKET_RENDERER="ops/plugins/mint/lib/quote_packet_render.py"

fail() {
  echo "FAIL D395: $*" >&2
  exit 1
}

pass() {
  echo "PASS D395: $*"
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "Missing $file"
  CHECKS=$((CHECKS + 1))
}

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"
  grep -Fq "$needle" "$file" || fail "$message"
  CHECKS=$((CHECKS + 1))
}

require_yq_item() {
  local expr="$1"
  local expected="$2"
  local file="$3"
  local message="$4"
  local values
  values="$(yq e "$expr" "$file" 2>/dev/null || true)"
  grep -Fxq "$expected" <<<"$values" || fail "$message"
  CHECKS=$((CHECKS + 1))
}

forbid_yq_item() {
  local expr="$1"
  local forbidden="$2"
  local file="$3"
  local message="$4"
  local values
  values="$(yq e "$expr" "$file" 2>/dev/null || true)"
  if grep -Fxq "$forbidden" <<<"$values"; then
    fail "$message"
  fi
  CHECKS=$((CHECKS + 1))
}

require_yq_value() {
  local expr="$1"
  local file="$2"
  local message="$3"
  local value
  value="$(yq e "$expr // \"__missing__\"" "$file" 2>/dev/null || true)"
  [[ -n "$value" && "$value" != "__missing__" && "$value" != "null" ]] || fail "$message"
  CHECKS=$((CHECKS + 1))
}

CHECKS=0
command -v yq >/dev/null 2>&1 || fail "yq is required"

# Core authority files must exist.
require_file "$NORMALIZATION_CONTRACT"
require_file "$PAYMENT_BRIDGE"
require_file "$QUOTE_PACKET_AUTHORITY"
require_file "$MINT_AGENT_CONTRACT"
require_file "$CAPABILITIES"
require_file "$CAPABILITY_MAP"
require_file "$QUOTE_PREPARE_BIN"
require_file "$QUOTE_PACKET_NORMALIZER"
require_file "$QUOTE_SOURCE_BIN"
require_file "$QUOTE_PACKET_SOURCER"
require_file "$QUOTE_PRICE_BIN"
require_file "$QUOTE_PACKET_PRICER"
require_file "$QUOTE_RENDER_BIN"
require_file "$QUOTE_PACKET_RENDERER"

# Quote packet authority must point at the canonical contract surfaces.
require_fixed "mint.quote.line_item.normalization.contract.yaml" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must reference line_item.normalization.contract.yaml"
require_fixed "mint.quote.payment_bridge.authority.yaml" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must reference payment_bridge.authority.yaml"

# Line-item normalization must preserve the canonical completeness progression.
for class in creation_minimum stock_lookup_ready pricing_ready quote_ready; do
  require_fixed "$class:" "$NORMALIZATION_CONTRACT" "Missing completeness class: $class"
done
require_fixed "line_item_id:" "$NORMALIZATION_CONTRACT" "Normalization contract must use canonical line_item_id"
if grep -Eq '^[[:space:]]*line_id:' "$NORMALIZATION_CONTRACT"; then
  fail "Normalization contract must not introduce alternate line_id identity"
fi
CHECKS=$((CHECKS + 1))
require_yq_item '.completeness_classes.creation_minimum.required_fields[]' 'line_item_id' "$NORMALIZATION_CONTRACT" "creation_minimum must require line_item_id"
require_yq_item '.completeness_classes.creation_minimum.required_fields[]' 'product_type' "$NORMALIZATION_CONTRACT" "creation_minimum must require product_type"
forbid_yq_item '.completeness_classes.creation_minimum.required_fields[]' 'quantity' "$NORMALIZATION_CONTRACT" "creation_minimum must not require quantity"
require_yq_item '.completeness_classes.stock_lookup_ready.required_fields[]' 'quantity' "$NORMALIZATION_CONTRACT" "stock_lookup_ready must require quantity"
require_yq_item '.completeness_classes.pricing_ready.required_fields[]' 'quantity' "$NORMALIZATION_CONTRACT" "pricing_ready must require quantity"
require_yq_item '.pricing_inputs[]' 'method_variant' "$NORMALIZATION_CONTRACT" "pricing_inputs must include method_variant"
require_yq_item '.pricing_inputs[]' 'underbase_needed' "$NORMALIZATION_CONTRACT" "pricing_inputs must include underbase_needed"
require_yq_item '.pricing_inputs[]' 'stitch_count' "$NORMALIZATION_CONTRACT" "pricing_inputs must include stitch_count"
require_yq_item '.pricing_inputs[]' 'puff_mode' "$NORMALIZATION_CONTRACT" "pricing_inputs must include puff_mode"
require_yq_item '.pricing_inputs[]' 'thread_type' "$NORMALIZATION_CONTRACT" "pricing_inputs must include thread_type"
require_yq_item '.pricing_inputs[]' 'hoop_class' "$NORMALIZATION_CONTRACT" "pricing_inputs must include hoop_class"
require_yq_item '.pricing_inputs[]' 'material_class' "$NORMALIZATION_CONTRACT" "pricing_inputs must include material_class"
require_yq_item '.pricing_inputs[]' 'transfer_type' "$NORMALIZATION_CONTRACT" "pricing_inputs must include transfer_type"
require_yq_item '.pricing_inputs[]' 'artwork_fingerprint_sha256' "$NORMALIZATION_CONTRACT" "pricing_inputs must include artwork_fingerprint_sha256"
require_yq_item '.pricing_inputs[]' 'garment_family' "$NORMALIZATION_CONTRACT" "pricing_inputs must include garment_family"

# Module mappings and payment bridge guardrails must remain present.
require_fixed "module_field_mapping:" "$NORMALIZATION_CONTRACT" "Missing module_field_mapping"
require_fixed "suppliers_stock:" "$NORMALIZATION_CONTRACT" "Missing suppliers_stock mapping"
require_fixed "pricing_job_estimator:" "$NORMALIZATION_CONTRACT" "Missing pricing_job_estimator mapping"
require_fixed "no_line_id:" "$NORMALIZATION_CONTRACT" "Missing no_line_id alias guard"
require_fixed "promotion_boundary:" "$PAYMENT_BRIDGE" "Missing promotion_boundary"
require_fixed "no_fake_order_id:" "$PAYMENT_BRIDGE" "Payment bridge must forbid fake order_id"

# Quote packet authority must carry the Morpheus intake normalization surface.
require_yq_value '.quote_packet_schema.optional_fields.operator_notes.type' "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must define operator_notes"
require_yq_item '.quote_packet_schema.required_fields.source_refs.elements[]' 'ref_type (optional: seed|quote_form|email|attachment|pdf|product_link|historical_quote|historical_invoice|operator_note)' "$QUOTE_PACKET_AUTHORITY" "source_refs must define ref_type"
require_yq_item '.quote_packet_schema.required_fields.source_refs.elements[]' 'source_locator (optional: path, URL, message-id, or external identifier)' "$QUOTE_PACKET_AUTHORITY" "source_refs must define source_locator"
require_yq_item '.quote_packet_schema.required_fields.source_refs.elements[]' 'summary (optional: one-line statement of what this evidence contributes)' "$QUOTE_PACKET_AUTHORITY" "source_refs must define summary"
require_yq_item '.quote_packet_schema.required_fields.source_refs.elements[]' 'artifact_state (optional: received|derived|missing|failed|low_quality)' "$QUOTE_PACKET_AUTHORITY" "source_refs must define artifact_state"
for section in morpheus_intake_normalization messy_input_patterns confidence_scoring_rules clarification_rules artie_routing_rules pricing_progression_rules ready_for_review_rules normalization_examples; do
  require_fixed "$section:" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority missing $section"
done
require_fixed "shipping_ambiguity" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must govern shipping_ambiguity gaps"
require_fixed "clarification_required" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must govern clarification_required gaps"
require_fixed "proof_routing_blocked" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must govern proof_routing_blocked gaps"
require_fixed "implementation_status: REAL (review boundary operational; payment remains downstream of promotion)" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must keep mint.quote.render as a real review boundary"
require_fixed "name: mint.quote.packet.source" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must define mint.quote.packet.source"
require_fixed "packet-driven call path to suppliers search + stock" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must describe real packet-driven supplier sourcing"
require_fixed "name: mint.quote.packet.price" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must define mint.quote.packet.price"
require_fixed "packet-driven call path to the live pricing estimator" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must describe real packet-driven pricing"
require_fixed "updated state (ready_for_review when packet meets authority conditions; approved_to_send preserved if already approved)" "$QUOTE_PACKET_AUTHORITY" "Quote packet authority must allow ready_for_review before payment generation"
if grep -Fq "updated state (needs_input if payment blocked, NOT ready_for_review)" "$QUOTE_PACKET_AUTHORITY"; then
  fail "Quote packet authority must not force render back to needs_input just because payment is downstream"
fi
CHECKS=$((CHECKS + 1))

# Runtime surface must stay pinned to the governed quote_packet normalizer.
require_fixed "quote_packet_normalize.py" "$QUOTE_PREPARE_BIN" "quote-prepare must delegate to the governed quote_packet normalizer"
require_fixed "quote_packet_source.py" "$QUOTE_SOURCE_BIN" "quote-source must delegate to the governed quote_packet sourcer"
require_fixed "quote_packet_price.py" "$QUOTE_PRICE_BIN" "quote-price must delegate to the governed quote_packet pricer"
require_fixed "quote_packet_render.py" "$QUOTE_RENDER_BIN" "quote-render must delegate to the governed quote_packet renderer"
require_fixed "mint.quote.packet.normalize:" "$CAPABILITIES" "Capabilities must register mint.quote.packet.normalize"
require_fixed "mint.quote.packet.show:" "$CAPABILITIES" "Capabilities must register mint.quote.packet.show"
require_fixed "mint.quote.packet.source:" "$CAPABILITIES" "Capabilities must register mint.quote.packet.source"
require_fixed "mint.quote.packet.price:" "$CAPABILITIES" "Capabilities must register mint.quote.packet.price"
require_fixed "mint.quote.packet.normalize:" "$CAPABILITY_MAP" "Capability map must register mint.quote.packet.normalize"
require_fixed "mint.quote.packet.show:" "$CAPABILITY_MAP" "Capability map must register mint.quote.packet.show"
require_fixed "mint.quote.packet.source:" "$CAPABILITY_MAP" "Capability map must register mint.quote.packet.source"
require_fixed "mint.quote.packet.price:" "$CAPABILITY_MAP" "Capability map must register mint.quote.packet.price"

# Morpheus contract must stay aligned with the normalization and routing rules.
require_fixed "mint.quote.packet.authority.yaml" "$MINT_AGENT_CONTRACT" "Mint agent must reference quote packet authority"
require_fixed "mint.quote.line_item.normalization.contract.yaml" "$MINT_AGENT_CONTRACT" "Mint agent must reference normalization contract"
require_fixed "mint.quote.payment_bridge.authority.yaml" "$MINT_AGENT_CONTRACT" "Mint agent must reference payment bridge"
require_fixed '| `mint.quote.packet.normalize` | mutating |' "$MINT_AGENT_CONTRACT" "Mint agent must describe mint.quote.packet.normalize as mutating"
require_fixed '| `mint.quote.packet.show` | read-only |' "$MINT_AGENT_CONTRACT" "Mint agent must describe mint.quote.packet.show as read-only"
require_fixed '| `mint.quote.packet.source` | mutating |' "$MINT_AGENT_CONTRACT" "Mint agent must describe mint.quote.packet.source as mutating"
require_fixed '| `mint.quote.packet.price` | mutating |' "$MINT_AGENT_CONTRACT" "Mint agent must describe mint.quote.packet.price as mutating"
require_fixed 'Calls suppliers search to choose a canonical blank candidate' "$MINT_AGENT_CONTRACT" "Mint agent must document governed supplier sourcing"
require_fixed '| `mint.quote.render` | mutating |' "$MINT_AGENT_CONTRACT" "Mint agent must describe mint.quote.render as mutating"
require_fixed 'Consumes only the persisted `quote_packet` state and canonical `line_items`' "$MINT_AGENT_CONTRACT" "Mint agent must document packet-only pricing input"
require_fixed 'Sets `ready_for_review` when the packet meets authority rules, even though payment remains downstream' "$MINT_AGENT_CONTRACT" "Mint agent must document render readiness before payment generation"
require_fixed "Do not invent quantity, decoration method, or supplier truth" "$MINT_AGENT_CONTRACT" "Mint agent must forbid invented quote facts"
require_fixed "**Artie Routing Guidance:**" "$MINT_AGENT_CONTRACT" "Mint agent must document Artie routing guidance"

pass "$CHECKS normalization checks passed"
