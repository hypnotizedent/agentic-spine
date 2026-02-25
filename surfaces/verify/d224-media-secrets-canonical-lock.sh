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
for key in RADARR_API_KEY SONARR_API_KEY LIDARR_API_KEY PRIVADO_VPN_USER PRIVADO_VPN_PASS HUNTARR_USER HUNTARR_PASSWORD AUTOPULSE_PASSWORD REAL_DEBRID_API_KEY; do
  check_canonical_routing "$key" "/spine/vm-infra/media-stack/download"
done

# Streaming-stack keys
for key in SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET NAVIDROME_USERNAME NAVIDROME_PASSWORD LASTFM_API_KEY LASTFM_SECRET JELLYFIN_API_KEY; do
  check_canonical_routing "$key" "/spine/vm-infra/media-stack/streaming"
done

# ── 3. Stack defaults must NOT use legacy media-stack project ──────────────
for stack in download-stack streaming-stack; do
  local_project=$(yq -r ".stack_defaults[\"$stack\"].project // \"\"" "$RUNWAY" 2>/dev/null || true)
  local_path=$(yq -r ".stack_defaults[\"$stack\"].path // \"\"" "$RUNWAY" 2>/dev/null || true)

  if [[ "$local_project" == "media-stack" ]]; then
    err "$stack: stack_default still uses legacy media-stack project (should be infrastructure)"
  else
    ok "$stack: stack_default project=$local_project path=$local_path"
  fi
done

# ── 4. SSH target contract parity ──────────────────────────────────────────
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
