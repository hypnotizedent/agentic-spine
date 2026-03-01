#!/usr/bin/env bash
# TRIAGE: Ensure all media compose secret vars are registered in canonical policy routes, no legacy project fallback for active keys, and SSH targets are wired.
# D224: Media Secrets Canonical Lock
# Enforces: compose secret registration, canonical path placement, SSH target contract parity
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY="$ROOT/ops/bindings/secrets.namespace.policy.yaml"
RUNWAY="$ROOT/ops/bindings/secrets.runway.contract.yaml"
DL_COMPOSE="$ROOT/ops/staged/download-stack/docker-compose.yml"
ST_COMPOSE="$ROOT/ops/staged/streaming-stack/docker-compose.yml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl not installed"; exit 1; }

for file in "$POLICY" "$RUNWAY" "$DL_COMPOSE" "$ST_COMPOSE" "$SSH_TARGETS"; do
  [[ -f "$file" ]] || { err "missing required file: $file"; exit 1; }
done

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
for key in RADARR_API_KEY SONARR_API_KEY LIDARR_API_KEY PROWLARR_API_KEY SABNZBD_API_KEY PRIVADO_VPN_USER PRIVADO_VPN_PASS HUNTARR_USER HUNTARR_PASSWORD AUTOPULSE_PASSWORD REAL_DEBRID_API_KEY; do
  check_canonical_routing "$key" "/spine/vm-infra/media-stack/download"
done

# Streaming-stack keys
for key in SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET NAVIDROME_USERNAME NAVIDROME_PASSWORD LASTFM_API_KEY LASTFM_SECRET JELLYFIN_API_KEY JELLYFIN_API_TOKEN JELLYFIN_USER_ID JELLYSEERR_API_KEY; do
  check_canonical_routing "$key" "/spine/vm-infra/media-stack/streaming"
done

# ── 3. Runtime API key parity checks (prevents half-complete rotations) ────
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"
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

  [[ -n "$RADARR_KEY" ]] || err "missing RADARR_API_KEY from canonical infrastructure route"
  [[ -n "$SONARR_KEY" ]] || err "missing SONARR_API_KEY from canonical infrastructure route"
  [[ -n "$LIDARR_KEY" ]] || err "missing LIDARR_API_KEY from canonical infrastructure route"
  [[ -n "$PROWLARR_KEY" ]] || err "missing PROWLARR_API_KEY from canonical infrastructure route"
  [[ -n "$JSEERR_KEY" ]] || err "missing JELLYSEERR_API_KEY from canonical infrastructure route"

  RADARR_URL="${RADARR_URL:-http://100.107.36.76:7878}"
  SONARR_URL="${SONARR_URL:-http://100.107.36.76:8989}"
  LIDARR_URL="${LIDARR_URL:-http://100.107.36.76:8686}"
  PROWLARR_URL="${PROWLARR_URL:-http://100.107.36.76:9696}"
  JSEERR_URL="${JSEERR_URL:-http://100.123.207.64:5055}"

  if [[ -n "$RADARR_KEY" ]]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $RADARR_KEY" "$RADARR_URL/api/v3/system/status" || true)"
    [[ "$code" == "200" ]] || err "RADARR_API_KEY auth failed against $RADARR_URL (http=$code)"
  fi

  if [[ -n "$SONARR_KEY" ]]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $SONARR_KEY" "$SONARR_URL/api/v3/system/status" || true)"
    [[ "$code" == "200" ]] || err "SONARR_API_KEY auth failed against $SONARR_URL (http=$code)"
  fi

  if [[ -n "$LIDARR_KEY" ]]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $LIDARR_KEY" "$LIDARR_URL/api/v1/system/status" || true)"
    [[ "$code" == "200" ]] || err "LIDARR_API_KEY auth failed against $LIDARR_URL (http=$code)"
  fi

  if [[ -n "$PROWLARR_KEY" ]]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $PROWLARR_KEY" "$PROWLARR_URL/api/v1/health" || true)"
    [[ "$code" == "200" ]] || err "PROWLARR_API_KEY auth failed against $PROWLARR_URL (http=$code)"
    testall="$(curl -s -X POST -H "X-Api-Key: $PROWLARR_KEY" -H "Content-Type: application/json" --data '{}' "$PROWLARR_URL/api/v1/applications/testall" || true)"
    valid="$(echo "$testall" | jq -r '[.[].isValid] | all' 2>/dev/null || echo false)"
    [[ "$valid" == "true" ]] || err "Prowlarr application parity check failed (testall reported invalid Sonarr/Radarr bindings)"
  fi

  if [[ -n "$JSEERR_KEY" ]]; then
    code="$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $JSEERR_KEY" "$JSEERR_URL/api/v1/settings/main" || true)"
    [[ "$code" == "200" ]] || err "JELLYSEERR_API_KEY auth failed against $JSEERR_URL (http=$code)"

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
  fi

  # Ensure dependent docker env on VM 209 tracks canonical keys.
  dl_host="${DOWNLOAD_STACK_SSH_HOST:-download-stack}"
  dl_rad_key="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^RADARR_API_KEY=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
  dl_son_key="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^SONARR_API_KEY=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
  dl_lid_key="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$dl_host" "sudo sh -lc \"grep '^LIDARR_API_KEY=' /opt/stacks/download-stack/.env | head -n1 | cut -d= -f2-\"" 2>/dev/null || true)"
  [[ -n "$dl_rad_key" ]] || err "download-stack .env missing RADARR_API_KEY"
  [[ -n "$dl_son_key" ]] || err "download-stack .env missing SONARR_API_KEY"
  [[ -n "$dl_lid_key" ]] || err "download-stack .env missing LIDARR_API_KEY"
  [[ "$dl_rad_key" == "$RADARR_KEY" ]] || err "download-stack .env RADARR_API_KEY drift from canonical key"
  [[ "$dl_son_key" == "$SONARR_KEY" ]] || err "download-stack .env SONARR_API_KEY drift from canonical key"
  [[ "$dl_lid_key" == "$LIDARR_KEY" ]] || err "download-stack .env LIDARR_API_KEY drift from canonical key"
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
