#!/usr/bin/env bash
# Secret Expiry Monitoring Script
# Checks all Infisical secrets and alerts on old/stale secrets
# Issue #127

set -eo pipefail

INFISICAL_API_URL="${INFISICAL_API_URL:-https://secrets.ronny.works}"
INFISICAL_CLIENT_ID="${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-40b44e76-db5a-4309-afa2-43bd93dddfc1}"
INFISICAL_CLIENT_SECRET="${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}"

# Thresholds (days)
WARNING_THRESHOLD="${WARNING_THRESHOLD:-60}"
CRITICAL_THRESHOLD="${CRITICAL_THRESHOLD:-90}"

# Output mode: text, json, or teams
OUTPUT_MODE="${OUTPUT_MODE:-text}"

# Teams webhook (optional)
TEAMS_WEBHOOK_URL="${TEAMS_WEBHOOK_URL:-}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Projects to check
PROJECTS=(
  "mint-os-api:6c67b03e-ed17-4154-9a94-59837738e432"
  "infrastructure:01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9"
  "n8n:4b9dfc6d-13e8-43c8-bd84-9beb64eb8e16"
  "finance-stack:4c34714d-6d85-4aa6-b8df-5a9505f3bcef"
  "media-stack:3807f1c4-e354-4aaf-a16f-8567d7f78a7e"
)

# Secrets that commonly expire and need monitoring
MONITORED_SECRETS=(
  "GITHUB_TOKEN"
  "GITHUB_PERSONAL_ACCESS_TOKEN"
  "AZURE_CLIENT_SECRET"
  "MS365_CLIENT_SECRET"
  "N8N_API_KEY"
  "STRIPE_SECRET_KEY"
  "STRIPE_WEBHOOK_SECRET"
  "TWILIO_AUTH_TOKEN"
  "CLOUDFLARE_API_TOKEN"
  "HA_API_TOKEN"
  "FIREFLY_ACCESS_TOKEN"
  "FIREFLY_PAT"
  "IMMICH_API_KEY"
  "PAPERLESS_API_TOKEN"
  "RESEND_API_KEY"
  "EASYPOST_API_KEY"
  "PRINTAVO_API_KEY"
)

log_info() { echo -e "${CYAN}→${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }

# Authenticate and get access token
infisical_auth() {
  if [[ -z "$INFISICAL_CLIENT_SECRET" ]]; then
    log_error "INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET not set"
    exit 1
  fi

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -X POST "${INFISICAL_API_URL}/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\": \"${INFISICAL_CLIENT_ID}\", \"clientSecret\": \"${INFISICAL_CLIENT_SECRET}\"}")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    log_error "Auth failed: HTTP $http_code"
    exit 1
  fi

  local token
  token=$(echo "$body" | jq -r '.accessToken // empty')

  if [[ -z "$token" ]]; then
    log_error "Auth failed: no access token in response"
    exit 1
  fi

  echo "$token"
}

# Get secrets with full metadata
get_secrets_with_metadata() {
  local project_id="$1"
  local env="${2:-prod}"
  local token="$3"

  local response
  response=$(curl -s -X GET "${INFISICAL_API_URL}/api/v3/secrets/raw?workspaceId=${project_id}&environment=${env}" \
    -H "Authorization: Bearer $token")

  # Validate response is parseable JSON with a secrets array
  if ! echo "$response" | jq -e '.secrets' >/dev/null 2>&1; then
    log_error "Invalid response for project $project_id (env: $env)"
    echo '{"secrets":[]}'
    return
  fi

  echo "$response"
}

# Calculate days since date
days_since() {
  local date_str="$1"
  local now_epoch
  local date_epoch

  now_epoch=$(date +%s)

  # Handle ISO date format from Infisical
  if command -v gdate &> /dev/null; then
    # macOS with coreutils
    date_epoch=$(gdate -d "$date_str" +%s 2>/dev/null || echo "0")
  else
    # Linux
    date_epoch=$(date -d "$date_str" +%s 2>/dev/null || echo "0")
  fi

  if [[ "$date_epoch" == "0" ]]; then
    echo "unknown"
    return
  fi

  local diff=$(( (now_epoch - date_epoch) / 86400 ))
  echo "$diff"
}

# Check if secret is in monitored list
is_monitored() {
  local key="$1"
  for monitored in "${MONITORED_SECRETS[@]}"; do
    if [[ "$key" == "$monitored" ]]; then
      return 0
    fi
  done
  return 1
}

