#!/usr/bin/env bash
# aof-tenant-show — Show tenant profile summary.
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
  echo "Usage: aof-tenant-show.sh [--json]" >&2
  exit 1
fi

PROFILE="${SPINE_TENANT_PROFILE:-$SP/ops/bindings/tenant.profile.yaml}"
FIXTURE="$SP/fixtures/tenant.sample.yaml"
profile_mode="missing"
profile_source=""

# Try bound profile first, fall back to fixture
if [[ -f "$PROFILE" ]]; then
  profile_mode="bound"
  profile_source="$PROFILE"
elif [[ -f "$FIXTURE" ]]; then
  PROFILE="$FIXTURE"
  profile_mode="sample"
  profile_source="$FIXTURE"
fi

tenant_id=""
owner=""
display=""
provider=""
preset=""
spine_root=""
declare -a agents=()
if [[ "$profile_mode" != "missing" ]]; then
  tenant_id="$(yq -r '.identity.tenant_id // ""' "$PROFILE" 2>/dev/null || true)"
  owner="$(yq -r '.identity.owner // ""' "$PROFILE" 2>/dev/null || true)"
  display="$(yq -r '.identity.display_name // ""' "$PROFILE" 2>/dev/null || true)"
  provider="$(yq -r '.secrets.provider // ""' "$PROFILE" 2>/dev/null || true)"
  preset="$(yq -r '.policy.preset // ""' "$PROFILE" 2>/dev/null || true)"
  spine_root="$(yq -r '.runtime.spine_root // ""' "$PROFILE" 2>/dev/null || true)"
  mapfile -t agents < <(yq -r '.surfaces.agents[]?' "$PROFILE" 2>/dev/null || true)
fi

if [[ "$JSON_MODE" -eq 1 ]]; then
  agents_json="$(printf '%s\n' "${agents[@]-}" | jq -R . | jq -s 'map(select(length > 0))')"
  status="ok"
  [[ "$profile_mode" == "missing" ]] && status="missing"

  jq -n \
    --arg capability "aof.tenant.show" \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg generated_at "$GENERATED_AT" \
    --arg status "$status" \
    --arg mode "$profile_mode" \
    --arg source "$profile_source" \
    --arg tenant_id "$tenant_id" \
    --arg owner "$owner" \
    --arg display "$display" \
    --arg provider "$provider" \
    --arg preset "$preset" \
    --arg spine_root "$spine_root" \
    --argjson agents "$agents_json" \
    '{
      capability: $capability,
      schema_version: $schema_version,
      generated_at: $generated_at,
      status: $status,
      data: {
        source: {
          mode: $mode,
          path: (if $source == "" then null else $source end)
        },
        identity: {
          tenant_id: (if $tenant_id == "" then null else $tenant_id end),
          owner: (if $owner == "" then null else $owner end),
          display_name: (if $display == "" then null else $display end)
        },
        secrets: {
          provider: (if $provider == "" then null else $provider end)
        },
        policy: {
          preset: (if $preset == "" then null else $preset end)
        },
        runtime: {
          spine_root: (if $spine_root == "" then null else $spine_root end)
        },
        surfaces: {
          agents: $agents
        }
      }
    }'
  exit 0
fi

echo "═══════════════════════════════════════"
echo "  AOF TENANT PROFILE"
echo "═══════════════════════════════════════"
echo ""

if [[ "$profile_mode" == "bound" ]]; then
  echo "Source: $profile_source (bound)"
elif [[ "$profile_mode" == "sample" ]]; then
  echo "Source: $profile_source (sample — no bound profile)"
else
  echo "No tenant profile found."
  echo ""
  echo "To create one:"
  echo "  cp fixtures/tenant.sample.yaml ops/bindings/tenant.profile.yaml"
  echo "  # Edit to match your environment"
  echo "  ./bin/ops cap run tenant.profile.validate --profile ops/bindings/tenant.profile.yaml"
  exit 0
fi
echo ""

# ── Identity ──
echo "Identity:"
echo "  Tenant ID:    ${tenant_id:-unset}"
echo "  Owner:        ${owner:-unset}"
echo "  Display Name: ${display:-unset}"

# ── Secrets ──
echo ""
echo "Secrets:"
echo "  Provider: ${provider:-unset}"

# ── Policy ──
echo ""
echo "Policy:"
echo "  Preset: ${preset:-unset}"

# ── Runtime ──
echo ""
echo "Runtime:"
echo "  Spine root: ${spine_root:-unset}"

# ── Surfaces ──
echo ""
echo "Surfaces:"
agents_csv="$(printf '%s, ' "${agents[@]-}" | sed 's/, $//')"
echo "  Agents: ${agents_csv:-none}"

echo ""
echo "═══════════════════════════════════════"
