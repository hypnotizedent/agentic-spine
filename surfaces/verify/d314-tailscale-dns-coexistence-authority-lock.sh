#!/usr/bin/env bash
# TRIAGE: DNS authority and Cloudflare/Tailscale coexistence contracts must be defined and wired.
# D314: Tailscale DNS + coexistence authority lock.
# Ensures the authority contract has dns_authority and cloudflare_tailscale_coexistence sections
# with required fields, and coexistence bindings are referenced.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTHORITY="$ROOT/docs/CANONICAL/TAILSCALE_AUTHORITY_CONTRACT_V1.yaml"
CF_INVENTORY="$ROOT/ops/bindings/cloudflare.inventory.yaml"
ROUTING_REG="$ROOT/docs/governance/DOMAIN_ROUTING_REGISTRY.yaml"

fail=0
err() { echo "D314 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { err "missing dependency: yq"; exit 1; }
[[ -f "$AUTHORITY" ]] || { err "authority contract missing: $AUTHORITY"; exit 1; }
[[ -f "$CF_INVENTORY" ]] || { err "cloudflare inventory missing: $CF_INVENTORY"; exit 1; }
[[ -f "$ROUTING_REG" ]] || { err "domain routing registry missing: $ROUTING_REG"; exit 1; }

# 1) DNS authority section must exist with required resolvers
dns_status=$(yq -r '.dns_authority.status // ""' "$AUTHORITY" 2>/dev/null || true)
[[ "$dns_status" == "authoritative" ]] || err "dns_authority.status must be authoritative"

for resolver in magicdns pihole cloudflare public_fallback; do
  scope=$(yq -r ".dns_authority.resolvers.${resolver}.scope // \"\"" "$AUTHORITY" 2>/dev/null || true)
  [[ -n "$scope" && "$scope" != "null" ]] || err "dns_authority.resolvers.${resolver}.scope missing"
done

# 2) Cloudflare/Tailscale coexistence section must exist
coex_status=$(yq -r '.cloudflare_tailscale_coexistence.status // ""' "$AUTHORITY" 2>/dev/null || true)
[[ "$coex_status" == "authoritative" ]] || err "cloudflare_tailscale_coexistence.status must be authoritative"

# 3) Coexistence must define both boundary types
for boundary in cloudflare_tunnel tailscale_direct lan_first; do
  purpose=$(yq -r ".cloudflare_tailscale_coexistence.boundaries.${boundary}.purpose // \"\"" "$AUTHORITY" 2>/dev/null || true)
  [[ -n "$purpose" && "$purpose" != "null" ]] || err "coexistence boundary ${boundary}.purpose missing"
done

# 4) Cloudflare inventory must match zone count referenced in DNS authority
cf_zone_count=$(yq -r '.zones | length' "$CF_INVENTORY" 2>/dev/null || echo 0)
dns_zone_count=$(yq -r '.dns_authority.resolvers.cloudflare.zones // 0' "$AUTHORITY" 2>/dev/null || echo 0)
if [[ "$cf_zone_count" -ne "$dns_zone_count" ]]; then
  err "zone count mismatch: cloudflare.inventory has $cf_zone_count zones, dns_authority says $dns_zone_count"
fi

# 5) Domain routing registry must exist and have zones
routing_zones=$(yq -r '.zones | length' "$ROUTING_REG" 2>/dev/null || echo 0)
[[ "$routing_zones" -gt 0 ]] || err "domain routing registry has no zones"

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D314 PASS: DNS authority + coexistence contracts valid (4 resolvers, 3 boundaries, $cf_zone_count zones matched)"
