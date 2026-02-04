# Version: 1.0.0 — canonical source: agentic-spine/ops/tools/
#!/usr/bin/env bash
# Cloudflare Management Agent
# DNS + Tunnel management via API

set -euo pipefail

CF_API_URL="https://api.cloudflare.com/client/v4"
# Global API Key authentication (full account access, no permission issues)
: "${CF_AUTH_EMAIL:?ERROR: CF_AUTH_EMAIL is required (set in env; do not hardcode)}"
: "${CF_GLOBAL_API_KEY:?ERROR: CF_GLOBAL_API_KEY is required (set in env; do not hardcode)}"

# Zone ID mapping
declare -A ZONE_IDS=(
  ["ronny.works"]="6d3f8f903534aafb27fe1ea2b1bd7269"
  ["mintprints.co"]="8455a1754ffe2f296d74e985a89069f3"
  # mintprints.com - to be added once domain is moved to Cloudflare
)

# Tunnel ID
TUNNEL_ID="ae7d4462-cfb2-4919-802e-41c01742a9eb"
: "${CF_ACCOUNT_ID:?ERROR: CF_ACCOUNT_ID is required (set in env; do not hardcode)}"
ACCOUNT_ID="$CF_ACCOUNT_ID"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_info() { echo -e "${YELLOW}→${NC} $1"; }
log_debug() { echo -e "${BLUE}⊙${NC} $1"; }

# Get zone ID from name or use directly if UUID-like
get_zone_id() {
  local zone="$1"
  if [[ "$zone" =~ ^[0-9a-f]{32}$ ]]; then
    echo "$zone"
  elif [[ -n "${ZONE_IDS[$zone]:-}" ]]; then
    echo "${ZONE_IDS[$zone]}"
  else
    log_error "Unknown zone: $zone"
    log_info "Available zones: ${!ZONE_IDS[*]}"
    exit 1
  fi
}

# Check API credentials are set
check_auth() {
  if [[ -z "$CF_GLOBAL_API_KEY" ]] || [[ -z "$CF_AUTH_EMAIL" ]]; then
    log_error "CF_GLOBAL_API_KEY or CF_AUTH_EMAIL not set"
    log_info "Set via: export CF_GLOBAL_API_KEY='your-key' CF_AUTH_EMAIL='your-email'"
    exit 1
  fi
}

