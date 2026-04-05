#!/usr/bin/env bash
# Test: extraction truth parity (domain + capability scope)
# Validates D428 enforcement for domains and domain=none capabilities

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../" && pwd)"
cd "$ROOT"

echo "TEST: extraction truth parity (domain + capability)"

# Test 1: D428 gate passes
echo "  - running D428 gate..."
d428_output=$("$ROOT/surfaces/verify/d428-extraction-truth-parity.sh" 2>&1 || true)
if ! echo "$d428_output" | grep -q "D428 PASS"; then
    echo "FAIL: D428 gate failed"
    echo "Output: $d428_output"
    exit 1
fi
echo "    PASS: D428 gate"

# Test 2: All domains have layer classification
echo "  - checking domain layer coverage..."
domain_count=$(yq '.domain_metadata | length' ops/bindings/gate.execution.topology.yaml)
domains_with_layer=$(yq '[.domain_metadata[] | select(.layer)] | length' ops/bindings/gate.execution.topology.yaml)
if [[ "$domain_count" != "$domains_with_layer" ]]; then
    echo "FAIL: $domain_count domains but only $domains_with_layer have layer"
    exit 1
fi
echo "    PASS: all $domain_count domains have layer"

# Test 3: domain=none capabilities have explicit layer
echo "  - checking domain=none capability layer coverage..."
none_caps=$(yq '[.capabilities[] | select(.domain == "none")] | length' ops/capabilities.yaml)
none_with_layer=$(yq '[.capabilities[] | select(.domain == "none" and .layer)] | length' ops/capabilities.yaml)
if [[ "$none_caps" != "$none_with_layer" ]]; then
    echo "FAIL: $none_caps domain=none capabilities but only $none_with_layer have layer"
    exit 1
fi
echo "    PASS: all $none_caps domain=none capabilities have layer"

# Test 4: non-domain-none capabilities do NOT have layer
echo "  - checking boundary enforcement (non-domain-none must not have layer)..."
leakage=$(yq '[.capabilities[] | select(.domain != "none" and .layer)] | length' ops/capabilities.yaml)
if [[ "$leakage" != "0" ]]; then
    echo "FAIL: $leakage non-domain-none capabilities have layer field (boundary violation)"
    exit 1
fi
echo "    PASS: no layer leakage to non-domain-none capabilities"

# Test 5: query tool works for domains and capabilities
echo "  - testing extraction-layer-query..."
if ! ops/plugins/core/verify/bin/extraction-layer-query --domain core | grep -q "layer=L1_engine"; then
    echo "FAIL: query tool failed for domain=core"
    exit 1
fi
if ! ops/plugins/core/verify/bin/extraction-layer-query --summary | grep -q "DOMAIN LAYER CLASSIFICATION"; then
    echo "FAIL: query tool --summary failed"
    exit 1
fi
echo "    PASS: query tool works"

echo "PASS: extraction truth parity (domain + capability)"
