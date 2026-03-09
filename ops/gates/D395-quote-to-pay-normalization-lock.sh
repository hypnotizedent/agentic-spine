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

# Check 1-2: Contract files exist
[[ -f "$NORMALIZATION_CONTRACT" ]] || { echo "FAIL: Missing $NORMALIZATION_CONTRACT"; exit 1; }
[[ -f "$PAYMENT_BRIDGE" ]] || { echo "FAIL: Missing $PAYMENT_BRIDGE"; exit 1; }

# Check 3-4: Quote packet authority references both new contracts
grep -q "mint.quote.line_item.normalization.contract.yaml" "$QUOTE_PACKET_AUTHORITY" || { echo "FAIL: Quote packet authority must reference line_item.normalization.contract.yaml"; exit 1; }
grep -q "mint.quote.payment_bridge.authority.yaml" "$QUOTE_PACKET_AUTHORITY" || { echo "FAIL: Quote packet authority must reference payment_bridge.authority.yaml"; exit 1; }

# Check 5: Completeness classes defined
for class in creation_minimum stock_lookup_ready pricing_ready quote_ready; do
  grep -q "$class:" "$NORMALIZATION_CONTRACT" || { echo "FAIL: Missing completeness class: $class"; exit 1; }
done

# Check 6: Canonical field identity must use line_item_id only
grep -q "line_item_id:" "$NORMALIZATION_CONTRACT" || { echo "FAIL: Normalization contract must use canonical line_item_id"; exit 1; }
grep -q "^[[:space:]]*line_id:" "$NORMALIZATION_CONTRACT" && { echo "FAIL: Normalization contract must not introduce alternate line_id identity"; exit 1; }

# Check 7-10: Module mappings, alias guardrails, and promotion boundary
grep -q "module_field_mapping:" "$NORMALIZATION_CONTRACT" || { echo "FAIL: Missing module_field_mapping"; exit 1; }
grep -q "suppliers_stock:" "$NORMALIZATION_CONTRACT" || { echo "FAIL: Missing suppliers_stock mapping"; exit 1; }
grep -q "pricing_job_estimator:" "$NORMALIZATION_CONTRACT" || { echo "FAIL: Missing pricing_job_estimator mapping"; exit 1; }
grep -q "no_line_id:" "$NORMALIZATION_CONTRACT" || { echo "FAIL: Missing no_line_id alias guard"; exit 1; }
grep -q "promotion_boundary:" "$PAYMENT_BRIDGE" || { echo "FAIL: Missing promotion_boundary"; exit 1; }

# Check 11: Payment bridge defines forbidden shortcuts
grep -q "no_fake_order_id:" "$PAYMENT_BRIDGE" || { echo "FAIL: Payment bridge must forbid fake order_id"; exit 1; }

# Check 12-14: Mint agent references authorities and keeps capability safety truthful
grep -q "mint.quote.line_item.normalization.contract.yaml" "$MINT_AGENT_CONTRACT" || { echo "FAIL: Mint agent must reference normalization contract"; exit 1; }
grep -q "mint.quote.payment_bridge.authority.yaml" "$MINT_AGENT_CONTRACT" || { echo "FAIL: Mint agent must reference payment bridge"; exit 1; }
grep -q '| `mint.quote.render` | mutating |' "$MINT_AGENT_CONTRACT" || { echo "FAIL: Mint agent must describe mint.quote.render as mutating"; exit 1; }

echo "PASS: All 14 Quote-to-Pay normalization checks passed"
