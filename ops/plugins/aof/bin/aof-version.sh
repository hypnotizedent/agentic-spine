#!/usr/bin/env bash
# aof-version — AOF version and contract info.
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"
SCHEMA_VERSION="1.1.0"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
JSON_MODE=0

if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=1
  shift
fi

if [[ "$#" -gt 0 ]]; then
  echo "Usage: aof-version.sh [--json]" >&2
  exit 1
fi

git_sha="$(git -C "$SP" rev-parse --short HEAD 2>/dev/null || echo unknown)"
git_branch="$(git -C "$SP" branch --show-current 2>/dev/null || echo unknown)"

contract="$SP/docs/product/AOF_PRODUCT_CONTRACT.md"
contract_present=false
contract_last_verified=""
contract_scope=""
if [[ -f "$contract" ]]; then
  contract_present=true
  contract_last_verified="$(grep -m1 'last_verified:' "$contract" 2>/dev/null | sed 's/.*: *//' || true)"
  contract_scope="$(grep -m1 'scope:' "$contract" 2>/dev/null | sed 's/.*: *//' || true)"
fi

schema="$SP/ops/bindings/tenant.profile.schema.yaml"
schema_present=false
if [[ -f "$schema" ]]; then
  schema_present=true
fi

presets="$SP/ops/bindings/policy.presets.yaml"
presets_present=false
declare -a preset_array=()
if [[ -f "$presets" ]]; then
  presets_present=true
  mapfile -t preset_array < <(yq -r '.presets | keys | .[]' "$presets" 2>/dev/null || true)
fi
preset_list_csv="$(printf '%s, ' "${preset_array[@]-}" | sed 's/, $//')"

gate_ver="$(grep -m1 'DRIFT GATE' "$SP/surfaces/verify/drift-gate.sh" 2>/dev/null | sed 's/.*(//' | sed 's/).*//' || echo unknown)"
mapfile -t aof_caps < <(grep '^  aof\.' "$SP/ops/capabilities.yaml" 2>/dev/null | sed 's/:.*//' | tr -d ' ' || true)
aof_caps_csv="$(printf '%s, ' "${aof_caps[@]-}" | sed 's/, $//')"

presets_json="$(printf '%s\n' "${preset_array[@]-}" | jq -R . | jq -s 'map(select(length > 0))')"
aof_caps_json="$(printf '%s\n' "${aof_caps[@]-}" | jq -R . | jq -s 'map(select(length > 0))')"

if [[ "$JSON_MODE" -eq 1 ]]; then
  jq -n \
    --arg capability "aof.version" \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg generated_at "$GENERATED_AT" \
    --arg status "ok" \
    --arg git_sha "$git_sha" \
    --arg git_branch "$git_branch" \
    --argjson contract_present "$contract_present" \
    --arg contract_path "$contract" \
    --arg contract_last_verified "$contract_last_verified" \
    --arg contract_scope "$contract_scope" \
    --argjson schema_present "$schema_present" \
    --arg schema_path "$schema" \
    --argjson presets_present "$presets_present" \
    --arg presets_path "$presets" \
    --arg gate_version "$gate_ver" \
    --argjson presets_list "$presets_json" \
    --argjson aof_caps "$aof_caps_json" \
    '{
      capability: $capability,
      schema_version: $schema_version,
      generated_at: $generated_at,
      status: $status,
      data: {
        git: {
          commit: $git_sha,
          branch: $git_branch
        },
        contract: {
          present: $contract_present,
          path: $contract_path,
          last_verified: (if $contract_last_verified == "" then null else $contract_last_verified end),
          scope: (if $contract_scope == "" then null else $contract_scope end)
        },
        schema: {
          present: $schema_present,
          path: $schema_path
        },
        presets: {
          present: $presets_present,
          path: $presets_path,
          list: $presets_list
        },
        gates: {
          drift_gate_version: $gate_version
        },
        capabilities: $aof_caps
      }
    }'
  exit 0
fi

echo "═══════════════════════════════════════"
echo "  AOF VERSION"
echo "═══════════════════════════════════════"
echo ""

# ── Git version ──
echo "Commit:   $git_sha ($git_branch)"

# ── Product contract ──
if [[ "$contract_present" == true ]]; then
  echo "Contract: present (scope=${contract_scope:-unknown}, verified=${contract_last_verified:-unknown})"
else
  echo "Contract: NOT FOUND"
fi

# ── Schema version ──
if [[ "$schema_present" == true ]]; then
  echo "Schema:   present (tenant.profile.schema.yaml)"
else
  echo "Schema:   NOT FOUND"
fi

# ── Policy presets ──
if [[ "$presets_present" == true ]]; then
  echo "Presets:  ${preset_list_csv:-unknown}"
else
  echo "Presets:  NOT FOUND"
fi

# ── Drift gate version ──
echo "Gates:    $gate_ver"

# ── AOF plugin caps ──
echo "AOF caps: ${aof_caps_csv:-none}"

echo ""
echo "═══════════════════════════════════════"