# Main check function
check_all_secrets() {
  local token
  token=$(infisical_auth)

  local warnings=()
  local criticals=()
  local total_secrets=0
  local total_old=0

  echo ""
  echo "========================================"
  echo " Infisical Secret Expiry Check"
  echo " $(date '+%Y-%m-%d %H:%M:%S')"
  echo "========================================"
  echo ""

  for project_entry in "${PROJECTS[@]}"; do
    local project_name="${project_entry%%:*}"
    local project_id="${project_entry##*:}"

    log_info "Checking: $project_name"

    local secrets_json
    secrets_json=$(get_secrets_with_metadata "$project_id" "prod" "$token")

    local count
    count=$(echo "$secrets_json" | jq '.secrets | length')
    total_secrets=$((total_secrets + count))

    # Process each secret
    echo "$secrets_json" | jq -c '.secrets[]' | while read -r secret; do
      local key
      local updated_at
      local days

      key=$(echo "$secret" | jq -r '.secretKey')
      updated_at=$(echo "$secret" | jq -r '.updatedAt // .createdAt // "unknown"')

      if [[ "$updated_at" != "unknown" && "$updated_at" != "null" ]]; then
        days=$(days_since "$updated_at")

        if [[ "$days" != "unknown" ]]; then
          # Check thresholds
          if [[ "$days" -ge "$CRITICAL_THRESHOLD" ]]; then
            echo -e "  ${RED}CRITICAL${NC}: $key - $days days old"
            echo "$project_name|$key|$days|critical" >> /tmp/secret_alerts.txt
          elif [[ "$days" -ge "$WARNING_THRESHOLD" ]]; then
            if is_monitored "$key"; then
              echo -e "  ${YELLOW}WARNING${NC}: $key - $days days old"
              echo "$project_name|$key|$days|warning" >> /tmp/secret_alerts.txt
            fi
          fi
        fi
      fi
    done

    echo "    Total: $count secrets"
    echo ""
  done

  echo "========================================"
  echo " Summary"
  echo "========================================"
  echo "Total secrets checked: $total_secrets"

  if [[ -f /tmp/secret_alerts.txt ]]; then
    local critical_count
    local warning_count
    critical_count=$(grep -c "|critical$" /tmp/secret_alerts.txt 2>/dev/null || echo "0")
    warning_count=$(grep -c "|warning$" /tmp/secret_alerts.txt 2>/dev/null || echo "0")

    echo -e "Critical (>$CRITICAL_THRESHOLD days): ${RED}$critical_count${NC}"
    echo -e "Warning (>$WARNING_THRESHOLD days): ${YELLOW}$warning_count${NC}"

    # Send Teams alert if configured and there are issues
    if [[ -n "$TEAMS_WEBHOOK_URL" && ( "$critical_count" -gt 0 || "$warning_count" -gt 0 ) ]]; then
      send_teams_alert
    fi

    rm -f /tmp/secret_alerts.txt

    if [[ "$critical_count" -gt 0 ]]; then
      exit 2
    elif [[ "$warning_count" -gt 0 ]]; then
      exit 1
    fi
  else
    echo -e "${GREEN}All monitored secrets are fresh!${NC}"
  fi
}

# Send Teams webhook alert
send_teams_alert() {
  if [[ ! -f /tmp/secret_alerts.txt ]]; then
    return
  fi

  local facts=""
  while IFS='|' read -r project key days level; do
    local emoji="⚠️"
    [[ "$level" == "critical" ]] && emoji="🔴"
    facts="$facts{\"name\": \"$key\", \"value\": \"$days days old ($project) $emoji\"},"
  done < /tmp/secret_alerts.txt

  # Remove trailing comma
  facts="${facts%,}"

  local payload
  payload=$(cat <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "FF0000",
  "summary": "Secret Expiry Warning",
  "sections": [{
    "activityTitle": "🔐 Secret Expiry Warning",
    "activitySubtitle": "The following secrets may need rotation",
    "facts": [$facts],
    "markdown": true
  }]
}
EOF
)

  local webhook_status
  webhook_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$TEAMS_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$payload")

  if [[ "$webhook_status" =~ ^2 ]]; then
    log_success "Teams alert sent (HTTP $webhook_status)"
  else
    log_error "Teams alert failed: HTTP $webhook_status"
  fi
}

# Generate JSON report
generate_json_report() {
  local token
  token=$(infisical_auth)

  echo "{"
  echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
  echo "  \"thresholds\": {"
  echo "    \"warning\": $WARNING_THRESHOLD,"
  echo "    \"critical\": $CRITICAL_THRESHOLD"
  echo "  },"
  echo "  \"projects\": ["

  local first_project=true
  for project_entry in "${PROJECTS[@]}"; do
    local project_name="${project_entry%%:*}"
    local project_id="${project_entry##*:}"

    [[ "$first_project" == "false" ]] && echo ","
    first_project=false

    local secrets_json
    secrets_json=$(get_secrets_with_metadata "$project_id" "prod" "$token")

    echo "    {"
    echo "      \"name\": \"$project_name\","
    echo "      \"secrets\": $(echo "$secrets_json" | jq '[.secrets[] | {key: .secretKey, updatedAt: (.updatedAt // .createdAt)}]')"
    echo -n "    }"
  done

  echo ""
  echo "  ]"
  echo "}"
}

# Show help
show_help() {
  cat << 'EOF'
Secret Expiry Monitoring Script

Usage: check-secret-expiry.sh [command]

Commands:
  check       Run expiry check (default)
  json        Generate JSON report
  help        Show this help

Environment Variables:
  WARNING_THRESHOLD   Days before warning (default: 60)
  CRITICAL_THRESHOLD  Days before critical (default: 90)
  TEAMS_WEBHOOK_URL   Teams webhook for alerts (optional)
  OUTPUT_MODE         text, json, or teams (default: text)

Exit Codes:
  0  All secrets fresh
  1  Warnings found
  2  Critical issues found

Examples:
  check-secret-expiry.sh
  check-secret-expiry.sh check
  check-secret-expiry.sh json > report.json
  WARNING_THRESHOLD=30 check-secret-expiry.sh
EOF
}

# Main
main() {
  local cmd="${1:-check}"

  case "$cmd" in
    check)
      check_all_secrets
      ;;
    json)
      generate_json_report
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
