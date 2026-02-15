#!/usr/bin/env bash
# aof-tenant-show — Show tenant profile summary.
set -euo pipefail

SP="${SPINE_ROOT:-${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)}}"

echo "═══════════════════════════════════════"
echo "  AOF TENANT PROFILE"
echo "═══════════════════════════════════════"
echo ""

PROFILE="${SPINE_TENANT_PROFILE:-$SP/ops/bindings/tenant.profile.yaml}"
FIXTURE="$SP/fixtures/tenant.sample.yaml"

# Try bound profile first, fall back to fixture
if [[ -f "$PROFILE" ]]; then
  echo "Source: $PROFILE (bound)"
elif [[ -f "$FIXTURE" ]]; then
  PROFILE="$FIXTURE"
  echo "Source: $FIXTURE (sample — no bound profile)"
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
tenant_id="$(yq -r '.identity.tenant_id // "unset"' "$PROFILE" 2>/dev/null || echo unset)"
owner="$(yq -r '.identity.owner // "unset"' "$PROFILE" 2>/dev/null || echo unset)"
display="$(yq -r '.identity.display_name // "unset"' "$PROFILE" 2>/dev/null || echo unset)"
echo "Identity:"
echo "  Tenant ID:    $tenant_id"
echo "  Owner:        $owner"
echo "  Display Name: $display"

# ── Secrets ──
provider="$(yq -r '.secrets.provider // "unset"' "$PROFILE" 2>/dev/null || echo unset)"
echo ""
echo "Secrets:"
echo "  Provider: $provider"

# ── Policy ──
preset="$(yq -r '.policy.preset // "unset"' "$PROFILE" 2>/dev/null || echo unset)"
echo ""
echo "Policy:"
echo "  Preset: $preset"

# ── Runtime ──
spine_root="$(yq -r '.runtime.spine_root // "unset"' "$PROFILE" 2>/dev/null || echo unset)"
echo ""
echo "Runtime:"
echo "  Spine root: $spine_root"

# ── Surfaces ──
echo ""
echo "Surfaces:"
agents="$(yq -r '.surfaces.agents[]?' "$PROFILE" 2>/dev/null | tr '\n' ', ' | sed 's/,$//' || echo none)"
echo "  Agents: $agents"

echo ""
echo "═══════════════════════════════════════"
