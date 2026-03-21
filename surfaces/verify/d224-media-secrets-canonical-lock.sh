#!/usr/bin/env bash
# TRIAGE: Ensure all media compose secret vars are registered in canonical policy routes, no legacy project fallback for active keys, and SSH targets are wired.
# D224: Media Secrets Canonical Lock
# Enforces: compose secret registration, canonical path placement, SSH target contract parity
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
POLICY="$ROOT/ops/bindings/secrets.namespace.policy.yaml"
RUNWAY="$ROOT/ops/bindings/secrets.runway.contract.yaml"
MEDIA_SERVICES="$ROOT/ops/bindings/media.services.yaml"
DL_COMPOSE="$SPINE_FOUNDATION_ROOT/ops/domains/download-stack/docker-compose.yml"
ST_COMPOSE="$SPINE_FOUNDATION_ROOT/ops/domains/streaming-stack/docker-compose.yml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl not installed"; exit 1; }

for file in "$POLICY" "$RUNWAY" "$MEDIA_SERVICES" "$DL_COMPOSE" "$ST_COMPOSE" "$SSH_TARGETS"; do
  [[ -f "$file" ]] || { err "missing required file: $file"; exit 1; }
done

get_service_field() {
  local service="$1" field="$2"
  yq -r ".services[\"$service\"].$field // \"\"" "$MEDIA_SERVICES" 2>/dev/null || true
}

get_target_field() {
  local target="$1" field="$2"
  yq -r ".ssh.targets[] | select(.id == \"$target\") | .$field // \"\"" "$SSH_TARGETS" 2>/dev/null || true
}

resolve_service_host() {
  local service="$1"
  local vm tailscale_ip host

  vm="$(get_service_field "$service" "vm")"
  [[ -n "$vm" && "$vm" != "null" ]] || return 1

  tailscale_ip="$(get_target_field "$vm" "tailscale_ip")"
  host="$(get_target_field "$vm" "host")"

  if [[ -n "$tailscale_ip" && "$tailscale_ip" != "null" ]]; then
    printf '%s\n' "$tailscale_ip"
    return 0
  fi

  [[ -n "$host" && "$host" != "null" ]] || return 1
  printf '%s\n' "$host"
}

resolve_service_base_url() {
  local service="$1"
  local host port

  host="$(resolve_service_host "$service" || true)"
  port="$(get_service_field "$service" "port")"
  [[ -n "$host" && -n "$port" && "$port" != "null" ]] || return 1
  printf 'http://%s:%s\n' "$host" "$port"
}

service_runtime_checkable() {
  local service="$1"
  local status

  status="$(get_service_field "$service" "status")"
  case "$status" in
    active) return 0 ;;
    parked|planned) return 1 ;;
    *) return 0 ;;
  esac
}

