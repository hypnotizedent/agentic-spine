#!/usr/bin/env bash
# mint-health-surface.sh — Canonical Mint health surface helpers
#
# Global health authority lives in ops/bindings/services.health.yaml.
# Mint-specific bindings should only carry non-HTTP metadata (targets, SSH checks,
# proof routes). Do not duplicate Mint HTTP port/path definitions elsewhere.

_MINT_HEALTH_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
_MINT_HEALTH_BINDING="${_MINT_HEALTH_ROOT}/ops/bindings/services.health.yaml"
_MINT_PROBE_BINDING="${_MINT_HEALTH_ROOT}/ops/bindings/mint.probe.targets.yaml"

mint_probe_target_id() {
  local plane="$1"
  yq -r ".targets.${plane}.ssh_target // \"\"" "$_MINT_PROBE_BINDING" 2>/dev/null || echo ""
}

mint_probe_vm_id() {
  local plane="$1"
  yq -r ".targets.${plane}.vm_id // \"\"" "$_MINT_PROBE_BINDING" 2>/dev/null || echo ""
}

mint_service_canonical_id() {
  local component="$1"
  case "$component" in
    files-api|files-api-v2) printf '%s\n' "files-api-v2" ;;
    quote-page|quote-page-v2) printf '%s\n' "quote-page-v2" ;;
    order-intake|order-intake-v2) printf '%s\n' "order-intake-v2" ;;
    finance-adapter) printf '%s\n' "finance-adapter" ;;
    pricing|pricing-v2) printf '%s\n' "pricing-v2" ;;
    suppliers|suppliers-v2) printf '%s\n' "suppliers-v2" ;;
    shipping|shipping-v2) printf '%s\n' "shipping-v2" ;;
    payment|payment-v2) printf '%s\n' "payment-v2" ;;
    minio|mint-modules-minio) printf '%s\n' "mint-modules-minio" ;;
    *) printf '%s\n' "$component" ;;
  esac
}

mint_service_field() {
  local component="$1"
  local field="$2"
  local service_id
  service_id="$(mint_service_canonical_id "$component")"
  yq -r ".endpoints[] | select(.id == \"$service_id\") | .${field} // \"\"" \
    "$_MINT_HEALTH_BINDING" 2>/dev/null | head -n1
}

mint_service_url() {
  mint_service_field "$1" "url"
}

mint_service_host_target() {
  mint_service_field "$1" "host"
}

mint_service_enabled() {
  local enabled
  enabled="$(mint_service_field "$1" "enabled")"
  if [[ -z "$enabled" || "$enabled" == "null" ]]; then
    printf '%s\n' "true"
  else
    printf '%s\n' "$enabled"
  fi
}

mint_service_port() {
  local url
  url="$(mint_service_url "$1")"
  python3 - "$url" <<'PY'
import sys
from urllib.parse import urlparse

url = sys.argv[1]
parsed = urlparse(url)
print(parsed.port or "")
PY
}

mint_service_path() {
  local url
  url="$(mint_service_url "$1")"
  python3 - "$url" <<'PY'
import sys
from urllib.parse import urlparse

url = sys.argv[1]
parsed = urlparse(url)
path = parsed.path or "/"
if parsed.query:
    path = f"{path}?{parsed.query}"
print(path)
PY
}

mint_http_rows_tsv() {
  cat <<'EOF'
files-api	app_plane
quote-page	app_plane
order-intake	app_plane
finance-adapter	app_plane
pricing	app_plane
suppliers	app_plane
shipping	app_plane
payment	app_plane
minio	data_plane
EOF
}
