#!/usr/bin/env bash
# Version: 1.1.0 — canonical source: agentic-spine/ops/tools/
# Infisical Secrets Management Agent
# Direct API calls - no CLI dependency
# Fixed: removed declare -A to avoid set -u issues
# Updated: 2026-01-22 - Added --cached flag for fast shell startup

set -eo pipefail

# Source credentials if not already set (enables Desktop Commander / non-shell access)
CREDENTIALS_FILE="${HOME}/.config/infisical/credentials"
if [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" && -f "$CREDENTIALS_FILE" ]]; then
  source "$CREDENTIALS_FILE"
fi

INFISICAL_CLIENT_ID="${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-40b44e76-db5a-4309-afa2-43bd93dddfc1}"
INFISICAL_CLIENT_SECRET="${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}"
SPINE_REPO="${SPINE_REPO:-$HOME/code/agentic-spine}"
SECRETS_BINDING="${SPINE_REPO}/ops/bindings/secrets.binding.yaml"
SECRETS_NAMESPACE_POLICY="${SPINE_REPO}/ops/bindings/secrets.namespace.policy.yaml"

# Prefer internal_api_url from binding (bypasses Authentik forward auth),
# fall back to env var, then public URL.
if [[ -f "$SECRETS_BINDING" ]] && command -v yq >/dev/null 2>&1; then
  _binding_url="$(yq -r '.infisical.internal_api_url // .infisical.api_url // ""' "$SECRETS_BINDING" 2>/dev/null || true)"
  INFISICAL_API_URL="${_binding_url:-${INFISICAL_API_URL:-https://secrets.ronny.works}}"
  unset _binding_url
else
  INFISICAL_API_URL="${INFISICAL_API_URL:-https://secrets.ronny.works}"
fi

# Cache configuration
CACHE_DIR="${HOME}/.cache/infisical"
CACHE_TTL="${INFISICAL_CACHE_TTL:-14400}"  # Default: 4 hours (14400 seconds)

# Deprecated project detection (lifecycle != active/clean)
# These projects must not be targeted by new agent write operations.
is_deprecated_project() {
  case "$1" in
    finance-stack|mint-os-portal|mint-os-vault) return 0 ;;
    *) return 1 ;;
  esac
}

# Project ID lookup function (case statement avoids associative array issues)
get_project_id_from_name() {
  case "$1" in
    mint-os-api)    echo "6c67b03e-ed17-4154-9a94-59837738e432" ;;
    mint-os-vault)  echo "66d149d6-f610-4ec3-a400-3ff42ea1aa75" ;;
    mint-os-portal) echo "758e5db3-8d00-4ccf-8d91-aeaad0d6ed37" ;;
    infrastructure) echo "01ddd93a-e0f8-4c7c-ad9f-903d76ef94d9" ;;
    n8n)            echo "4b9dfc6d-13e8-43c8-bd84-9beb64eb8e16" ;;
    finance-stack)  echo "4c34714d-6d85-4aa6-b8df-5a9505f3bcef" ;;
    media-stack)    echo "3807f1c4-e354-4aaf-a16f-8567d7f78a7e" ;;
    immich)         echo "4bf7f25e-596b-4293-9d2a-c2c7c2d0df42" ;;
    home-assistant) echo "5df75515-7259-4c14-98b8-5adda379aade" ;;
    *)              echo "" ;;
  esac
}

# Guard: block mutating operations on deprecated projects
guard_deprecated_write() {
  local project="$1"
  local cmd="$2"
  if is_deprecated_project "$project"; then
    log_error "STOP: '$cmd' blocked — project '$project' is deprecated."
    log_info "Governed writes target 'infrastructure' project only. See secrets.inventory.yaml lifecycle field."
    exit 1
  fi
}