# ── 1. Compose secret vars must be registered in policy or runway ──────────
check_compose_keys() {
  local compose="$1" stack="$2"
  local keys
  keys=$(grep -oE '\$\{[A-Z_]+\}' "$compose" 2>/dev/null | sed 's/\${//;s/}//' | sort -u)

  for key in $keys; do
    # Skip non-secret env vars (TZ, PUID, PGID, static defaults)
    case "$key" in
      TZ|PUID|PGID|WEBUI_PORT|DOCKER_API_VERSION|VPN_SERVER_COUNTRIES) continue ;;
    esac

    # Check in: required_key_paths, key_path_overrides, planned_key_paths
    local in_policy
    in_policy=$(yq -r "
      (.rules.required_key_paths[\"$key\"] // \"\") +
      (.rules.key_path_overrides[\"$key\"] // \"\") +
      (.rules.planned_key_paths[\"$key\"] // \"\")
    " "$POLICY" 2>/dev/null || true)

    # Check in runway key_overrides
    local in_runway
    in_runway=$(yq -r ".key_overrides[\"$key\"].path // \"\"" "$RUNWAY" 2>/dev/null || true)

    # Check in runway stack_key_overrides
    local in_stack_override
    in_stack_override=$(yq -r ".stack_key_overrides[\"$stack\"][\"$key\"].canonical_key // \"\"" "$RUNWAY" 2>/dev/null || true)

    if [[ -z "$in_policy" && -z "$in_runway" && -z "$in_stack_override" ]]; then
      err "$stack: compose var $key has no policy route, runway override, or stack_key_override"
    else
      ok "$stack: $key registered"
    fi
  done
}

check_compose_keys "$DL_COMPOSE" "download-stack"
check_compose_keys "$ST_COMPOSE" "streaming-stack"

# Ensure canonical download-stack keeps autopulse/crosswatch wiring.
for required in \
  'AUTOPULSE__TARGETS__JELLYFIN__TOKEN=${JELLYFIN_API_TOKEN}' \
  'AUTOPULSE__TARGETS__JELLYFIN__URL=' \
  'AUTOPULSE__TRIGGERS__RADARR__TYPE=radarr' \
  'AUTOPULSE__TRIGGERS__SONARR__TYPE=sonarr' \
  'AUTOPULSE__TRIGGERS__LIDARR__TYPE=lidarr' \
  '127.0.0.1:8787:8787'
do
  if ! grep -Fq "$required" "$DL_COMPOSE"; then
    err "download-stack: missing required canonical media bridge setting: $required"
  fi
done

# ── 2. Canonical paths: active media keys must NOT route to legacy media-stack project ──
check_canonical_routing() {
  local key="$1" expected_path="$2"
  local override_path override_project
  override_path=$(yq -r ".key_overrides[\"$key\"].path // \"\"" "$RUNWAY" 2>/dev/null || true)
  override_project=$(yq -r ".key_overrides[\"$key\"].project // \"\"" "$RUNWAY" 2>/dev/null || true)

  if [[ -n "$override_path" ]]; then
    if [[ "$override_project" == "media-stack" && "$override_path" == "/" ]]; then
      err "$key routes to legacy media-stack project at root (should be infrastructure at $expected_path)"
    else
      ok "$key canonical: project=$override_project path=$override_path"
    fi
  fi
}

# Download-stack keys
for key in RADARR_API_KEY SONARR_API_KEY LIDARR_API_KEY PROWLARR_API_KEY SABNZBD_API_KEY PRIVADO_VPN_USER PRIVADO_VPN_PASS AUTOPULSE_PASSWORD REAL_DEBRID_API_KEY; do
  check_canonical_routing "$key" "/spine/vm-infra/media-stack/download"
done

# Streaming-stack keys
for key in SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET NAVIDROME_USERNAME NAVIDROME_PASSWORD LASTFM_API_KEY LASTFM_SECRET JELLYFIN_API_KEY JELLYFIN_API_TOKEN JELLYFIN_USER_ID JELLYSEERR_API_KEY; do
  check_canonical_routing "$key" "/spine/vm-infra/media-stack/streaming"
done

# ── 3. Runtime API key parity checks (prevents half-complete rotations) ────
INFISICAL_AGENT="$ROOT/ops/plugins/providers/bin/infisical-agent.sh"
if [[ ! -x "$INFISICAL_AGENT" ]]; then
  err "missing infisical agent: $INFISICAL_AGENT"
else
  get_secret() {
    local key="$1"
    bash "$INFISICAL_AGENT" get infrastructure prod "$key" 2>/dev/null | tail -n1
  }

  RADARR_KEY="$(get_secret RADARR_API_KEY || true)"
  SONARR_KEY="$(get_secret SONARR_API_KEY || true)"
  LIDARR_KEY="$(get_secret LIDARR_API_KEY || true)"
  PROWLARR_KEY="$(get_secret PROWLARR_API_KEY || true)"
  JSEERR_KEY="$(get_secret JELLYSEERR_API_KEY || true)"
  JFIN_TOKEN="$(get_secret JELLYFIN_API_TOKEN || true)"

  [[ -n "$RADARR_KEY" ]] || err "missing RADARR_API_KEY from canonical infrastructure route"
  [[ -n "$SONARR_KEY" ]] || err "missing SONARR_API_KEY from canonical infrastructure route"
  [[ -n "$LIDARR_KEY" ]] || err "missing LIDARR_API_KEY from canonical infrastructure route"
  [[ -n "$PROWLARR_KEY" ]] || err "missing PROWLARR_API_KEY from canonical infrastructure route"
  [[ -n "$JSEERR_KEY" ]] || err "missing JELLYSEERR_API_KEY from canonical infrastructure route"
  [[ -n "$JFIN_TOKEN" ]] || err "missing JELLYFIN_API_TOKEN from canonical infrastructure route"

  RADARR_URL="${RADARR_URL:-$(resolve_service_base_url radarr || true)}"
  SONARR_URL="${SONARR_URL:-$(resolve_service_base_url sonarr || true)}"
  LIDARR_URL="${LIDARR_URL:-$(resolve_service_base_url lidarr || true)}"
  PROWLARR_URL="${PROWLARR_URL:-$(resolve_service_base_url prowlarr || true)}"
  JSEERR_URL="${JSEERR_URL:-$(resolve_service_base_url jellyseerr || true)}"

  if [[ -z "$RADARR_URL" ]]; then
    err "failed to resolve RADARR_URL from media.services.yaml + ssh.targets.yaml"
  elif [[ -n "$RADARR_KEY" ]] && service_runtime_checkable radarr; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $RADARR_KEY" "$RADARR_URL/api/v3/system/status" || true)"
    [[ "$code" == "200" ]] || err "RADARR_API_KEY auth failed against $RADARR_URL (http=$code)"
  else
    ok "radarr runtime auth skipped (status=$(get_service_field radarr status), url=$RADARR_URL)"
  fi

  if [[ -z "$SONARR_URL" ]]; then
    err "failed to resolve SONARR_URL from media.services.yaml + ssh.targets.yaml"
  elif [[ -n "$SONARR_KEY" ]] && service_runtime_checkable sonarr; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $SONARR_KEY" "$SONARR_URL/api/v3/system/status" || true)"
    [[ "$code" == "200" ]] || err "SONARR_API_KEY auth failed against $SONARR_URL (http=$code)"
  else
    ok "sonarr runtime auth skipped (status=$(get_service_field sonarr status), url=$SONARR_URL)"
  fi

  if [[ -z "$LIDARR_URL" ]]; then
    err "failed to resolve LIDARR_URL from media.services.yaml + ssh.targets.yaml"
  elif [[ -n "$LIDARR_KEY" ]] && service_runtime_checkable lidarr; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $LIDARR_KEY" "$LIDARR_URL/api/v1/system/status" || true)"
    [[ "$code" == "200" ]] || err "LIDARR_API_KEY auth failed against $LIDARR_URL (http=$code)"
  else
    ok "lidarr runtime auth skipped (status=$(get_service_field lidarr status), url=$LIDARR_URL)"
  fi

  if [[ -z "$PROWLARR_URL" ]]; then
    err "failed to resolve PROWLARR_URL from media.services.yaml + ssh.targets.yaml"
  elif [[ -n "$PROWLARR_KEY" ]] && service_runtime_checkable prowlarr; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $PROWLARR_KEY" "$PROWLARR_URL/api/v1/health" || true)"
    [[ "$code" == "200" ]] || err "PROWLARR_API_KEY auth failed against $PROWLARR_URL (http=$code)"
    testall="$(curl -s -X POST -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" --data '{}' "$PROWLARR_URL/api/v1/applications/testall" || true)"
    valid="$(echo "$testall" | jq -r '[.[].isValid] | all' 2>/dev/null || echo false)"
    [[ "$valid" == "true" ]] || err "Prowlarr application parity check failed (testall reported invalid Sonarr/Radarr bindings)"
  else
    ok "prowlarr runtime auth skipped (status=$(get_service_field prowlarr status), url=$PROWLARR_URL)"
  fi

  if [[ -z "$JSEERR_URL" ]]; then
    err "failed to resolve JSEERR_URL from media.services.yaml + ssh.targets.yaml"
  elif [[ -n "$JSEERR_KEY" ]]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $JSEERR_KEY" "$JSEERR_URL/api/v1/settings/main" || true)"
    [[ "$code" == "200" ]] || err "JELLYSEERR_API_KEY auth failed against $JSEERR_URL (http=$code)"

    if service_runtime_checkable radarr && service_runtime_checkable sonarr; then
      rad_settings="$(curl -s -H "X-Api-Key: $JSEERR_KEY" "$JSEERR_URL/api/v1/settings/radarr" || true)"
      son_settings="$(curl -s -H "X-Api-Key: $JSEERR_KEY" "$JSEERR_URL/api/v1/settings/sonarr" || true)"
      rad_match="$(echo "$rad_settings" | jq -r --arg k "$RADARR_KEY" '.[0].apiKey == $k' 2>/dev/null || echo false)"
      son_match="$(echo "$son_settings" | jq -r --arg k "$SONARR_KEY" '.[0].apiKey == $k' 2>/dev/null || echo false)"
      [[ "$rad_match" == "true" ]] || err "Jellyseerr Radarr API key does not match canonical RADARR_API_KEY"
      [[ "$son_match" == "true" ]] || err "Jellyseerr Sonarr API key does not match canonical SONARR_API_KEY"

      rad_test_payload="$(echo "$rad_settings" | jq '.[0] | del(.id) | .minimumAvailability=(.minimumAvailability // "released")' 2>/dev/null || true)"
      son_test_payload="$(echo "$son_settings" | jq '.[0] | del(.id)' 2>/dev/null || true)"
      rad_test_code="$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Api-Key: $JSEERR_KEY" -H "Content-Type: application/json" --data "$rad_test_payload" "$JSEERR_URL/api/v1/settings/radarr/test" || true)"
      son_test_code="$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "X-Api-Key: $JSEERR_KEY" -H "Content-Type: application/json" --data "$son_test_payload" "$JSEERR_URL/api/v1/settings/sonarr/test" || true)"
      [[ "$rad_test_code" == "200" ]] || err "Jellyseerr Radarr test failed (http=$rad_test_code)"
      [[ "$son_test_code" == "200" ]] || err "Jellyseerr Sonarr test failed (http=$son_test_code)"
    else
      ok "jellyseerr downstream arr parity skipped (radarr_status=$(get_service_field radarr status), sonarr_status=$(get_service_field sonarr status))"
    fi
  fi

  # Ensure the current writer-plane env tracks canonical keys.
  current_writer_vm="$(yq -r '.operating_model.writer_plane.current_vm // "download-stack"' "$MEDIA_SERVICES" 2>/dev/null || echo "download-stack")"
  dl_host="${DOWNLOAD_STACK_SSH_HOST:-$current_writer_vm}"
  if [[ "$current_writer_vm" == "download-stack" ]]; then
    dl_rad_key="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^RADARR_API_KEY=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
    dl_son_key="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^SONARR_API_KEY=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
    dl_lid_key="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^LIDARR_API_KEY=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
    dl_jfin_token="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^JELLYFIN_API_TOKEN=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
    [[ -n "$dl_rad_key" ]] || err "download-stack .env missing RADARR_API_KEY"
    [[ -n "$dl_son_key" ]] || err "download-stack .env missing SONARR_API_KEY"
    [[ -n "$dl_lid_key" ]] || err "download-stack .env missing LIDARR_API_KEY"
    [[ -n "$dl_jfin_token" ]] || err "download-stack .env missing JELLYFIN_API_TOKEN"
    [[ "$dl_rad_key" == "$RADARR_KEY" ]] || err "download-stack .env RADARR_API_KEY drift from canonical key"
    [[ "$dl_son_key" == "$SONARR_KEY" ]] || err "download-stack .env SONARR_API_KEY drift from canonical key"
    [[ "$dl_lid_key" == "$LIDARR_KEY" ]] || err "download-stack .env LIDARR_API_KEY drift from canonical key"
    [[ "$dl_jfin_token" == "$JFIN_TOKEN" ]] || err "download-stack .env JELLYFIN_API_TOKEN drift from canonical key"
  else
    ok "current writer-plane env parity skipped for $current_writer_vm (download-stack env path is transitional-only)"
  fi
fi

# ── 4. Stack defaults must NOT use legacy media-stack project ──────────────
for stack in download-stack streaming-stack; do
  local_project=$(yq -r ".stack_defaults[\"$stack\"].project // \"\"" "$RUNWAY" 2>/dev/null || true)
  local_path=$(yq -r ".stack_defaults[\"$stack\"].path // \"\"" "$RUNWAY" 2>/dev/null || true)

  if [[ "$local_project" == "media-stack" ]]; then
    err "$stack: stack_default still uses legacy media-stack project (should be infrastructure)"
  else
    ok "$stack: stack_default project=$local_project path=$local_path"
  fi
done

# ── 5. SSH target contract parity ──────────────────────────────────────────
for target in download-stack streaming-stack; do
  ssh_host=$(yq -r ".ssh.targets[] | select(.id == \"$target\") | .host // \"\"" "$SSH_TARGETS" 2>/dev/null || true)
  if [[ -z "$ssh_host" ]]; then
    err "SSH target '$target' missing from ssh.targets.yaml"
  else
    ok "SSH target $target: host=$ssh_host"
  fi
done

# ── Result ─────────────────────────────────────────────────────────────────
if [[ $ERRORS -gt 0 ]]; then
  echo "D224 FAIL: $ERRORS check(s) failed" >&2
  exit 1
fi
exit 0