# Verify credentials work
cf_auth() {
  check_auth
  local response
  response=$(curl -s -X GET "${CF_API_URL}/user" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    log_success "Global API Key verified"
    echo "$response" | jq -r '"Email: \(.result.email)\nAccount: \(.result.id)"'
  else
    log_error "Authentication failed"
    echo "$response" | jq -r '.errors[].message' 2>/dev/null
    exit 1
  fi
}

# List all zones
cf_list_zones() {
  check_auth
  local response
  response=$(curl -s -X GET "${CF_API_URL}/zones" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq -r '.result[] | "\(.name): \(.id) [\(.status)]"'
}

# List DNS records for a zone
cf_list_dns() {
  check_auth
  local zone="$1"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  local response
  response=$(curl -s -X GET "${CF_API_URL}/zones/${zone_id}/dns_records" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq -r '.result[] | "\(.type)\t\(.name)\t\(.content)\t\(if .proxied then "proxied" else "dns-only" end)\t\(.id)"' | column -t -s $'\t'
}

# Add DNS record
cf_add_dns() {
  check_auth
  local zone="$1"
  local type="$2"
  local name="$3"
  local content="$4"
  local proxied="${5:-true}"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  # Handle tunnel shorthand
  if [[ "$content" == "tunnel" ]]; then
    content="${TUNNEL_ID}.cfargotunnel.com"
    proxied="true"
  fi

  local response
  response=$(curl -s -X POST "${CF_API_URL}/zones/${zone_id}/dns_records" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"type\": \"${type}\", \"name\": \"${name}\", \"content\": \"${content}\", \"proxied\": ${proxied}}")

  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    local record_id
    record_id=$(echo "$response" | jq -r '.result.id')
    log_success "Created DNS record: $name -> $content (ID: $record_id)"
  else
    log_error "Failed to create DNS record"
    echo "$response" | jq -r '.errors[].message' 2>/dev/null
    exit 1
  fi
}

# Update DNS record
cf_update_dns() {
  check_auth
  local zone="$1"
  local record_id="$2"
  local type="$3"
  local name="$4"
  local content="$5"
  local proxied="${6:-true}"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  # Handle tunnel shorthand
  if [[ "$content" == "tunnel" ]]; then
    content="${TUNNEL_ID}.cfargotunnel.com"
  fi

  local response
  response=$(curl -s -X PUT "${CF_API_URL}/zones/${zone_id}/dns_records/${record_id}" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"type\": \"${type}\", \"name\": \"${name}\", \"content\": \"${content}\", \"proxied\": ${proxied}}")

  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    log_success "Updated DNS record: $name -> $content"
  else
    log_error "Failed to update DNS record"
    echo "$response" | jq -r '.errors[].message' 2>/dev/null
    exit 1
  fi
}

# Delete DNS record
cf_delete_dns() {
  check_auth
  local zone="$1"
  local record_id="$2"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  local response
  response=$(curl -s -X DELETE "${CF_API_URL}/zones/${zone_id}/dns_records/${record_id}" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    log_success "Deleted DNS record: $record_id"
  else
    log_error "Failed to delete DNS record"
    echo "$response" | jq -r '.errors[].message' 2>/dev/null
    exit 1
  fi
}

# Find DNS record by name
cf_find_dns() {
  check_auth
  local zone="$1"
  local name="$2"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  local response
  response=$(curl -s -X GET "${CF_API_URL}/zones/${zone_id}/dns_records?name=${name}" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq -r '.result[] | "\(.type)\t\(.name)\t\(.content)\t\(.id)"'
}

# List tunnels
cf_list_tunnels() {
  check_auth
  if [[ -z "$ACCOUNT_ID" ]]; then
    log_error "CF_ACCOUNT_ID not set"
    exit 1
  fi

  local response
  response=$(curl -s -X GET "${CF_API_URL}/accounts/${ACCOUNT_ID}/cfd_tunnel" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq -r '.result[] | "\(.name): \(.id) [\(.status)]"'
}

# Get tunnel config
cf_get_tunnel_config() {
  check_auth
  if [[ -z "$ACCOUNT_ID" ]]; then
    log_error "CF_ACCOUNT_ID not set"
    exit 1
  fi

  local tunnel_id="${1:-$TUNNEL_ID}"

  local response
  response=$(curl -s -X GET "${CF_API_URL}/accounts/${ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/configurations" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq '.result.config.ingress'
}

# Check zone status
cf_check_zone_status() {
  check_auth
  local zone="$1"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  local response
  response=$(curl -s -X GET "${CF_API_URL}/zones/${zone_id}" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq '{
    name: .result.name,
    status: .result.status,
    nameservers: .result.name_servers,
    plan: .result.plan.name
  }'
}

# Purge cache
cf_purge_cache() {
  check_auth
  local zone="$1"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  local response
  response=$(curl -s -X POST "${CF_API_URL}/zones/${zone_id}/purge_cache" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"purge_everything": true}')

  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    log_success "Cache purged for $zone"
  else
    log_error "Failed to purge cache"
    echo "$response" | jq -r '.errors[].message' 2>/dev/null
    exit 1
  fi
}

# Force zone activation check
cf_activate_zone() {
  check_auth
  local zone="$1"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  log_info "Forcing activation check for $zone..."
  local response
  response=$(curl -s -X PUT "${CF_API_URL}/zones/${zone_id}/activation_check" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  if echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
    log_success "Activation check triggered for $zone"
  else
    log_error "Failed to trigger activation check"
    echo "$response" | jq -r '.errors[].message' 2>/dev/null
    exit 1
  fi
}

# Get SSL status
cf_ssl_status() {
  check_auth
  local zone="$1"
  local zone_id
  zone_id=$(get_zone_id "$zone")

  local response
  response=$(curl -s -X GET "${CF_API_URL}/zones/${zone_id}/settings/ssl" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY")

  echo "$response" | jq '{
    ssl_mode: .result.value,
    editable: .result.editable
  }'
}

# Health check all zones
cf_health_check() {
  check_auth
  echo "=== Cloudflare Health Check ==="
  echo ""

  # Check each zone
  local zones=("ronny.works" "mintprints.co")
  for zone in "${zones[@]}"; do
    local zone_id
    zone_id=$(get_zone_id "$zone")
    local zone_status ssl_mode
    zone_status=$(curl -s -X GET "${CF_API_URL}/zones/${zone_id}" \
      -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY" | jq -r '.result.status')
    ssl_mode=$(curl -s -X GET "${CF_API_URL}/zones/${zone_id}/settings/ssl" \
      -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY" | jq -r '.result.value')

    if [[ "$zone_status" == "active" ]]; then
      log_success "$zone: status=$zone_status, ssl=$ssl_mode"
    else
      log_error "$zone: status=$zone_status, ssl=$ssl_mode"
    fi
  done

  echo ""
  local tunnel_status
  tunnel_status=$(curl -s -X GET "${CF_API_URL}/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}" \
    -H "X-Auth-Email: $CF_AUTH_EMAIL" -H "X-Auth-Key: $CF_GLOBAL_API_KEY" | jq -r '.result.status')

  if [[ "$tunnel_status" == "healthy" ]]; then
    log_success "Tunnel: $tunnel_status"
  else
    log_info "Tunnel: $tunnel_status"
  fi
}

# Show help
show_help() {
  cat << EOF
Cloudflare Management Agent

Usage: $(basename "$0") <command> [args]

DNS Commands:
  list-dns <zone>                           List all DNS records
  add-dns <zone> <type> <name> <content> [proxied]
                                            Add DNS record (content="tunnel" for tunnel CNAME)
  update-dns <zone> <record_id> <type> <name> <content> [proxied]
                                            Update DNS record
  delete-dns <zone> <record_id>             Delete DNS record
  find-dns <zone> <name>                    Find DNS record by name

Zone Commands:
  zones                                     List all zones
  check-zone <zone>                         Check zone status
  activate-zone <zone>                      Force zone activation check
  ssl-status <zone>                         Check SSL/TLS mode
  purge-cache <zone>                        Purge zone cache
  health-check                              Full health check of all zones

Tunnel Commands:
  tunnels                                   List all tunnels
  tunnel-config [tunnel_id]                 Get tunnel ingress config

Auth:
  auth                                      Verify API token

Zones:
$(for z in "${!ZONE_IDS[@]}"; do echo "  $z"; done | sort)

Environment Variables:
  CF_AUTH_EMAIL      Cloudflare account email (required)
  CF_GLOBAL_API_KEY  Global API Key (required, full account access)
  CF_ACCOUNT_ID      Account ID (required for tunnel operations)

Examples:
  $(basename "$0") auth
  $(basename "$0") list-dns ronny.works
  $(basename "$0") add-dns ronny.works CNAME api tunnel
  $(basename "$0") add-dns ronny.works A @ 1.2.3.4 false
  $(basename "$0") check-zone mintprints.co
  $(basename "$0") purge-cache ronny.works
EOF
}

# Main command router
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    auth|verify)
      cf_auth
      ;;
    zones|list-zones)
      cf_list_zones
      ;;
    list-dns|dns)
      [[ $# -lt 1 ]] && { log_error "Usage: list-dns <zone>"; exit 1; }
      cf_list_dns "$1"
      ;;
    add-dns)
      [[ $# -lt 4 ]] && { log_error "Usage: add-dns <zone> <type> <name> <content> [proxied]"; exit 1; }
      cf_add_dns "$1" "$2" "$3" "$4" "${5:-true}"
      ;;
    update-dns)
      [[ $# -lt 5 ]] && { log_error "Usage: update-dns <zone> <record_id> <type> <name> <content> [proxied]"; exit 1; }
      cf_update_dns "$1" "$2" "$3" "$4" "$5" "${6:-true}"
      ;;
    delete-dns)
      [[ $# -lt 2 ]] && { log_error "Usage: delete-dns <zone> <record_id>"; exit 1; }
      cf_delete_dns "$1" "$2"
      ;;
    find-dns)
      [[ $# -lt 2 ]] && { log_error "Usage: find-dns <zone> <name>"; exit 1; }
      cf_find_dns "$1" "$2"
      ;;
    check-zone|status)
      [[ $# -lt 1 ]] && { log_error "Usage: check-zone <zone>"; exit 1; }
      cf_check_zone_status "$1"
      ;;
    purge-cache|purge)
      [[ $# -lt 1 ]] && { log_error "Usage: purge-cache <zone>"; exit 1; }
      cf_purge_cache "$1"
      ;;
    activate-zone|activate)
      [[ $# -lt 1 ]] && { log_error "Usage: activate-zone <zone>"; exit 1; }
      cf_activate_zone "$1"
      ;;
    ssl-status|ssl)
      [[ $# -lt 1 ]] && { log_error "Usage: ssl-status <zone>"; exit 1; }
      cf_ssl_status "$1"
      ;;
    health-check|health)
      cf_health_check
      ;;
    tunnels|list-tunnels)
      cf_list_tunnels
      ;;
    tunnel-config)
      cf_get_tunnel_config "${1:-}"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      log_error "Unknown command: $cmd"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
