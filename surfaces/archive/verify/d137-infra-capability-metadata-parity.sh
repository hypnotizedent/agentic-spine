#!/usr/bin/env bash
# TRIAGE: Add plane/domain/requires metadata to infra capabilities in ops/capabilities.yaml
# D137: Infra capabilities declare plane, domain, and requires metadata
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAPS="$ROOT/ops/capabilities.yaml"

ERRORS=0
err() { echo "  $*"; ERRORS=$((ERRORS + 1)); }

[[ -f "$CAPS" ]] || { err "capabilities.yaml not found"; echo "D137 FAIL: 1 check(s) failed"; exit 1; }
command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D137 FAIL: 1 check(s) failed"; exit 1; }

TARGET_CAPS=(
  "infra.proxmox.maintenance.precheck"
  "infra.proxmox.maintenance.shutdown"
  "infra.proxmox.maintenance.startup"
  "infra.post_power.recovery.status"
  "infra.post_power.recovery"
  "infra.maintenance.window"
  "infra.proxmox.node_path.migrate"
)

# Canonical infra-core adjacent prefixes. These must always declare both domain
# and plane to preserve routing/pack clarity.
PREFIX_REGEX='^(infra|caddy|auth|secrets|cloudflared|pihole|vaultwarden)\.'

for cap in "${TARGET_CAPS[@]}"; do
  cap_exists="$(yq e ".capabilities[\"$cap\"] | has(\"description\")" "$CAPS" 2>/dev/null || echo "false")"
  if [[ "$cap_exists" != "true" ]]; then
    err "Capability '$cap' not found in capabilities.yaml"
    continue
  fi

  plane="$(yq e ".capabilities[\"$cap\"].plane" "$CAPS" 2>/dev/null || echo "")"
  domain="$(yq e ".capabilities[\"$cap\"].domain" "$CAPS" 2>/dev/null || echo "")"
  requires="$(yq e ".capabilities[\"$cap\"].requires" "$CAPS" 2>/dev/null || echo "")"

  if [[ -z "$plane" || "$plane" == "null" ]]; then
    err "Capability '$cap' missing 'plane' field"
  elif [[ "$plane" != "fabric" ]]; then
    err "Capability '$cap' plane='$plane' (expected 'fabric')"
  fi

  if [[ -z "$domain" || "$domain" == "null" ]]; then
    err "Capability '$cap' missing 'domain' field"
  elif [[ "$domain" != "infra" ]]; then
    err "Capability '$cap' domain='$domain' (expected 'infra')"
  fi

  # requires is optional for node_path.migrate (already had it), but should exist for others
  if [[ "$cap" != "infra.proxmox.node_path.migrate" ]]; then
    if [[ -z "$requires" || "$requires" == "null" || "$requires" == "[]" ]]; then
      err "Capability '$cap' missing 'requires' preconditions"
    fi
  fi
done

matched_caps=0
while IFS= read -r cap; do
  [[ -z "$cap" ]] && continue
  matched_caps=$((matched_caps + 1))
  plane="$(yq e ".capabilities[\"$cap\"].plane" "$CAPS" 2>/dev/null || echo "")"
  domain="$(yq e ".capabilities[\"$cap\"].domain" "$CAPS" 2>/dev/null || echo "")"

  if [[ -z "$plane" || "$plane" == "null" ]]; then
    err "Capability '$cap' missing 'plane' field"
  fi
  if [[ -z "$domain" || "$domain" == "null" ]]; then
    err "Capability '$cap' missing 'domain' field"
  fi
done < <(yq -r ".capabilities | to_entries[] | select(.key | test(\"${PREFIX_REGEX}\")) | .key" "$CAPS")

if [[ "$matched_caps" -eq 0 ]]; then
  err "No infra-core adjacent capabilities matched regex $PREFIX_REGEX"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D137 FAIL: $ERRORS metadata gaps found"
  exit 1
fi

echo "D137 PASS: ${#TARGET_CAPS[@]} strict infra caps + ${matched_caps} infra-core adjacent caps have required metadata"
exit 0
