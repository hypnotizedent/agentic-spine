#!/usr/bin/env bash
# TRIAGE: Tailscale enrollment must prefer OAuth-scoped keys over static reusable auth keys.
# D313: Tailscale enrollment security lock.
# Ensures authority contract has enrollment section with oauth_preferred: true,
# OAuth credentials are in secrets namespace, and static key is documented as emergency only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTHORITY="$ROOT/docs/CANONICAL/TAILSCALE_AUTHORITY_CONTRACT_V1.yaml"
NAMESPACE_POLICY="$ROOT/ops/bindings/secrets.namespace.policy.yaml"

fail=0
err() { echo "D313 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { err "missing dependency: yq"; exit 1; }
[[ -f "$AUTHORITY" ]] || { err "authority contract missing: $AUTHORITY"; exit 1; }
[[ -f "$NAMESPACE_POLICY" ]] || { err "namespace policy missing: $NAMESPACE_POLICY"; exit 1; }

# 1) Authority contract must have enrollment section
enrollment_mode=$(yq -r '.enrollment.default_mode // ""' "$AUTHORITY" 2>/dev/null || true)
[[ -n "$enrollment_mode" && "$enrollment_mode" != "null" ]] || err "authority contract missing enrollment.default_mode"

# 2) OAuth must be preferred
oauth_pref=$(yq -r '.enrollment.oauth_preferred // ""' "$AUTHORITY" 2>/dev/null || true)
[[ "$oauth_pref" == "true" ]] || err "enrollment.oauth_preferred must be true"

# 3) Primary path must be oauth_scoped_enrollment
primary_name=$(yq -r '.enrollment.paths.primary.name // ""' "$AUTHORITY" 2>/dev/null || true)
[[ "$primary_name" == "oauth_scoped_enrollment" ]] || err "enrollment primary path must be oauth_scoped_enrollment, got: $primary_name"

# 4) Emergency fallback must exist and be named static_reusable_auth_key
fallback_name=$(yq -r '.enrollment.paths.emergency_fallback.name // ""' "$AUTHORITY" 2>/dev/null || true)
[[ "$fallback_name" == "static_reusable_auth_key" ]] || err "enrollment emergency_fallback must be named static_reusable_auth_key, got: $fallback_name"

# 5) OAuth credentials must be in secrets namespace
oauth_id_path=$(yq -r '.rules.required_key_paths.TAILSCALE_OAUTH_CLIENT_ID // ""' "$NAMESPACE_POLICY" 2>/dev/null || true)
oauth_secret_path=$(yq -r '.rules.required_key_paths.TAILSCALE_OAUTH_CLIENT_SECRET // ""' "$NAMESPACE_POLICY" 2>/dev/null || true)
[[ -n "$oauth_id_path" && "$oauth_id_path" != "null" ]] || err "TAILSCALE_OAUTH_CLIENT_ID missing from secrets namespace policy"
[[ -n "$oauth_secret_path" && "$oauth_secret_path" != "null" ]] || err "TAILSCALE_OAUTH_CLIENT_SECRET missing from secrets namespace policy"

# 6) API key and auth key must also be registered
api_key_path=$(yq -r '.rules.required_key_paths.TAILSCALE_API_KEY // ""' "$NAMESPACE_POLICY" 2>/dev/null || true)
auth_key_path=$(yq -r '.rules.required_key_paths.TAILSCALE_AUTH_KEY // ""' "$NAMESPACE_POLICY" 2>/dev/null || true)
[[ -n "$api_key_path" && "$api_key_path" != "null" ]] || err "TAILSCALE_API_KEY missing from secrets namespace policy"
[[ -n "$auth_key_path" && "$auth_key_path" != "null" ]] || err "TAILSCALE_AUTH_KEY missing from secrets namespace policy"

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D313 PASS: enrollment security valid (oauth_preferred=true, all credentials registered, fallback documented)"