# Guard: warn on read operations targeting deprecated projects
guard_deprecated_read() {
  local project="$1"
  if is_deprecated_project "$project"; then
    echo "WARN: reading from deprecated project '$project'. Migrate to 'infrastructure' project." >&2
  fi
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_info() { echo -e "${YELLOW}→${NC} $1"; }

# ═══════════════════════════════════════════════════════════════
# CACHE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Get cache file path for a secret
get_cache_path() {
  local project="$1"
  local env="$2"
  local key="$3"
  local secret_path="${4:-/}"
  local path_segment="${secret_path#/}"
  [[ -n "$path_segment" ]] || path_segment="root"
  path_segment="${path_segment//\//__}"
  echo "${CACHE_DIR}/${project}/${env}/${path_segment}/${key}"
}

# Resolve canonical path for key operations.
# Falls back to "/" when no namespace policy applies.
resolve_secret_path() {
  local project="${1:-}"
  local env="${2:-}"
  local key="${3:-}"

  # Namespace cutovers are currently scoped to infrastructure/prod only.
  if [[ "$project" != "infrastructure" || "$env" != "prod" ]]; then
    echo "/"
    return 0
  fi

  if [[ ! -f "$SECRETS_NAMESPACE_POLICY" ]] || ! command -v yq >/dev/null 2>&1; then
    echo "/"
    return 0
  fi

  local resolved
  resolved="$(yq e -r ".rules.key_path_overrides.${key} // \"\"" "$SECRETS_NAMESPACE_POLICY" 2>/dev/null || true)"
  if [[ -n "$resolved" && "$resolved" != "null" ]]; then
    echo "$resolved"
  else
    echo "/"
  fi
}

urlencode() {
  jq -rn --arg v "${1:-}" '$v|@uri'
}

# Check if cache is valid (exists and not expired)
is_cache_valid() {
  local cache_file="$1"

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  local file_age
  if [[ "$(uname)" == "Darwin" ]]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$cache_file") ))
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
  fi

  if [[ $file_age -lt $CACHE_TTL ]]; then
    return 0
  else
    return 1
  fi
}

# Read from cache
read_cache() {
  local cache_file="$1"
  cat "$cache_file" 2>/dev/null
}

# Write to cache
write_cache() {
  local cache_file="$1"
  local value="$2"

  mkdir -p "$(dirname "$cache_file")"
  echo -n "$value" > "$cache_file"
  chmod 600 "$cache_file"
}

# Clear cache for a specific secret or all
clear_cache() {
  local project="${1:-}"
  local env="${2:-}"
  local key="${3:-}"

  if [[ -n "$key" && -n "$env" && -n "$project" ]]; then
    local cache_file
    local secret_path
    secret_path=$(resolve_secret_path "$project" "$env" "$key")
    cache_file=$(get_cache_path "$project" "$env" "$key" "$secret_path")
    rm -f "$cache_file"
    log_success "Cleared cache: $project/$env/$key"
  elif [[ -n "$project" ]]; then
    rm -rf "${CACHE_DIR}/${project}"
    log_success "Cleared cache for project: $project"
  else
    rm -rf "${CACHE_DIR}"
    log_success "Cleared all cache"
  fi
}

# Get project ID from name or use directly if UUID
get_project_id() {
  local project="${1:-}"
  if [[ -z "$project" ]]; then
    log_error "Project name required"
    exit 1
  fi
  if [[ "$project" =~ ^[0-9a-f-]{36}$ ]]; then
    echo "$project"
  else
    local id
    id=$(get_project_id_from_name "$project")
    if [[ -n "$id" ]]; then
      echo "$id"
    else
      log_error "Unknown project: $project"
      log_info "Active: infrastructure mint-os-api n8n media-stack immich home-assistant"
      log_info "Deprecated (read-only): finance-stack mint-os-vault mint-os-portal"
      exit 1
    fi
  fi
}

# Authenticate and get access token
infisical_auth() {
  if [[ -z "$INFISICAL_CLIENT_SECRET" ]]; then
    log_error "INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET not set"
    log_info "Get it from: ssh docker-host \"grep INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET ~/.bashrc\""
    exit 1
  fi

  local response
  response=$(curl -s -X POST "${INFISICAL_API_URL}/api/v1/auth/universal-auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"clientId\": \"${INFISICAL_CLIENT_ID}\", \"clientSecret\": \"${INFISICAL_CLIENT_SECRET}\"}")

  local token
  token=$(echo "$response" | jq -r '.accessToken // empty')

  if [[ -z "$token" ]]; then
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
    log_error "Auth failed: $error_msg"
    exit 1
  fi

  echo "$token"
}

# List all projects (workspaces)
infisical_list_projects() {
  local token
  token=$(infisical_auth)

  curl -s -X GET "${INFISICAL_API_URL}/api/v2/organizations/workspaces" \
    -H "Authorization: Bearer $token" | jq -r '.workspaces[] | "\(.name): \(.id)"'
}

# List secrets in a project/environment
infisical_list_secrets() {
  local project="${1:-}"
  local env="${2:-dev}"

  if [[ -z "$project" ]]; then
    log_error "Usage: list <project> [env]"
    exit 1
  fi

  guard_deprecated_read "$project"

  local project_id
  project_id=$(get_project_id "$project")
  local secret_path
  secret_path=$(resolve_secret_path "$project" "$env" "")
  local encoded_path
  encoded_path=$(urlencode "$secret_path")

  local token
  token=$(infisical_auth)

  curl -s -X GET "${INFISICAL_API_URL}/api/v3/secrets/raw?workspaceId=${project_id}&environment=${env}&secretPath=${encoded_path}" \
    -H "Authorization: Bearer $token" | jq -r '.secrets[] | "\(.secretKey)=\(.secretValue)"'
}

# Get a single secret (always fetches from API)
infisical_get_secret() {
  local project="${1:-}"
  local env="${2:-}"
  local key="${3:-}"

  if [[ -z "$project" || -z "$env" || -z "$key" ]]; then
    log_error "Usage: get <project> <env> <key>"
    exit 1
  fi

  guard_deprecated_read "$project"

  local project_id
  project_id=$(get_project_id "$project")
  local secret_path
  secret_path=$(resolve_secret_path "$project" "$env" "$key")
  local encoded_path
  encoded_path=$(urlencode "$secret_path")

  local token
  token=$(infisical_auth)

  local response
  response=$(curl -s -X GET "${INFISICAL_API_URL}/api/v3/secrets/raw/${key}?workspaceId=${project_id}&environment=${env}&secretPath=${encoded_path}" \
    -H "Authorization: Bearer $token")

  echo "$response" | jq -r '.secret.secretValue // empty'
}

# Get a single secret with caching (fast for shell startup)
# Usage: get-cached <project> <env> <key> [--no-cache]
infisical_get_secret_cached() {
  local project="${1:-}"
  local env="${2:-}"
  local key="${3:-}"
  local force_refresh="${4:-}"

  if [[ -z "$project" || -z "$env" || -z "$key" ]]; then
    log_error "Usage: get-cached <project> <env> <key> [--no-cache]"
    exit 1
  fi

  local cache_file
  local secret_path
  secret_path=$(resolve_secret_path "$project" "$env" "$key")
  cache_file=$(get_cache_path "$project" "$env" "$key" "$secret_path")

  # Check if we should use cache
  if [[ "$force_refresh" != "--no-cache" ]] && is_cache_valid "$cache_file"; then
    read_cache "$cache_file"
    return 0
  fi

  # Fetch from API
  local value
  value=$(infisical_get_secret "$project" "$env" "$key")

  # Write to cache if we got a value
  if [[ -n "$value" ]]; then
    write_cache "$cache_file" "$value"
  fi

  echo "$value"
}

# Show cache status
infisical_cache_info() {
  if [[ ! -d "$CACHE_DIR" ]]; then
    log_info "No cache directory exists"
    return 0
  fi

  echo "Cache directory: $CACHE_DIR"
  echo "Cache TTL: ${CACHE_TTL}s ($(( CACHE_TTL / 3600 ))h $(( (CACHE_TTL % 3600) / 60 ))m)"
  echo ""
  echo "Cached secrets:"

  local count=0
  while IFS= read -r -d '' file; do
    local rel_path="${file#$CACHE_DIR/}"
    local project="${rel_path%%/*}"
    local after_project="${rel_path#*/}"
    local env="${after_project%%/*}"
    local tail="${after_project#*/}"
    local key="${tail##*/}"
    local path_segment="${tail%/*}"
    local display_path="/${path_segment//__/\/}"
    [[ "$path_segment" == "$key" ]] && display_path="/"

    local file_age
    if [[ "$(uname)" == "Darwin" ]]; then
      file_age=$(( $(date +%s) - $(stat -f %m "$file") ))
    else
      file_age=$(( $(date +%s) - $(stat -c %Y "$file") ))
    fi

    local remaining=$(( CACHE_TTL - file_age ))
    local status="valid"
    if [[ $remaining -le 0 ]]; then
      status="expired"
      remaining=0
    fi

    printf "  %-20s %-6s %-24s %-24s [%s, %dm remaining]\n" "$project" "$env" "$key" "$display_path" "$status" "$(( remaining / 60 ))"
    count=$((count + 1))
  done < <(find "$CACHE_DIR" -type f -print0 2>/dev/null)

  if [[ $count -eq 0 ]]; then
    echo "  (none)"
  fi
  echo ""
  echo "Total: $count cached secrets"
}

# Set/create a secret
infisical_set_secret() {
  local project="${1:-}"
  local env="${2:-}"
  local key="${3:-}"
  local value="${4:-}"

  if [[ -z "$project" || -z "$env" || -z "$key" ]]; then
    log_error "Usage: set <project> <env> <key> <value>"
    exit 1
  fi

  guard_deprecated_write "$project" "set"

  local project_id
  project_id=$(get_project_id "$project")
  local secret_path
  secret_path=$(resolve_secret_path "$project" "$env" "$key")

  local token
  token=$(infisical_auth)

  # Try to update first, if fails create
  local response
  response=$(curl -s -X PATCH "${INFISICAL_API_URL}/api/v3/secrets/raw/${key}" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"workspaceId\": \"${project_id}\", \"environment\": \"${env}\", \"secretValue\": \"${value}\", \"secretPath\": \"${secret_path}\"}")

  if echo "$response" | jq -e '.secret' >/dev/null 2>&1; then
    log_success "Updated secret: $key"
    return 0
  fi

  # Create new secret
  response=$(curl -s -X POST "${INFISICAL_API_URL}/api/v3/secrets/raw/${key}" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"workspaceId\": \"${project_id}\", \"environment\": \"${env}\", \"secretValue\": \"${value}\", \"secretPath\": \"${secret_path}\", \"type\": \"shared\"}")

  if echo "$response" | jq -e '.secret' >/dev/null 2>&1; then
    log_success "Created secret: $key"
  else
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
    log_error "Failed to set secret: $error_msg"
    exit 1
  fi
}

# Delete a secret
infisical_delete_secret() {
  local project="${1:-}"
  local env="${2:-}"
  local key="${3:-}"

  if [[ -z "$project" || -z "$env" || -z "$key" ]]; then
    log_error "Usage: delete <project> <env> <key>"
    exit 1
  fi

  guard_deprecated_write "$project" "delete"

  local project_id
  project_id=$(get_project_id "$project")
  local secret_path
  secret_path=$(resolve_secret_path "$project" "$env" "$key")

  local token
  token=$(infisical_auth)

  local response
  response=$(curl -s -X DELETE "${INFISICAL_API_URL}/api/v3/secrets/raw/${key}" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"workspaceId\": \"${project_id}\", \"environment\": \"${env}\", \"secretPath\": \"${secret_path}\"}")

  if echo "$response" | jq -e '.secret' >/dev/null 2>&1; then
    log_success "Deleted secret: $key"
  else
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
    log_error "Failed to delete secret: $error_msg"
    exit 1
  fi
}

# Export secrets to .env file
infisical_sync_to_env() {
  local project="${1:-}"
  local env="${2:-}"
  local output_file="${3:-}"

  if [[ -z "$project" || -z "$env" || -z "$output_file" ]]; then
    log_error "Usage: export <project> <env> <file>"
    exit 1
  fi

  local project_id
  project_id=$(get_project_id "$project")

  local token
  token=$(infisical_auth)

  local response
  response=$(curl -s -X GET "${INFISICAL_API_URL}/api/v3/secrets/raw?workspaceId=${project_id}&environment=${env}" \
    -H "Authorization: Bearer $token")

  echo "# Exported from Infisical: $project ($env)" > "$output_file"
  echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$output_file"
  echo "" >> "$output_file"

  echo "$response" | jq -r '.secrets[] | "\(.secretKey)=\"\(.secretValue)\""' >> "$output_file"

  log_success "Exported $(echo "$response" | jq '.secrets | length') secrets to $output_file"
}

# Import secrets from .env file
infisical_sync_from_env() {
  local project="${1:-}"
  local env="${2:-}"
  local input_file="${3:-}"

  if [[ -z "$project" || -z "$env" || -z "$input_file" ]]; then
    log_error "Usage: import <project> <env> <file>"
    exit 1
  fi

  guard_deprecated_write "$project" "import"

  if [[ ! -f "$input_file" ]]; then
    log_error "File not found: $input_file"
    exit 1
  fi

  local count=0
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    # Remove quotes from value
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    infisical_set_secret "$project" "$env" "$key" "$value"
    ((count++))
  done < "$input_file"

  log_success "Imported $count secrets from $input_file"
}

# Verify auth works
infisical_verify() {
  local token
  token=$(infisical_auth 2>/dev/null)
  if [[ -n "$token" ]]; then
    log_success "Authentication successful"
    log_info "Token: ${token:0:20}..."
  else
    log_error "Authentication failed"
    exit 1
  fi
}

# Show help
show_help() {
  cat << 'EOF'
Infisical Secrets Management Agent

Usage: infisical-agent.sh <command> [args]

Commands:
  auth                              Verify authentication
  projects                          List all projects
  list <project> [env]              List secrets (env defaults to 'dev')
  get <project> <env> <key>         Get a secret value (always fetches)
  get-cached <project> <env> <key>  Get secret with caching (fast, for shell startup)
  set <project> <env> <key> <value> Set/create a secret
  delete <project> <env> <key>      Delete a secret
  export <project> <env> <file>     Export secrets to .env file
  import <project> <env> <file>     Import secrets from .env file
  cache-info                        Show cache status and TTL
  cache-clear [project] [env] [key] Clear cached secrets

Active Projects:
  infrastructure    (spine-bound, governed writes)
  mint-os-api       (legacy product)
  n8n               (automation)
  media-stack       (media management)
  immich            (photo management)
  home-assistant    (smart home)

Deprecated Projects (read-only, writes blocked):
  finance-stack     (use infrastructure /spine/services/finance)
  mint-os-vault     (consolidation candidate)
  mint-os-portal    (empty, delete candidate)

Environment Variables:
  INFISICAL_UNIVERSAL_AUTH_CLIENT_ID      Client ID (default: 40b44e76-...)
  INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET  Client Secret (required)
  INFISICAL_API_URL                       API URL (default: https://secrets.ronny.works)
  INFISICAL_CACHE_TTL                     Cache TTL in seconds (default: 14400 = 4 hours)

Caching:
  - get-cached uses ~/.cache/infisical/ to store secrets
  - Cache TTL defaults to 4 hours (configurable via INFISICAL_CACHE_TTL)
  - First call fetches from API and caches; subsequent calls read from cache
  - Use --no-cache flag to force refresh: get-cached proj env key --no-cache
  - Use cache-clear to manually invalidate cache
  - For infrastructure/prod, key paths may be auto-resolved via
    ops/bindings/secrets.namespace.policy.yaml

Examples:
  infisical-agent.sh auth
  infisical-agent.sh list n8n dev
  infisical-agent.sh get mint-os-api prod JWT_SECRET
  infisical-agent.sh get-cached infrastructure prod CLOUDFLARE_API_TOKEN
  infisical-agent.sh get-cached infrastructure prod CLOUDFLARE_API_TOKEN --no-cache
  infisical-agent.sh cache-info
  infisical-agent.sh cache-clear
  infisical-agent.sh set n8n prod MS365_CLIENT_ID "your-client-id"
  infisical-agent.sh export mint-os-api prod /tmp/api.env
EOF
}

# Main command router
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
      auth|verify)
        infisical_verify
        ;;
      projects|list-projects)
        infisical_list_projects
        ;;
      list|ls)
        infisical_list_secrets "${1:-}" "${2:-dev}"
        ;;
      get)
        infisical_get_secret "${1:-}" "${2:-}" "${3:-}"
        ;;
      get-cached)
        infisical_get_secret_cached "${1:-}" "${2:-}" "${3:-}" "${4:-}"
        ;;
      set)
        infisical_set_secret "${1:-}" "${2:-}" "${3:-}" "${4:-}"
        ;;
      delete|del|rm)
        infisical_delete_secret "${1:-}" "${2:-}" "${3:-}"
        ;;
      export|sync-to-env)
        infisical_sync_to_env "${1:-}" "${2:-}" "${3:-}"
        ;;
      import|sync-from-env)
        infisical_sync_from_env "${1:-}" "${2:-}" "${3:-}"
        ;;
      cache-info|cache-status)
        infisical_cache_info
        ;;
      cache-clear|cache-flush)
        clear_cache "${1:-}" "${2:-}" "${3:-}"
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
fi
