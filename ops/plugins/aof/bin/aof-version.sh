#!/usr/bin/env bash
# aof-version — AOF version and contract info.
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"

echo "═══════════════════════════════════════"
echo "  AOF VERSION"
echo "═══════════════════════════════════════"
echo ""

# ── Git version ──
git_sha="$(git -C "$SP" rev-parse --short HEAD 2>/dev/null || echo unknown)"
git_branch="$(git -C "$SP" branch --show-current 2>/dev/null || echo unknown)"
echo "Commit:   $git_sha ($git_branch)"

# ── Product contract ──
contract="$SP/docs/product/AOF_PRODUCT_CONTRACT.md"
if [[ -f "$contract" ]]; then
  last_verified="$(grep -m1 'last_verified:' "$contract" 2>/dev/null | sed 's/.*: *//' || echo unknown)"
  scope="$(grep -m1 'scope:' "$contract" 2>/dev/null | sed 's/.*: *//' || echo unknown)"
  echo "Contract: present (scope=$scope, verified=$last_verified)"
else
  echo "Contract: NOT FOUND"
fi

# ── Schema version ──
schema="$SP/ops/bindings/tenant.profile.schema.yaml"
if [[ -f "$schema" ]]; then
  echo "Schema:   present (tenant.profile.schema.yaml)"
else
  echo "Schema:   NOT FOUND"
fi

# ── Policy presets ──
presets="$SP/ops/bindings/policy.presets.yaml"
if [[ -f "$presets" ]]; then
  preset_list="$(yq -r '.presets | keys | .[]' "$presets" 2>/dev/null | tr '\n' ', ' | sed 's/,$//' || echo unknown)"
  echo "Presets:  $preset_list"
else
  echo "Presets:  NOT FOUND"
fi

# ── Drift gate version ──
gate_ver="$(grep -m1 'DRIFT GATE' "$SP/surfaces/verify/drift-gate.sh" 2>/dev/null | sed 's/.*(//' | sed 's/).*//' || echo unknown)"
echo "Gates:    $gate_ver"

# ── AOF plugin caps ──
aof_caps="$(grep '^  aof\.' "$SP/ops/capabilities.yaml" 2>/dev/null | sed 's/:.*//' | tr -d ' ' | tr '\n' ', ' | sed 's/,$//' || echo none)"
echo "AOF caps: $aof_caps"

echo ""
echo "═══════════════════════════════════════"
